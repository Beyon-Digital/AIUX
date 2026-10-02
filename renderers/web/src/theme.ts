/**
 * AIUX theme contract (docs/PLAN.md §7) — platform-neutral semantic roles.
 *
 * Apps supply values per role; the web renderer maps every role to a CSS
 * custom property scoped to the component root (`--aiux-*`), so themes never
 * leak outside the conversation subtree. Light and dark ship as first-class
 * defaults; `colorScheme: "auto"` follows `prefers-color-scheme`.
 */

export interface AiuxThemeColors {
  background: string;
  /** Primary text color (renderer extension of the §7 role list — every
   * platform needs a body-text role even though the plan leaves it implied). */
  foreground: string;
  surface: string;
  surfaceElevated: string;
  userSurface: string;
  assistantSurface: string;
  accent: string;
  accentForeground: string;
  muted: string;
  border: string;
  destructive: string;
  success: string;
  warning: string;
}

export interface AiuxTypeRole {
  fontFamily: string;
  fontSize: string;
  fontWeight: number;
  lineHeight: number;
}

export interface AiuxThemeTypography {
  body: AiuxTypeRole;
  caption: AiuxTypeRole;
  label: AiuxTypeRole;
  heading: AiuxTypeRole;
  title: AiuxTypeRole;
  code: AiuxTypeRole;
}

export interface AiuxThemeSpacing {
  xs: string;
  sm: string;
  md: string;
  lg: string;
  xl: string;
}

export interface AiuxThemeRadius {
  sm: string;
  md: string;
  lg: string;
  full: string;
}

export interface AiuxThemeMotion {
  /** Base transition duration. */
  durationMs: number;
  /** Honor reduced-motion preferences (also auto-detected via media query). */
  reduce: boolean;
}

export type AiuxDensity = "compact" | "comfortable";
export type AiuxColorScheme = "light" | "dark" | "auto";

/** The app-facing theme input — every field optional, merged over defaults. */
export interface AiuxTheme {
  colorScheme?: AiuxColorScheme;
  colors?: Partial<AiuxThemeColors>;
  typography?: {
    [K in keyof AiuxThemeTypography]?: Partial<AiuxTypeRole>;
  };
  spacing?: Partial<AiuxThemeSpacing>;
  radius?: Partial<AiuxThemeRadius>;
  motion?: Partial<AiuxThemeMotion>;
  density?: AiuxDensity;
}

export interface ResolvedAiuxTheme {
  colorScheme: "light" | "dark";
  colors: AiuxThemeColors;
  typography: AiuxThemeTypography;
  spacing: AiuxThemeSpacing;
  radius: AiuxThemeRadius;
  motion: AiuxThemeMotion;
  density: AiuxDensity;
}

const SANS =
  'ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';
const MONO =
  'ui-monospace, "SF Mono", "Cascadia Code", "JetBrains Mono", Menlo, Consolas, monospace';

function typeRole(
  fontFamily: string,
  fontSize: string,
  fontWeight: number,
  lineHeight: number,
): AiuxTypeRole {
  return { fontFamily, fontSize, fontWeight, lineHeight };
}

const BASE_TYPOGRAPHY: AiuxThemeTypography = {
  body: typeRole(SANS, "0.9375rem", 400, 1.55),
  caption: typeRole(SANS, "0.8125rem", 400, 1.45),
  label: typeRole(SANS, "0.8125rem", 600, 1.3),
  heading: typeRole(SANS, "1.125rem", 650, 1.35),
  title: typeRole(SANS, "1.375rem", 700, 1.3),
  code: typeRole(MONO, "0.8125rem", 400, 1.55),
};

const BASE_SPACING: AiuxThemeSpacing = {
  xs: "0.25rem",
  sm: "0.5rem",
  md: "0.75rem",
  lg: "1rem",
  xl: "1.5rem",
};

