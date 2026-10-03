import { useCallback, useEffect, useRef, useState } from "react";
import {
  AIConversation,
  type AIConversationMode,
  type AiuxAction,
  type AiuxTheme,
} from "@beyond-digital/aiux-web";
import { FIXTURES, type FixtureEntry } from "./fixtures.js";
import {
  createActionHandler,
  openSession,
  replayFixture,
  type LiveSession,
} from "./host.js";

type Conformance = "pending" | "pass" | "fail" | "n/a";

export default function App() {
  const [live, setLive] = useState<LiveSession | null>(null);
  const [fixture, setFixture] = useState<FixtureEntry | null>(null);
  const [mode, setMode] = useState<AIConversationMode>("fullscreen");
  const [scheme, setScheme] = useState<"light" | "dark" | "auto">("light");
  const [conformance, setConformance] = useState<Conformance>("pending");
  const [progress, setProgress] = useState("");
  const [actionLog, setActionLog] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const logRef = useRef<string[]>([]);
  const runId = useRef(0);

  const log = useCallback((line: string) => {
    logRef.current = [...logRef.current.slice(-49), line];
    setActionLog(logRef.current);
  }, []);

  const play = useCallback(
    async (entry: FixtureEntry | null, replay: "instant" | "stream") => {
      const ticket = ++runId.current;
      setError(null);
      setConformance("pending");
      setProgress("loading aiux-wasm…");
      try {
        const next = await openSession();
        if (ticket !== runId.current) {
          next.dispose();
          return;
        }
        setLive((prev) => {
          prev?.dispose();
          return next;
        });
        if (!entry) {
          setProgress("empty session — compose below");
          setConformance("n/a");
          return;
        }
        await replayFixture(next, entry.events, replay, (done, total) =>
          setProgress(`${done}/${total} events`),
        );
        if (ticket !== runId.current) return;
        if (entry.expectedSerialized !== undefined) {
          const actual = next.session.serialize();
          setConformance(
            actual === entry.expectedSerialized ? "pass" : "fail",
          );
        } else {
          setConformance("n/a");
        }
        setProgress(`${entry.events.length} events replayed`);
      } catch (e) {
        setError((e as Error).message);
        setProgress("");
      }
    },
    [],
  );

  // Boot: play the first fixture instantly.
  useEffect(() => {
    void play(FIXTURES[0] ?? null, "instant");
    setFixture(FIXTURES[0] ?? null);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const onAction = useCallback(
    (action: AiuxAction) => {
      if (!live) return;
      createActionHandler(live, log)(action);
    },
    [live, log],
  );

  const theme: AiuxTheme = { colorScheme: scheme };

  return (
    <div className={`example ${mode === "fullscreen" ? "example--full" : ""}`}>
      <header className="example__bar">
        <strong>AIUX</strong>
        <label>
          Fixture{" "}
          <select
            value={fixture?.name ?? ""}
            onChange={(e) => {
              const entry =
                FIXTURES.find((f) => f.name === e.target.value) ?? null;
              setFixture(entry);
              void play(entry, "instant");
            }}
          >
            <option value="">— empty session —</option>
            {FIXTURES.map((f) => (
              <option key={f.name} value={f.name}>
                {f.name}
              </option>
            ))}
          </select>
        </label>
        <button
          type="button"
          onClick={() => void play(fixture, "instant")}
          title="dispatchBatch all events at once"
        >
          Replay
        </button>
        <button
          type="button"
          onClick={() => void play(fixture, "stream")}
          title="Queue events through EventBuffer like a live transport"
        >
          Stream
        </button>
        <label>
          Mode{" "}
          <select
            value={mode}
            onChange={(e) => setMode(e.target.value as AIConversationMode)}
          >
            <option value="fullscreen">fullscreen</option>
            <option value="embedded">embedded</option>
          </select>
        </label>
        <label>
          Theme{" "}
          <select
            value={scheme}
            onChange={(e) =>
              setScheme(e.target.value as "light" | "dark" | "auto")
            }
          >
            <option value="light">light</option>
            <option value="dark">dark</option>
            <option value="auto">auto</option>
          </select>
        </label>
        <ConformanceBadge state={conformance} />
        <span className="example__progress" role="status">
          {error ? `error: ${error}` : progress}
        </span>
      </header>
      <main className="example__main">
        {live ? (
          <AIConversation
            session={live.session}
            theme={theme}
            mode={mode}
            onAction={onAction}
          />
        ) : (
          <div className="example__loading">starting aiux-wasm…</div>
        )}
        {actionLog.length > 0 ? (
          <aside className="example__log" aria-label="Action log">
            <h3>Host action log</h3>
            <ol>
              {actionLog.map((line, i) => (
                <li key={i}>
                  <code>{line}</code>
                </li>
              ))}
            </ol>
          </aside>
        ) : null}
      </main>
    </div>
  );
}

function ConformanceBadge({ state }: { state: Conformance }) {
  const label = {
    pending: "conformance: replaying…",
    pass: "conformance: PASS — serialize() === expected",
    fail: "conformance: FAIL — bytes differ",
    "n/a": "conformance: n/a",
  }[state];
  return (
    <span
      className={`example__conformance example__conformance--${state}`}
      role="status"
    >
      {label}
    </span>
  );
}
