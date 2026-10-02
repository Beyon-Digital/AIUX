import AIUXSwiftUI
import Foundation

// MARK: - Demo controller (the "host" + mocked agent)
//
// `DemoController` plays both sides of the Phase 3 gate demo:
//   host side   — owns the `AIUXSessionStore`, receives `AIUXAction`s from
//                 views and turns them into protocol events (a real host
//                 would forward them to its agent).
//   agent side  — the mock: answers `aiux.composer.send` with the scripted
//                 stream, holds at `approval.requested`, and resolves when
//                 `aiux.approval.resolve` arrives.
//
// Events trickle in with small delays so streaming/progress states are
// actually visible in the UI.

@MainActor
public final class DemoController: ObservableObject {
    /// The session store the views bind to.
    public let store: AIUXSessionStore

    /// Running agent transcript — surfaced in the UI for inspection.
    @Published public private(set) var log: [String] = []

    private var factory = DemoEventFactory(sessionId: DemoScenario.sessionId)
    private var turn = 0
    private var runTask: Task<Void, Never>?
    /// Suspends the script between `approval.requested` and the user's choice.
    private var approvalGate: CheckedContinuation<Bool, Never>?
    private var waitingForApproval = false
    /// A decision tapped before the gate was installed — consumed on arrival.
    private var queuedDecision: Bool?

    public init(store: AIUXSessionStore) {
        self.store = store
    }

    /// Build a controller over a real UniFFI session; falls back to a
    /// fail-loud backend so the UI shows the error instead of crashing.
    public static func bootstrap(configJson: String = #"{"sessionId":"demo"}"#) -> DemoController {
        do {
            let backend = try UniFFIBackend.create(configJson: configJson)
            return DemoController(store: AIUXSessionStore(backend: backend))
        } catch {
            return DemoController(store: AIUXSessionStore(backend: FailingBackend(error: error)))
        }
    }

    /// Emit the session bootstrap + start listening. Call once from `.task`.
    public func start() {
        guard store.snapshot.session == nil else { return }
        do {
            _ = try store.ingest(eventJson: DemoScenario.sessionCreated(factory: &factory))
        } catch {
            record("session.created failed: \(error)")
        }
    }

    // MARK: Action handling — the host's job

    /// Route a semantic action emitted by a view. The renderer produced it;
    /// this host decides what it means (plan §1, §23).
    public func handle(_ action: AIUXAction) {
        switch action.id {
        case AIUXAction.composerSend:
            let text = action.payload["text"]?.stringValue ?? ""
            guard !text.isEmpty else { return }
            sendPrompt(text)
        case AIUXAction.composerCancel:
            cancelActiveTurn()
        case AIUXAction.approvalResolve:
            let decision = action.payload["decision"]?.stringValue ?? ""
            resolveApproval(approved: decision == "approved")
        case AIUXAction.composerAttach:
            record("attach requested — host picker hook")
        case AIUXAction.contextAdd:
            record("context add requested — host picker hook")
        case AIUXAction.contextRemove:
            record("context remove: \(action.payload["entityId"]?.stringValue ?? "?")")
        case AIUXAction.errorRetry:
            record("retry requested: \(action.payload["code"]?.stringValue ?? "")")
        default:
            // Host-defined actions (e.g. report.open, report.share) and open
            // requests land here — a real app routes them to navigation.
            let keys = action.payload.keys.sorted().joined(separator: ",")
            record("action \(action.id) [\(keys)]")
        }
    }

    // MARK: Agent script

    /// User sent a prompt → echo the message, then stream the mocked turn.
    private func sendPrompt(_ text: String) {
        guard runTask == nil else { record("busy — run already active"); return }
        turn += 1
        let turn = self.turn
        record("you: \(text)")
        do {
            _ = try store.ingest(eventsJson: "[" + [
                DemoScenario.userMessage(factory: &factory, messageId: "m-user-\(turn)", text: text),
            ].joined(separator: ",") + "]")
        } catch {
            record("user message failed: \(error)")
            return
        }

        let scenarioEvents = DemoScenario.preApprovalEvents(factory: &factory, turn: turn)
        runTask = Task { [weak self] in
            guard let self else { return }
            // The approval card appears before the gate is installed; mark
            // waiting now so an early tap queues instead of being ignored.
            self.waitingForApproval = true
            for event in scenarioEvents {
                if Task.isCancelled { return }
                await self.dispatchTrickle(event)
            }
            // Hold for the approval decision.
            let approved: Bool
            if let queued = self.queuedDecision {
                self.queuedDecision = nil
                approved = queued
            } else {
                approved = await withCheckedContinuation { continuation in
                    self.approvalGate = continuation
                }
            }
            self.waitingForApproval = false
            for event in DemoScenario.postApprovalEvents(factory: &self.factory, turn: turn, approved: approved) {
                if Task.isCancelled { return }
                await self.dispatchTrickle(event)
            }
            self.runTask = nil
        }
    }

    private func cancelActiveTurn() {
        guard let task = runTask else { return }
        task.cancel()
        approvalGate?.resume(returning: false)
        approvalGate = nil
        waitingForApproval = false
        queuedDecision = nil
        let events = DemoScenario.cancelEvents(factory: &factory, turn: turn)
        runTask = nil
        do {
            _ = try store.ingest(eventsJson: "[" + events.joined(separator: ",") + "]")
        } catch {
            record("cancel events failed: \(error)")
        }
        record("run cancelled")
    }

    /// Resolve the pending approval and let the script continue.
    private func resolveApproval(approved: Bool) {
        guard waitingForApproval else {
            record("approval resolve ignored — nothing pending")
            return
        }
        if let gate = approvalGate {
            approvalGate = nil
            gate.resume(returning: approved)
        } else {
            queuedDecision = approved
        }
        record(approved ? "approval: approved" : "approval: rejected")
    }

    private func dispatchTrickle(_ eventJson: String) async {
        do {
            _ = try store.ingest(eventJson: eventJson)
        } catch {
            record("dispatch failed: \(error)")
        }
        // A short pause between events so streaming/progress states are
        // visible in the UI.
        try? await Task.sleep(for: .milliseconds(320))
    }

    private func record(_ line: String) {
        log.append(line)
        if log.count > 200 { log.removeFirst(log.count - 200) }
    }
}

/// A backend that always fails — only used when UniFFI creation itself fails,
/// so the UI surfaces the store error instead of crashing at boot.
final class FailingBackend: AIUXSessionBackend {
    let error: Error
    init(error: Error) { self.error = error }
    func dispatch(eventJson: String) throws -> String { throw error }
    func dispatchBatch(eventsJson: String) throws -> String { throw error }
    func snapshot() throws -> String { throw error }
    func serialize() throws -> String { throw error }
    func reset() throws { throw error }
}
