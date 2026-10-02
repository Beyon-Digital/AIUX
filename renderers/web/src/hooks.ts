import { useCallback, useEffect, useRef, useState } from "react";
import type { AiuxSnapshot, AiuxSessionLike } from "./types.js";

/**
 * Subscribe a React tree to an `AiuxSessionLike`: initial snapshot on mount,
 * then the fresh snapshot the session publishes after every mutation.
 */
export function useSessionSnapshot(session: AiuxSessionLike): AiuxSnapshot {
  const [snapshot, setSnapshot] = useState<AiuxSnapshot>(
    () => session.snapshot() as AiuxSnapshot,
  );
  useEffect(() => {
    // Re-sync on session swap: subscribe may not emit immediately, so pull the
    // new session's current snapshot instead of showing the previous one.
    setSnapshot(session.snapshot() as AiuxSnapshot);
    return session.subscribe((next) => setSnapshot(next as AiuxSnapshot));
  }, [session]);
  return snapshot;
}

/** Metadata for one file picked via the browser file picker or drag/drop. */
export interface PickedFile {
  name: string;
  sizeBytes: number;
  mimeType?: string;
}

function toPickedFile(file: File): PickedFile {
  return {
    name: file.name,
    sizeBytes: file.size,
    ...(file.type ? { mimeType: file.type } : {}),
  };
}

/**
 * File-picker hook for the composer attach affordance. Returns a hidden
 * `<input type="file">` element ref + `open()` + props to spread on it.
 * Selected files surface as metadata only (host-mediated upload — §23).
 */
export function useFilePicker(
  onFiles: (files: PickedFile[]) => void,
  options: { multiple?: boolean; accept?: string } = {},
) {
  const inputRef = useRef<HTMLInputElement>(null);
  const open = useCallback(() => inputRef.current?.click(), []);
  const inputProps = {
    ref: inputRef,
    type: "file" as const,
    multiple: options.multiple ?? true,
    ...(options.accept ? { accept: options.accept } : {}),
    style: { display: "none" } as const,
    onChange: (e: React.ChangeEvent<HTMLInputElement>) => {
      const files = Array.from(e.target.files ?? []).map(toPickedFile);
      e.target.value = "";
      if (files.length > 0) onFiles(files);
    },
  };
  return { open, inputProps };
}

/**
 * Drag/drop hook for the conversation root. Tracks an `active` flag while a
 * file drag is over the drop zone (for styling) and reports dropped files.
 */
export function useFileDrop(
  onFiles: (files: PickedFile[]) => void,
  enabled: boolean,
) {
  const [active, setActive] = useState(false);
  const depth = useRef(0);
  const reset = useCallback(() => {
    depth.current = 0;
    setActive(false);
  }, []);

  const props = {
    onDragEnter: (e: React.DragEvent) => {
      if (!enabled) return;
      if (!e.dataTransfer.types.includes("Files")) return;
      depth.current += 1;
      setActive(true);
    },
    onDragOver: (e: React.DragEvent) => {
      if (!enabled) return;
      if (!e.dataTransfer.types.includes("Files")) return;
      e.preventDefault();
      e.dataTransfer.dropEffect = "copy";
    },
    onDragLeave: (e: React.DragEvent) => {
      if (!enabled) return;
      depth.current = Math.max(0, depth.current - 1);
      if (depth.current === 0) setActive(false);
    },
    onDrop: (e: React.DragEvent) => {
      if (!enabled) return;
      if (!e.dataTransfer.types.includes("Files")) return;
      e.preventDefault();
      reset();
      const files = Array.from(e.dataTransfer.files).map(toPickedFile);
      if (files.length > 0) onFiles(files);
    },
  };
  return { active, props };
}

/** Clipboard copy with a transient "copied" confirmation flag. */
export function useCopyToClipboard(): {
  copied: boolean;
  copy: (text: string) => void;
} {
  const [copied, setCopied] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(
    () => () => {
      if (timer.current !== undefined) clearTimeout(timer.current);
    },
    [],
  );
  const copy = useCallback((text: string) => {
    const mark = () => {
      setCopied(true);
      if (timer.current !== undefined) clearTimeout(timer.current);
      timer.current = setTimeout(() => setCopied(false), 1600);
    };
    if (navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(text).then(mark, mark);
      return;
    }
    // Fallback for non-secure contexts / older browsers.
    const el = document.createElement("textarea");
    el.value = text;
    el.style.position = "fixed";
    el.style.opacity = "0";
    document.body.appendChild(el);
    el.select();
    try {
      document.execCommand("copy");
    } finally {
      el.remove();
    }
    mark();
  }, []);
  return { copied, copy };
}
