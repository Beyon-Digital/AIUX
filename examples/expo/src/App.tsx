import { useEffect, useMemo, useRef, useState } from "react";
import {
  Appearance,
  SafeAreaView,
  StatusBar,
  StyleSheet,
  Switch,
  Text,
  View,
} from "react-native";
import {
  AIConversation,
  createAIUXSession,
  type AIUXErrorInfo,
} from "@beyondigital/aiux-expo";

import { DemoController } from "./DemoController";
import { exampleTheme } from "./theme";

const SESSION_ID = "s1";

export default function App() {
  const [ready, setReady] = useState(false);
  const [dark, setDark] = useState(
    () => Appearance.getColorScheme() === "dark",
  );
  const [error, setError] = useState<AIUXErrorInfo | null>(null);
  const controller = useRef<DemoController | null>(null);
  // Live mode streams real OpenRouter completions; the key is inline-bundled
  // by expo at build time (EXPO_PUBLIC_*), never committed.
  const liveKey = process.env.EXPO_PUBLIC_OPEN_ROUTER;
  const liveModel = process.env.EXPO_PUBLIC_OPENROUTER_MODEL ?? "openrouter/free";
  const [live, setLive] = useState(false);

  const toggleLive = (value: boolean) => {
    setLive(value);
    controller.current?.setLive(value, liveKey, liveModel);
  };

  const theme = useMemo(
    () => ({
      ...exampleTheme,
      colorScheme: dark ? ("dark" as const) : ("light" as const),
    }),
    [dark],
  );

  useEffect(() => {
    let cancelled = false;
    void createAIUXSession({ sessionId: SESSION_ID })
      .then(async () => {
        if (cancelled) return;
        controller.current = await DemoController.create(SESSION_ID);
        setReady(true);
      })
      .catch((cause: unknown) => {
        if (cancelled) return;
        setError({
          code: "session.create.failed",
          message: cause instanceof Error ? cause.message : String(cause),
        });
      });
    return () => {
      cancelled = true;
      controller.current?.close();
      controller.current = null;
    };
  }, []);

  return (
    <SafeAreaView
      style={[styles.root, dark && styles.rootDark]}
      accessibilityLabel="aiux example app"
    >
      <StatusBar barStyle={dark ? "light-content" : "dark-content"} />
      <View style={[styles.header, dark && styles.headerDark]}>
        {liveKey ? (
          <View style={styles.toggle}>
            <Text style={[styles.toggleLabel, dark && styles.titleDark]}>
              Live
            </Text>
            <Switch
              value={live}
              onValueChange={toggleLive}
              accessibilityLabel="toggle live mode"
            />
          </View>
        ) : null}
        <View style={styles.toggle}>
          <Text style={[styles.toggleLabel, dark && styles.titleDark]}>
            Dark
          </Text>
          <Switch
            value={dark}
            onValueChange={setDark}
            accessibilityLabel="toggle dark mode"
          />
        </View>
      </View>

      {error ? (
        <View style={styles.errorBox} accessibilityLabel="module error">
          <Text style={styles.errorText}>
            {error.code}: {error.message}
          </Text>
        </View>
      ) : null}

      <View style={styles.surface}>
        {ready ? (
          <AIConversation
            sessionId={SESSION_ID}
            theme={theme}
            mode="fullscreen"
            onAction={(action) => controller.current?.onAction(action)}
            onError={setError}
            style={styles.conversation}
          />
        ) : (
          <Text
            style={[styles.loading, dark && styles.titleDark]}
            accessibilityLabel="loading session"
          >
            Starting AIUX session…
          </Text>
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: "#FFFFFF" },
  rootDark: { backgroundColor: "#101318" },
  header: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "flex-end",
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#D8DCE3",
  },
  headerDark: { borderBottomColor: "#2A2F38" },
  titleDark: { color: "#E8EAED" },
  toggle: { flexDirection: "row", alignItems: "center", gap: 8 },
  toggleLabel: { fontSize: 13, color: "#3C4450" },
  surface: { flex: 1 },
  conversation: { flex: 1 },
  loading: { padding: 24, fontSize: 14, color: "#3C4450" },
  errorBox: {
    margin: 12,
    padding: 12,
    borderRadius: 8,
    backgroundColor: "#FDECEC",
  },
  errorText: { color: "#B3261E", fontSize: 13 },
});
