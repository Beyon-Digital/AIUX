/**
 * Minimal OpenRouter client for the live demo — React Native's fetch cannot
 * stream response bodies on Android, so this reads SSE progressively off an
 * XMLHttpRequest's growing `responseText` (the standard RN trick).
 *
 * Key handling: the key is passed in by the caller and never stored in a
 * file or logged — `EXPO_PUBLIC_OPEN_ROUTER` inline-bundles it at build time
 * for the dev app only.
 */

export type ChatMessage = {
  role: "system" | "user" | "assistant" | "tool";
  content: string | null;
  tool_call_id?: string;
  tool_calls?: ToolCall[];
};

export type ToolCall = {
  id: string;
  type: "function";
  function: { name: string; arguments: string };
};

export type ToolDefinition = {
  type: "function";
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
};

export type StreamCallbacks = {
  onDelta: (text: string) => void;
  /** Streamed tool calls, arguments fully accumulated, in emission order. */
  onToolCalls: (calls: ToolCall[]) => void;
  onDone: (finishReason: string | null) => void;
  onError: (code: string, message: string) => void;
};

export type StreamHandle = { abort: () => void };

const ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";

/**
 * Streams a chat completion. `onDelta` fires per content fragment; when the
 * model requests tools instead, `onToolCalls` fires once at seal — args are
 * accumulated as raw strings and only parsed by the caller at completion
 * (never early: a scalar prefix like `1` parses before `12` arrives).
 */
export function streamChatCompletion(
  apiKey: string,
  model: string,
  messages: ChatMessage[],
  tools: ToolDefinition[] | undefined,
  cb: StreamCallbacks,
): StreamHandle {
  const xhr = new XMLHttpRequest();
  let offset = 0;
  let lineBuf = "";
  let sawDone = false;
  let settled = false;
  // RN Android's xhr.abort() does not reliably sever an in-flight SSE
  // response — chunks can keep arriving afterwards. `aborted` makes every
  // downstream callback a no-op so post-cancel deltas are dropped here.
  let aborted = false;
  let finishReason: string | null = null;
  const toolAcc = new Map<number, ToolCall>();

  const fail = (code: string, message: string) => {
    if (settled || aborted) return;
    settled = true;
    cb.onError(code, message);
  };

  const handleLine = (line: string) => {
    if (aborted) return;
    const trimmed = line.trim();
    if (!trimmed.startsWith("data:")) return;
    const data = trimmed.slice(5).trim();
    if (data === "[DONE]") {
      sawDone = true;
      return;
    }
    let chunk: {
      choices?: Array<{
        delta?: {
          content?: string | null;
          tool_calls?: Array<{
            index: number;
            id?: string;
            type?: string;
            function?: { name?: string; arguments?: string };
          }>;
        };
        finish_reason?: string | null;
      }>;
      error?: { code?: number | string; message?: string };
    };
    try {
      chunk = JSON.parse(data);
    } catch {
      return; // keepalive/partial frames — skip
    }
    if (chunk.error) {
      fail(String(chunk.error.code ?? "openrouter"), chunk.error.message ?? "stream error");
      return;
    }
    const choice = chunk.choices?.[0];
    if (!choice) return;
    const delta = choice.delta;
    if (typeof delta?.content === "string" && delta.content.length > 0) {
      cb.onDelta(delta.content);
    }
    for (const tc of delta?.tool_calls ?? []) {
      const acc = toolAcc.get(tc.index) ?? {
        id: tc.id ?? `call_${tc.index}`,
        type: "function" as const,
        function: { name: "", arguments: "" },
      };
      if (tc.id) acc.id = tc.id;
      if (tc.function?.name) acc.function.name = tc.function.name;
      if (tc.function?.arguments) acc.function.arguments += tc.function.arguments;
      toolAcc.set(tc.index, acc);
    }
    if (choice.finish_reason) finishReason = choice.finish_reason;
  };

  const pump = () => {
    if (aborted) return;
    const text = xhr.responseText ?? "";
    let next = text.indexOf("\n", offset);
    while (next >= 0) {
      const piece = text.slice(offset, next);
      offset = next + 1;
      lineBuf += piece;
      handleLine(lineBuf);
      lineBuf = "";
      next = text.indexOf("\n", offset);
    }
    lineBuf += text.slice(offset);
    offset = text.length;
  };

  xhr.onprogress = pump;
  xhr.onreadystatechange = () => {
    if (xhr.readyState === XMLHttpRequest.DONE) {
      pump();
      if (lineBuf.trim()) {
        handleLine(lineBuf);
        lineBuf = "";
      }
      if (settled || aborted) return;
      if (xhr.status === 0) {
        // RN XHR reports connectivity failures as DONE with status 0
        // rather than firing onerror.
        fail("NETWORK", "network unreachable — check connectivity and retry");
        return;
      }
      if (xhr.status < 200 || xhr.status >= 300) {
        let message = `HTTP ${xhr.status}`;
        try {
          const body = JSON.parse(xhr.responseText ?? "{}") as {
            error?: { message?: string };
          };
          if (body.error?.message) message = `${message}: ${body.error.message}`;
        } catch {
          /* non-JSON error body */
        }
        fail(`HTTP_${xhr.status}`, message);
        return;
      }
      if (aborted) return;
      settled = true;
      if (toolAcc.size > 0) {
        cb.onToolCalls([...toolAcc.keys()].sort().map((i) => toolAcc.get(i)!));
      }
      cb.onDone(sawDone ? finishReason : finishReason ?? "closed");
    }
  };
  xhr.onerror = () => fail("NETWORK", "request failed (offline or blocked)");
  xhr.onabort = () => {
    aborted = true;
  };
  xhr.ontimeout = () => fail("TIMEOUT", "request timed out");

  xhr.open("POST", ENDPOINT, true);
  xhr.setRequestHeader("content-type", "application/json");
  xhr.setRequestHeader("authorization", `Bearer ${apiKey}`);
  xhr.setRequestHeader("http-referer", "https://beyondigital.in/aiux-demo");
  xhr.setRequestHeader("x-title", "AIUX live demo");
  xhr.timeout = 120_000;
  xhr.send(
    JSON.stringify({
      model,
      messages,
      stream: true,
      ...(tools && tools.length > 0 ? { tools, tool_choice: "auto" } : {}),
    }),
  );

  return {
    abort: () => {
      aborted = true;
      xhr.abort();
    },
  };
}
