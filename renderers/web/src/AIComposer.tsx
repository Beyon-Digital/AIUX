import { useRef, useState, type JSX } from "react";
import { AiuxIcon } from "./icons.jsx";
import { useFilePicker } from "./hooks.js";
import { AIUX_ACTIONS, type AiuxAction } from "./types.js";

export interface AIComposerProps {
  /** Emits `aiux.composer.submit` / `aiux.composer.attach` (§23 — host decides). */
  onAction?: ((action: AiuxAction) => void) | undefined;
  /** Show the attach affordance (capability-gated by the parent). */
  attachmentsEnabled?: boolean | undefined;
  /** Disable input while a run is in-flight. */
  disabled?: boolean | undefined;
  placeholder?: string | undefined;
}

/**
 * Composer — the one place the renderer produces new user input. Submitting
 * emits a semantic action; the host dispatches the resulting protocol events.
 * Enter submits, Shift+Enter inserts a newline, Escape clears.
 */
export function AIComposer({
  onAction,
  attachmentsEnabled = true,
  disabled = false,
  placeholder = "Message…",
}: AIComposerProps): JSX.Element {
  const [text, setText] = useState("");
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const picker = useFilePicker((files) =>
    onAction?.({ id: AIUX_ACTIONS.composerAttach, payload: { files } }),
  );

  const submit = () => {
    const value = text.trim();
    if (!value || !onAction || disabled) return;
    onAction({
      id: AIUX_ACTIONS.composerSubmit,
      payload: { text: value },
    });
    setText("");
    // Focus returns to the input — keyboard flow never leaves the composer.
    textareaRef.current?.focus();
  };

  return (
    <form
      className="aiux-composer"
      aria-label="Composer"
      onSubmit={(e) => {
        e.preventDefault();
        submit();
      }}
    >
      {attachmentsEnabled ? (
        <>
          <button
            type="button"
            className="aiux-btn aiux-btn--ghost aiux-composer__attach"
            aria-label="Attach files"
            disabled={disabled || !onAction}
            onClick={picker.open}
          >
            <AiuxIcon name="attachment" />
          </button>
          <input {...picker.inputProps} aria-hidden tabIndex={-1} />
        </>
      ) : null}
      <textarea
        ref={textareaRef}
        className="aiux-composer__input"
        aria-label="Message"
        placeholder={placeholder}
        rows={1}
        value={text}
        disabled={disabled}
        onChange={(e) => setText(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            submit();
          } else if (e.key === "Escape" && text) {
            e.preventDefault();
            setText("");
          }
        }}
      />
      <button
        type="submit"
        className="aiux-btn aiux-btn--primary aiux-composer__send"
        aria-label="Send message"
        disabled={disabled || !onAction || !text.trim()}
      >
        <AiuxIcon name="send" />
      </button>
    </form>
  );
}
