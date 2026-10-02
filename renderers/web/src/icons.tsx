import type { JSX } from "react";

/**
 * Semantic icon vocabulary — renderer-resolved names (Surface `icon` nodes,
 * status lines, attachment chips). Stroke-only 16×16 SVG paths so every icon
 * inherits `currentColor` and needs no theme assets.
 */

const PATHS: Record<string, JSX.Element> = {
  check: <path d="M3 8.5l3.5 3.5L13 4.5" />,
  x: <path d="M4 4l8 8M12 4l-8 8" />,
  warning: (
    <>
      <path d="M8 2.5L1.8 13h12.4L8 2.5z" />
      <path d="M8 6.5v3.2M8 11.4v.1" />
    </>
  ),
  info: (
    <>
      <circle cx="8" cy="8" r="6.2" />
      <path d="M8 7.4v3.4M8 5v.1" />
    </>
  ),
  success: (
    <>
      <circle cx="8" cy="8" r="6.2" />
      <path d="M5.2 8.2l2 2 3.6-4" />
    </>
  ),
  error: (
    <>
      <circle cx="8" cy="8" r="6.2" />
      <path d="M8 5v3.8M8 11v.1" />
    </>
  ),
  file: (
    <>
      <path d="M4 1.8h5.2L12 4.6v9.6H4z" />
      <path d="M9.2 1.8v2.8H12" />
    </>
  ),
  image: (
    <>
      <rect x="2" y="3" width="12" height="10" rx="1" />
      <circle cx="5.6" cy="6.4" r="1.2" />
      <path d="M2.5 11.5l3.4-3.2 2.6 2.4 3-2.8 2.5 2.3" />
    </>
  ),
  link: (
    <>
      <path d="M6.5 9.5l3-3" />
      <path d="M7.5 4.7l1.6-1.6a2.6 2.6 0 013.7 3.7L11.2 8.4" />
      <path d="M8.5 11.3l-1.6 1.6a2.6 2.6 0 01-3.7-3.7l1.6-1.6" />
    </>
  ),
  tool: (
    <path d="M9.9 2.6a3.4 3.4 0 00-4.4 4.3L2 13.4a1.1 1.1 0 001.6 1.6l6.5-6.5a3.4 3.4 0 004.3-4.4l-2.3 2.3-2-.5-.5-2 2.3-2.3" />
  ),
  clock: (
    <>
      <circle cx="8" cy="8" r="6.2" />
      <path d="M8 4.6V8l2.4 1.6" />
    </>
  ),
  spinner: (
    <path d="M8 2a6 6 0 11-6 6" />
  ),
  artifact: (
    <>
      <rect x="2.4" y="2.4" width="11.2" height="11.2" rx="1.4" />
      <path d="M5.4 8h5.2M5.4 5.6h5.2M5.4 10.4h3.2" />
    </>
  ),
  citation: (
    <path d="M3.5 11.6c0-4.4 2.1-6.9 5.4-8.2l.6 1.1c-2 .9-3 2.2-3.2 3.8.2-.1.5-.1.8-.1 1.4 0 2.4 1 2.4 2.4s-1 2.4-2.4 2.4c-1.9 0-3.6-1.4-3.6-1.4z" />
  ),
  attachment: (
    <path d="M11.5 7.2L7 11.7a2.7 2.7 0 01-3.8-3.8l5.3-5.3a1.8 1.8 0 012.6 2.5L6 10.3a.9.9 0 01-1.3-1.3l4.5-4.5" />
  ),
  send: <path d="M14 2L7.3 8.7M14 2l-4.2 12-2.5-5.3L2 6.2 14 2z" />,
  copy: (
    <>
      <rect x="5.5" y="5.5" width="8" height="8" rx="1" />
      <path d="M10.5 5.5v-2a1 1 0 00-1-1h-6a1 1 0 00-1 1v6a1 1 0 001 1h2" />
    </>
  ),
  chevron: <path d="M5 3.5L10.5 8 5 12.5" />,
  star: (
    <path d="M8 2.2l1.8 3.7 4.1.6-3 2.9.7 4L8 11.6l-3.6 1.8.7-4-3-2.9 4.1-.6L8 2.2z" />
  ),
};

const SIZE_PX: Record<string, number> = { sm: 12, md: 16, lg: 20 };

export interface AiuxIconProps {
  name: string;
  size?: "sm" | "md" | "lg" | undefined;
  /** Extra accessible label; omit for decorative use. */
  label?: string | undefined;
}

export function AiuxIcon({ name, size = "md", label }: AiuxIconProps) {
  const px = SIZE_PX[size] ?? 16;
  const path = PATHS[name];
  const labelled = label !== undefined && label !== "";
  return (
    <svg
      className="aiux-icon"
      width={px}
      height={px}
      viewBox="0 0 16 16"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden={labelled ? undefined : true}
      role={labelled ? "img" : undefined}
      aria-label={labelled ? label : undefined}
      focusable="false"
    >
      {path ?? <circle cx="8" cy="8" r="3" fill="currentColor" stroke="none" />}
    </svg>
  );
}
