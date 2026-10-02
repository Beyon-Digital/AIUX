#!/usr/bin/env node
// Release-notes generator — Phase 8 (plan §16).
//
// Builds a conventional-commit changelog between two refs:
//   node tools/release-notes.mjs [base-ref] [head-ref]
// (defaults: previous reachable tag → HEAD; falls back to full history when
// no earlier tag exists — e.g. the first release).
//
// Grouping: feat/fix/perf/docs/test/refactor/build/ci/chore + breaking.
// Non-conventional subjects land in "Other". Output is Markdown to stdout —
// release.yml pipes it into `gh release create --notes-file`.

import { execSync } from "node:child_process";

const [, , baseArg, headArg] = process.argv;
const head = headArg ?? "HEAD";

function sh(cmd) {
  return execSync(cmd, { encoding: "utf8" }).trim();
}

function defaultBase() {
  try {
    // newest tag reachable from head, excluding head's own tag
    return sh(`git describe --tags --abbrev=0 ${head}^ 2>/dev/null`);
  } catch {
    return "";
  }
}

const base = baseArg ?? defaultBase();
const range = base ? `${base}..${head}` : head;

const lines = sh(`git log ${range} --pretty=format:%s%x1f%h%x1f%an`)
  .split("\n")
  .filter(Boolean)
  .filter((l) => !/^Merge /.test(l))
  .map((l) => {
    const [subject, sha, author] = l.split("\x1f");
    return { subject, sha, author };
  });

const GROUPS = [
  ["breaking", /^(?:\w+(?:\([^)]*\))?!|BREAKING)/, "Breaking changes"],
  ["feat", /^feat(?:\([^)]*\))?!?:/, "Features"],
  ["fix", /^fix(?:\([^)]*\))?!?:/, "Fixes"],
  ["perf", /^perf(?:\([^)]*\))?:/, "Performance"],
  ["refactor", /^refactor(?:\([^)]*\))?:/, "Refactoring"],
  ["docs", /^docs(?:\([^)]*\))?:/, "Documentation"],
  ["test", /^test(?:\([^)]*\))?:/, "Tests"],
  ["build", /^build(?:\([^)]*\))?:/, "Build"],
  ["ci", /^ci(?:\([^)]*\))?:/, "CI"],
  ["chore", /^chore(?:\([^)]*\))?:/, "Chores"],
];

const buckets = new Map(GROUPS.map(([k]) => [k, []]));
const other = [];

for (const { subject, sha, author } of lines) {
  const clean = subject.replace(/^\w+(?:\([^)]*\))?!?:\s*/, "");
  const entry = `- ${clean} ([${sha}]) — ${author}`;
  const group = GROUPS.find(([, re]) => re.test(subject));
  if (group) buckets.get(group[0]).push(entry);
  else other.push(`- ${subject} ([${sha}]) — ${author}`);
}

const tagName = head === "HEAD" ? sh("git describe --tags --exact-match HEAD 2>/dev/null || echo upcoming") : head;

console.log(`## AIUX ${tagName}`);
console.log("");
if (base) console.log(`Changes since ${base} (${lines.length} commits).`);
else console.log(`First release — full history (${lines.length} commits).`);
console.log("");

for (const [key, , title] of GROUPS) {
  const items = buckets.get(key);
  if (!items.length) continue;
  console.log(`### ${title}`);
  console.log("");
  items.forEach((i) => console.log(i));
  console.log("");
}
if (other.length) {
  console.log("### Other");
  console.log("");
  other.forEach((i) => console.log(i));
  console.log("");
}
console.log(
  "All release artifacts derive from the tag commit; checksums in `SHA256SUMS`.",
);
