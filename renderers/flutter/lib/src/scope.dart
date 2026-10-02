import 'package:flutter/material.dart';

import 'models.dart';

// MARK: - Action + entity scope
//
// Views emit `AiuxAction`s upward through an inherited scope; the host
// decides execution (PLAN §1, §23). Entity references inside parts (`tool`,
// `approval`, `artifact`, `surface`) resolve against a per-snapshot index
// carried in the same scope, so part views never need prop drilling.

/// Carries the resolved entity index plus the semantic-action handler for an
/// AIUX subtree. `AIConversation` publishes its store's model here; hosts
/// register a handler with `AiuxActionScope`.
class AiuxScope extends InheritedWidget {
  const AiuxScope({
    super.key,
    required this.model,
    required this.emit,
    required super.child,
  });

  /// The resolved entity index for the snapshot being rendered.
  final AiuxRenderModel model;

  /// The handler every AIUX view reports semantic actions to.
  final void Function(AiuxAction) emit;

  /// The nearest scope's render model — empty when outside a conversation.
  static AiuxRenderModel modelOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AiuxScope>()?.model ??
      AiuxRenderModel(snapshot: AiuxSnapshot());

  /// The nearest scope's action emitter — a no-op sink when outside a
  /// conversation (safe for previews and read-only embeddings).
  static void Function(AiuxAction) emitterOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AiuxScope>()?.emit ?? (_) {};

  /// Emit an action to the nearest scope.
  static void emitAction(BuildContext context, AiuxAction action) =>
      emitterOf(context)(action);

  @override
  bool updateShouldNotify(AiuxScope oldWidget) =>
      !identical(model, oldWidget.model) || !identical(emit, oldWidget.emit);
}
