/**
 * `@beyond-digital/aiux-expo` — the AIUX native surface for Expo SDK 57.
 *
 * One coarse boundary (plan §10): `<AIConversation/>` hosts the platform's
 * native renderer (SwiftUI on iOS, Compose on Android) and the underlying
 * `AiuxSession`. JS configures the session, streams protocol events through
 * the batched transport, and receives semantic actions — it never lays out
 * message UI.
 *
 * ```tsx
 * <AIConversation
 *   sessionId="demo"
 *   theme={theme}
 *   context={context}
 *   capabilities={capabilities}
 *   onAction={handleAction}
 *   mode="fullscreen"
 * />
 * ```
 */

export { AIConversation } from "./AIConversation";
export type { AIConversationProps } from "./AIConversation";
export {
  createAIUXSession,
  dispatchAIUXBatch,
  getAIUXSnapshot,
  resetAIUXSession,
  restoreAIUXSession,
  serializeAIUXSession,
} from "./sessions";
export type { AIUXSessionBootstrap } from "./sessions";
export { createAIUXTransport } from "./transport";
export type { AIUXTransport, AIUXTransportPolicy } from "./transport";
export { getNativeModule } from "./AIUXNative";
export type {
  AIConversationMode,
  AIUXAction,
  AIUXCapability,
  AIUXComposerGlyphName,
  AIUXComposerToolbarSpec,
  AIUXComposerToolSpec,
  AIUXColorRole,
  AIUXColorRoles,
  AIUXColorValue,
  AIUXContextEntity,
  AIUXDispatchReport,
  AIUXErrorInfo,
  AIUXEventLike,
  AIUXSnapshot,
  AIUXThemeInput,
} from "./types";
