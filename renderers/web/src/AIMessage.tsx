import { forwardRef } from "react";
import { PartView } from "./parts.jsx";
import type { Message } from "./types.js";

const ROLE_LABEL: Record<Message["role"], string> = {
  user: "You",
  assistant: "Assistant",
  system: "System",
  tool: "Tool",
};

/**
 * One conversation message — an ARIA `article` inside the feed. Articles are
 * focus targets for the feed's roving keyboard navigation (focusable but not
 * in the Tab order).
 */
export const AIMessage = forwardRef<HTMLElement, { message: Message }>(
  function AIMessage({ message }, ref) {
    const streaming = message.status === "streaming";
    const label = `${ROLE_LABEL[message.role]} message${
      message.status ? `, ${message.status}` : ""
    }`;
    return (
      <article
        ref={ref}
        role="article"
        aria-label={label}
        tabIndex={-1}
        className={`aiux-msg aiux-msg--${message.role}${
          message.status ? ` aiux-msg--${message.status}` : ""
        }`}
        data-aiux-message={message.id}
      >
        <span className="aiux-msg__role" aria-hidden>
          {ROLE_LABEL[message.role]}
        </span>
        <div className="aiux-msg__body">
          {(message.parts ?? []).map((part) => (
            <PartView key={part.id} part={part} messageId={message.id} />
          ))}
          {streaming ? (
            <span className="aiux-msg__cursor" aria-hidden>
              ▍
            </span>
          ) : null}
        </div>
      </article>
    );
  },
);
