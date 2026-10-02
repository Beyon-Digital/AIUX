import 'dart:io';

import 'package:beyond_aiux/beyond_aiux.dart';
import 'package:flutter/material.dart';

import 'demo_controller.dart';

// MARK: - Example app root
//
// The demo screen: a fullscreen `AIConversation` over the real FFI session,
// action routing through `DemoController`, a transcript sheet, and the
// conformance fixture gallery for inspection.

/// The demo conversation screen.
class AiuxExampleRootView extends StatefulWidget {
  const AiuxExampleRootView({super.key, required this.controller});

  final DemoController controller;

  @override
  State<AiuxExampleRootView> createState() => _AiuxExampleRootViewState();
}

class _AiuxExampleRootViewState extends State<AiuxExampleRootView> {
  @override
  void initState() {
    super.initState();
    widget.controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: widget.controller.store,
          builder: (context, _) =>
              Text(widget.controller.store.snapshot.session?.title ?? 'AIUX'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            tooltip: 'Agent log',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (context) => AiuxLogView(controller: widget.controller),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view),
            tooltip: 'Fixture gallery',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (context) => const AiuxFixtureGallery()),
            ),
          ),
        ],
      ),
      body: AiuxScope(
        model: widget.controller.store.renderModel,
        emit: widget.controller.handle,
        child: AIConversation(
          store: widget.controller.store,
          composerPlaceholder: 'Ask the demo agent…',
        ),
      ),
    );
  }
}

/// The agent transcript sheet — what the mocked host/agent saw and did.
class AiuxLogView extends StatelessWidget {
  const AiuxLogView({super.key, required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                    child: Text('Agent log', style: theme.typography.heading)),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => ListView.builder(
                itemCount: controller.log.length,
                itemBuilder: (context, i) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Text(controller.log[i],
                      style: theme.typography.caption
                          .copyWith(color: colors.muted)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The conformance catalog: every `conformance/fixtures/*.json` replayed
/// through a fresh FFI session and rendered by `AIFixturePlayer`.
class AiuxFixtureGallery extends StatefulWidget {
  const AiuxFixtureGallery({super.key});

  @override
  State<AiuxFixtureGallery> createState() => _AiuxFixtureGalleryState();
}

class _AiuxFixtureGalleryState extends State<AiuxFixtureGallery> {
  List<AiuxFixture>? _fixtures;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    try {
      _fixtures = AiuxFixtureCatalog.loadAll(_fixtureDir());
    } catch (e) {
      _loadError = e.toString();
    }
  }

  /// `conformance/fixtures/` resolved relative to the app working directory —
  /// dev-only pathing: a shipped app would bundle the catalog as an asset.
  Directory _fixtureDir() {
    var dir = Directory.current.absolute;
    while (true) {
      final candidate = Directory('${dir.path}/conformance/fixtures');
      if (candidate.existsSync()) return candidate;
      final parent = dir.parent.absolute;
      if (parent.path == dir.path) {
        throw StateError(
            'conformance/fixtures not found above ${Directory.current.path} '
            '(run the app from within the AIUX checkout)');
      }
      dir = parent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final fixtures = _fixtures;
    return Scaffold(
      appBar: AppBar(title: const Text('Fixtures')),
      body: _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber, color: colors.warning),
                    Text("Couldn't load fixtures",
                        style: theme.typography.heading),
                    Text(_loadError!,
                        style: theme.typography.caption
                            .copyWith(color: colors.muted)),
                  ],
                ),
              ),
            )
          : ListView.builder(
              itemCount: fixtures?.length ?? 0,
              itemBuilder: (context, i) {
                final fixture = fixtures![i];
                return ListTile(
                  title: Text(fixture.name, style: theme.typography.label),
                  subtitle: Text('${fixture.events.length} events',
                      style: theme.typography.caption
                          .copyWith(color: colors.muted)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: Text(fixture.name)),
                        body: AIFixturePlayer(
                          fixture: fixture,
                          backend: AiuxFfiBackend.create,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
