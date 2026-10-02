import { requireNativeModule, requireNativeView } from "expo";
import type { NativeSyntheticEvent } from "react-native";

import type {
  AIConversationMode,
  AIUXDispatchReport,
} from "./types";

/** Native view scalar props — JSON strings keep the boundary verbatim. */
export interface NativeViewProps {
  /** Bound session id (`AiuxSession` in the native session registry). */
  sessionId?: string | undefined;
  /** `AIUXThemeInput` serialized to JSON. */
  theme?: string | undefined;
  /** Presentation mode. */
  mode?: AIConversationMode | undefined;
  /** Whether the composer row is visible. */
  showComposer?: boolean | undefined;
  /** `AIUXComposerToolbarSpec` serialized to JSON. */
  composerToolbar?: string | undefined;
  style?: unknown;
  children?: unknown;
}

/** `{ id, payloadJson }` — payloadJson is the action payload verbatim. */
export interface NativeActionEvent {
  id: string;
  payloadJson?: string;
}

/** `{ code, message }`. */
export interface NativeErrorEvent {
  code: string;
  message: string;
}

/** `{ snapshotJson }` — canonical snapshot serialized to JSON. */
export interface NativeSnapshotEvent {
  snapshotJson: string;
}

export interface NativeViewEventProps {
  onAction?:
    | ((event: NativeSyntheticEvent<NativeActionEvent>) => void)
    | undefined;
  onError?:
    | ((event: NativeSyntheticEvent<NativeErrorEvent>) => void)
    | undefined;
  onSnapshot?:
    | ((event: NativeSyntheticEvent<NativeSnapshotEvent>) => void)
    | undefined;
}

export interface EventSubscriptionLike {
  remove(): void;
}

export interface AIUXModuleSpec {
  createSession(sessionId: string, configJson: string): Promise<void>;
  dispatchBatch(
    sessionId: string,
    eventsJson: string,
  ): Promise<AIUXDispatchReport>;
  serialize(sessionId: string): Promise<string>;
  restore(serializedJson: string): Promise<void>;
  reset(sessionId: string): Promise<void>;
  snapshot(sessionId: string): Promise<string>;
  /** `true` when the native module linked (both renderers vendored). */
  isNativeReady(): boolean;
  addListener(
    eventName: "onAction" | "onError" | "onSnapshot",
    listener: (payload: unknown) => void,
  ): EventSubscriptionLike;
}

let cached: AIUXModuleSpec | null = null;

function loadModule(): AIUXModuleSpec | null {
  if (cached) return cached;
  try {
    cached = requireNativeModule<AIUXModuleSpec>("AIUX");
  } catch {
    cached = null;
  }
  return cached;
}

/** The native module, or `null` when unavailable (Expo Go / tests). */
export function getNativeModule(): AIUXModuleSpec | null {
  return loadModule();
}

type NativeViewType = React.ComponentType<NativeViewProps & NativeViewEventProps>;

let cachedView: NativeViewType | null | undefined;

/** Native view handle for `AIConversation`. `null` when unlinked. */
export function getNativeView(): NativeViewType | null {
  if (cachedView !== undefined) return cachedView;
  try {
    cachedView = requireNativeView<NativeViewProps & NativeViewEventProps>(
      "AIUX",
    );
  } catch {
    cachedView = null;
  }
  return cachedView;
}