const BASE_RADIUS: AiuxThemeRadius = {
  sm: "0.375rem",
  md: "0.625rem",
  lg: "0.875rem",
  full: "9999px",
};

export const LIGHT_COLORS: AiuxThemeColors = {
  background: "#ffffff",
  foreground: "#1a1d24",
  surface: "#f6f7f8",
  surfaceElevated: "#ffffff",
  userSurface: "#e8f0fe",
  assistantSurface: "#f6f7f8",
  accent: "#2563eb",
  accentForeground: "#ffffff",
  muted: "#667085",
  border: "#d9dde3",
  destructive: "#dc2626",
  success: "#16a34a",
  warning: "#d97706",
};

export const DARK_COLORS: AiuxThemeColors = {
  background: "#0f1115",
  foreground: "#e8eaed",
  surface: "#171a21",
  surfaceElevated: "#1e222b",
  userSurface: "#1d2f52",
  assistantSurface: "#171a21",
  accent: "#5b8def",
  accentForeground: "#0f1115",
  muted: "#98a2b3",
  border: "#2b303b",
  destructive: "#f87171",
  success: "#4ade80",
  warning: "#fbbf24",
};

function detectSystemScheme(): "light" | "dark" {
  if (
    typeof window !== "undefined" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia("(prefers-color-scheme: dark)").matches
  ) {
    return "dark";
  }
  return "light";
}

/** Resolve a user theme into concrete values (defaults + overrides). */
export function resolveTheme(theme: AiuxTheme = {}): ResolvedAiuxTheme {
  const scheme =
    theme.colorScheme === "dark" ||
    (theme.colorScheme !== "light" && detectSystemScheme() === "dark")
      ? "dark"
      : "light";
  const baseColors = scheme === "dark" ? DARK_COLORS : LIGHT_COLORS;
  const density = theme.density ?? "comfortable";
  const spacingScale = density === "compact" ? 0.8 : 1;
  // Compact density scales base tokens; explicit overrides pass through as-is.
  const scaledSpacing: AiuxThemeSpacing = Object.fromEntries(
    Object.entries(BASE_SPACING).map(([k, v]) => [
      k,
      theme.spacing?.[k as keyof AiuxThemeSpacing] ??
        (density === "compact" ? `calc(${v} * ${spacingScale})` : v),
    ]),
  ) as unknown as AiuxThemeSpacing;

  const typography = { ...BASE_TYPOGRAPHY };
  if (theme.typography) {
    for (const key of Object.keys(theme.typography) as (keyof AiuxThemeTypography)[]) {
      typography[key] = { ...typography[key], ...theme.typography[key] };
    }
  }

  return {
    colorScheme: scheme,
    colors: { ...baseColors, ...theme.colors },
    typography,
    spacing: scaledSpacing,
    radius: { ...BASE_RADIUS, ...theme.radius },
    motion: { durationMs: 160, reduce: false, ...theme.motion },
    density,
  };
}

/** Flatten a resolved theme to CSS custom properties for the component root. */
export function themeCssVars(theme: ResolvedAiuxTheme): Record<string, string> {
  const vars: Record<string, string> = {};
  for (const [role, value] of Object.entries(theme.colors)) {
    vars[`--aiux-color-${kebab(role)}`] = value;
  }
  for (const [role, t] of Object.entries(theme.typography)) {
    vars[`--aiux-font-${kebab(role)}`] =
      `${t.fontWeight} ${t.fontSize}/${t.lineHeight} ${t.fontFamily}`;
  }
  for (const [step, value] of Object.entries(theme.spacing)) {
    vars[`--aiux-space-${step}`] = value;
  }
  for (const [step, value] of Object.entries(theme.radius)) {
    vars[`--aiux-radius-${step}`] = value;
  }
  vars["--aiux-motion-duration"] = `${theme.motion.durationMs}ms`;
  return vars;
}

function kebab(name: string): string {
  return name.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`);
}
