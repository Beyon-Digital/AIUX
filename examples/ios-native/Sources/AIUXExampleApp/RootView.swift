import AIUXSwiftUI
import Foundation
import SwiftUI

// MARK: - Example app root
//
// `AIUXExampleRootView` is the real-app screen: a fullscreen `AIConversation`
// over the real UniFFI session, action routing through `DemoController`, a
// transcript pane, and the conformance fixture gallery for inspection.
//
// The `AIUXExampleApp` App struct at the bottom of this file is the entry
// point an .xcodeproj (or a SwiftPM executable wrapper) can host.

/// The demo conversation screen.
public struct AIUXExampleRootView: View {
    @ObservedObject public var controller: DemoController

    @State private var galleryPresented = false
    @State private var logPresented = false

    public init(controller: DemoController) {
        self.controller = controller
    }

    public var body: some View {
        NavigationStack {
            AIConversation(
                store: controller.store,
                mode: .fullscreen,
                composerPlaceholder: "Ask the demo agent…"
            )
            .onAIUXAction { action in
                controller.handle(action)
            }
            .navigationTitle(controller.store.snapshot.session?.title ?? "AIUX")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        Button {
                            logPresented = true
                        } label: {
                            Image(systemName: "list.bullet.rectangle")
                        }
                        .accessibilityLabel("Agent log")
                        Button {
                            galleryPresented = true
                        } label: {
                            Image(systemName: "square.grid.2x2")
                        }
                        .accessibilityLabel("Fixture gallery")
                    }
                }
            }
            .sheet(isPresented: $logPresented) {
                AIUXLogView(controller: controller)
            }
            .sheet(isPresented: $galleryPresented) {
                AIUXFixtureGallery()
            }
        }
        .task { controller.start() }
    }
}

/// The agent transcript sheet — what the mocked host/agent saw and did.
struct AIUXLogView: View {
    @ObservedObject var controller: DemoController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        NavigationStack {
            List(controller.log.indices, id: \.self) { i in
                Text(controller.log[i])
                    .font(theme.typography.caption)
                    .foregroundStyle(colors.muted)
            }
            .navigationTitle("Agent log")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// The conformance catalog: every `conformance/fixtures/*.json` replayed
/// through a fresh UniFFI session and rendered by `AIFixturePlayer`.
public struct AIUXFixtureGallery: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var fixtures: [AIUXFixture] = []
    @State private var loadError: String?

    public init() {}

    public var body: some View {
        let colors = theme.colors(for: colorScheme)
        NavigationStack {
            Group {
                if let loadError {
                    ContentUnavailableShim(text: loadError)
                } else {
                    List(fixtures, id: \.name) { fixture in
                        NavigationLink {
                            AIFixturePlayer(fixture: fixture) {
                                AIUXFixtureGallery.galleryBackend()
                            }
                            .background(colors.background)
                            .navigationTitle(fixture.name)
                            #if os(iOS)
                            .navigationBarTitleDisplayMode(.inline)
                            #endif
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fixture.name).font(theme.typography.label)
                                Text("\(fixture.events.count) events")
                                    .font(theme.typography.caption)
                                    .foregroundStyle(colors.muted)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fixtures")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            do {
                fixtures = try AIUXFixtureCatalog.loadAll(in: aiuxConformanceFixturesURL())
            } catch {
                loadError = String(describing: error)
            }
        }
    }

    /// A fresh UniFFI session for one fixture player.
    static func galleryBackend() -> AIUXSessionBackend {
        (try? UniFFIBackend.create(configJson: #"{"sessionId":"gallery"}"#))
            ?? FailingBackend(error: CocoaError(.featureUnsupported))
    }
}

/// Minimal empty-state stand-in (`ContentUnavailableView` is iOS 17+).
private struct ContentUnavailableShim: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    let text: String

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(spacing: theme.space(.sm)) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(colors.warning)
            Text("Couldn't load fixtures")
                .font(theme.typography.heading)
            Text(text)
                .font(theme.typography.caption)
                .foregroundStyle(colors.muted)
        }
        .padding(theme.space(.lg))
    }
}

/// `conformance/fixtures/` resolved relative to this source file — the same
/// `#filePath` trick the bindings tests use. Dev-only pathing: a shipped .app
/// would bundle the catalog as a resource instead.
public func aiuxConformanceFixturesURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // AIUXExampleApp
        .deletingLastPathComponent() // Sources
        .deletingLastPathComponent() // ios-native
        .deletingLastPathComponent() // examples
        .appendingPathComponent("conformance/fixtures")
}

// MARK: - App entry point
//
// `AIUXExampleApp` is the SwiftUI `App` an Xcode project hosts as its @main.
// (An SPM executable can't be an iOS bundle, but this is the real app scene —
// on macOS `swift run` can also call `AIUXExampleApp.main()`.)

/// The demo app — a fullscreen AIUX conversation over a real UniFFI session.
public struct AIUXExampleApp: App {
    @StateObject private var controller: DemoController

    public init() {
        _controller = StateObject(wrappedValue: DemoController.bootstrap())
    }

    public var body: some Scene {
        WindowGroup {
            AIUXExampleRootView(controller: controller)
                .aiuxTheme(.default)
        }
    }
}
