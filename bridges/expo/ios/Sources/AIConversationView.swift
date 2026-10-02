import Combine
import ExpoModulesCore
import SwiftUI
import UIKit

/// Hosts the complete SwiftUI `AIConversation` surface behind the Expo view
/// boundary via a `UIHostingController`. Props are JSON-typed (theme) or
/// scalars (mode/sessionId); every callback crosses back as an event — JS
/// never lays out the UI (plan §10).
public final class AIConversationView: ExpoView {

    private let onAction = EventDispatcher()
    private let onError = EventDispatcher()
    private let onSnapshot = EventDispatcher()

    private var sessionId: String?
    private var themeJson: String?
    private var mode: AIUXConversationMode = .fullscreen
    private var showComposer = true
    private var composerToolbarJson: String?

    private var hostingController: UIHostingController<AnyView>?
    private var cancellables = Set<AnyCancellable>()
    private var registryCancellable: AnyCancellable?
    private var boundStore: AIUXSessionStore?

    /// Native-side coalescing for `onSnapshot` (plan §10, §22).
    private static let snapshotThrottle: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(150)

    /// `AIUXComposerToolbarSpec` (JSON) → `AIUXComposerToolbar`. Unknown
    /// glyph names map to a default SF Symbol; malformed input → defaults.
    private static func parseComposerToolbar(_ json: String?) -> AIUXComposerToolbar {
        guard let json, let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return .default }

        func flag(_ name: String) -> Bool { (root[name] as? Bool) ?? true }
        let extra: [AIUXComposerTool] = (root["extra"] as? [[String: Any]] ?? [])
            .compactMap { o in
                guard let id = o["id"] as? String else { return nil }
                return AIUXComposerTool(
                    id: id,
                    accessibilityLabel: (o["label"] as? String) ?? id,
                    systemImage: symbol(for: o["glyph"] as? String)
                )
            }
        return AIUXComposerToolbar(
            attach: flag("attach"),
            tools: flag("tools"),
            dictate: flag("dictate"),
            extra: extra
        )
    }

    /// The shared glyph vocabulary → SF Symbols.
    private static func symbol(for name: String?) -> String {
        switch name {
        case "doc": return "doc.text"
        case "photo": return "photo"
        case "gear": return "gearshape"
        case "globe": return "globe"
        case "mic": return "mic"
        case "search": return "magnifyingglass"
        case "plus": return "plus"
        case "star": return "star"
        default: return "sparkles"
        }
    }

    required init(appContext: AppContext? = nil) {
        super.init(appContext: appContext)
        clipsToBounds = true
    }

    func setSessionId(_ value: String) {
        sessionId = value
        Task { @MainActor [weak self] in self?.rebind() }
    }

    func setThemeJson(_ value: String) {
        themeJson = value
        Task { @MainActor [weak self] in self?.rebuild() }
    }

    func setMode(_ value: String) {
        mode = AIUXConversationMode(rawValue: value) ?? .fullscreen
        Task { @MainActor [weak self] in self?.rebuild() }
    }

    func setShowComposer(_ value: Bool) {
        showComposer = value
        Task { @MainActor [weak self] in self?.rebuild() }
    }

    func setComposerToolbarJson(_ value: String) {
        composerToolbarJson = value
        Task { @MainActor [weak self] in self?.rebuild() }
    }

    @MainActor
    private func rebind() {
        guard let sessionId else { return }
        // `restore` replaces the registry store for this id — rebind so the
        // mounted conversation follows the restored session's events.
        if registryCancellable == nil {
            registryCancellable = AIUXSessionRegistry.shared.storeReplaced
                .filter { [weak self] in $0 == self?.sessionId }
                .sink { [weak self] _ in self?.rebind() }
        }
        let store = AIUXSessionRegistry.shared.store(for: sessionId)
        boundStore = store

        cancellables.removeAll()
        store.$renderModel
            .throttle(
                for: Self.snapshotThrottle,
                scheduler: DispatchQueue.main,
                latest: true
            )
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    do {
                        self.onSnapshot([
                            "snapshotJson": try store.backend.snapshot(),
                        ])
                    } catch {
                        /* snapshot contract is core-owned; skip bad frames */
                    }
                }
            }
            .store(in: &cancellables)

        store.$lastError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.onError([
                    "code": "store",
                    "message": String(describing: error),
                ])
            }
            .store(in: &cancellables)

        rebuild()
    }

    @MainActor
    private func rebuild() {
        guard sessionId != nil, let store = boundStore else { return }

        var content: AnyView = AnyView(
            AIConversation(
                store: store,
                mode: mode,
                composerPlaceholder: "Message…",
                showsComposer: showComposer,
                composerToolbar: Self.parseComposerToolbar(composerToolbarJson)
            )
                .onAIUXAction { [weak self] action in
                    let payload = (try? String(
                        decoding: JSONEncoder().encode(action.payload),
                        as: UTF8.self
                    )) ?? "{}"
                    self?.onAction([
                        "id": action.id,
                        "payloadJson": payload,
                    ])
                }
        )
        if let themeJson, let theme = AIUXThemeJSON.parse(themeJson) {
            content = AnyView(content.aiuxTheme(theme))
        }
        if let themeJson, let scheme = AIUXThemeJSON.colorScheme(themeJson) {
            content = AnyView(content.preferredColorScheme(scheme))
        }

        if let controller = hostingController {
            controller.rootView = content
        } else {
            let controller = UIHostingController(rootView: content)
            controller.view.backgroundColor = .clear
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(controller.view)
            NSLayoutConstraint.activate([
                controller.view.leadingAnchor.constraint(equalTo: leadingAnchor),
                controller.view.trailingAnchor.constraint(equalTo: trailingAnchor),
                controller.view.topAnchor.constraint(equalTo: topAnchor),
                controller.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            hostingController = controller
        }
    }
}
