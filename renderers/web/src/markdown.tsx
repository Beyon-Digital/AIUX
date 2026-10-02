import { memo } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

/**
 * Safe markdown rendering (docs/PLAN.md §23): markdown parses to an AST which
 * is rendered as React elements — no `dangerouslySetInnerHTML` anywhere, and
 * raw HTML embedded in the source is never executed (react-markdown drops it
 * by default; we additionally keep `skipHtml` explicit).
 */

const SAFE_URL = /^(https?:|mailto:|tel:|#|\/|\.\/|\.\.\/)/i;

/** Drop non-web / script-capable URL schemes (`javascript:`, `data:`, `vbscript:`). */
function safeUrl(url: string): string {
  return SAFE_URL.test(url.trim()) ? url : "";
}

const COMPONENTS = {
  a: ({ href, children, ...rest }: React.ComponentProps<"a">) => {
    const safe = href ? safeUrl(href) : "";
    if (!safe) {
      // Untrusted scheme — render the label as plain text, never a link.
      return <span>{children}</span>;
    }
    const external = /^https?:/i.test(safe);
    return (
      <a
        href={safe}
        {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
        {...rest}
      >
        {children}
      </a>
    );
  },
};

/** Protocol-safe markdown → React elements. Memoized on source text. */
export const AiuxMarkdown = memo(function AiuxMarkdown({
  source,
}: {
  source: string;
}) {
  return (
    <ReactMarkdown
      remarkPlugins={[remarkGfm]}
      skipHtml
      urlTransform={safeUrl}
      components={COMPONENTS}
    >
      {source}
    </ReactMarkdown>
  );
});
