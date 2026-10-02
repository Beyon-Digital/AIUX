import { useEffect, useMemo } from "react";
import type {
  NativeSyntheticEvent,
  StyleProp,
  ViewStyle,
} from "react-native";
import { View as RNView } from "react-native";

import {
  getNativeModule,
  getNativeView,
  type NativeActionEvent,
  type NativeErrorEvent,
  type NativeSnapshotEvent,
} from "./AIUXNative";
import { createAIUXSession } from "./sessions";
import type {
  AIConversationMode,
  AIUXAction,
  AIUXCapability,
  AIUXContextEntity,
  AIUXErrorInfo,
  AIUXSnapshot,
  AIUXThemeInput,
} from "./types";

export interface AIConversationProps {
  /** Session id to bind — the native side owns the `AiuxSession` registry. */
  sessionId: string;
  /**
   * Theme roles (plan §7). Accepts the input object — it is serialized to
   * JSON at the boundary — or a pre-serialized JSON string.
   */
  theme?: AIUXThemeInput | string;
  /**
   * Context entities for the session bootstrap. Combined with
   * `capabilities`/`title` into a seed `session.created` (sequence 0) when
   * the session has not been bootstrapped yet — a producer emitting its own
   * `session.created` should not rely on these props.
   */
  context?: AIUXContextEntity[];
  /** Declared capabilities for the session bootstrap (see `context`). */
  capabilities?: AIUXCapability[];
  /** Optional session title for the bootstrap seed. */
  title?: string;
  /** Presentation mode (plan §14). */
  mode?: AIConversationMode;
  /** Whether the composer row is visible. */
  showComposer?: boolean;
  /**
   * Semantic `AIUXAction`s emitted by the native surface. The library never
   * executes them — it routes them to the host application (plan §10).
   */
  onAction?: (action: AIUXAction) => void;
  /** Native errors surfaced to the host. */
  onError?: (error: AIUXErrorInfo) => void;
  /**
   * Throttled canonical snapshot emissions (native-coalesced ~150 ms). Use
   * for bespoke chrome; the surface itself needs nothing.
   */
  onSnapshot?: (snapshot: AIUXSnapshot) => void;
  style?: StyleProp<ViewStyle>;
  /** Placeholder rendered when the native module is not linked. */
  fallback?: React.ReactNode;
  children?: React.ReactNode;
}

function parseAction(
  event: NativeSyntheticEvent<NativeActionEvent>,
): AIUXAction {
  const { id, payloadJson } = event.nativeEvent;
  let payload: Record<string, unknown> = {};
  if (payloadJson) {
    try {
      payload = JSON.parse(payloadJson) as Record<string, unknown>;
    } catch {
      payload = {};
    }
  }
  return { id, payload };
}

/**
 * The complete AIUX conversation surface — iOS SwiftUI / Android Compose —
 * behind one coarse native boundary. JS configures and controls the surface;
 * no message UI is ever laid out in React Native (plan §10, ADR 0002).
 */
export function AIConversation(props: AIConversationProps) {
  const {
    sessionId,
    theme,
    context,
    capabilities,
    title,
    mode = "fullscreen",
    showComposer = true,
    onAction,
    onError,
    onSnapshot,
    style,
    fallback = null,
    children,
  } = props;

  useEffect(() => {
    if (!getNativeModule()) return;
    void createAIUXSession({ sessionId }).catch((error: unknown) => {
      onError?.({
        code: "session.create.failed",
        message: error instanceof Error ? error.message : String(error),
      });
    });
  }, [sessionId]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (
      context === undefined &&
      capabilities === undefined &&
      title === undefined
    ) {
      return;
    }
    if (!getNativeModule()) return;
    void createAIUXSession({ sessionId, title, context, capabilities }).catch(
      (error: unknown) => {
        onError?.({
          code: "session.bootstrap.failed",
          message: error instanceof Error ? error.message : String(error),
        });
      },
    );
  }, [sessionId]); // eslint-disable-line react-hooks/exhaustive-deps

  const themeJson = useMemo(
    () =>
      theme === undefined
        ? undefined
        : typeof theme === "string"
          ? theme
          : JSON.stringify(theme),
    [theme],
  );

  const NativeView = getNativeView();
  if (!NativeView) return <RNView style={style}>{fallback}</RNView>;

  return (
    <NativeView
      sessionId={sessionId}
      theme={themeJson}
      mode={mode}
      showComposer={showComposer}
      style={style}
      onAction={(event: NativeSyntheticEvent<NativeActionEvent>) =>
        onAction?.(parseAction(event))
      }
      onError={(event: NativeSyntheticEvent<NativeErrorEvent>) =>
        onError?.(event.nativeEvent)
      }
      onSnapshot={(event: NativeSyntheticEvent<NativeSnapshotEvent>) => {
        if (!onSnapshot) return;
        try {
          onSnapshot(
            JSON.parse(event.nativeEvent.snapshotJson) as AIUXSnapshot,
          );
        } catch {
          /* snapshot contract is native-owned; ignore malformed frames */
        }
      }}
    >
      {children}
    </NativeView>
  );
}
