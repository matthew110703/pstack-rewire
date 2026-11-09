#!/usr/bin/env node
// Codex injects only about the first 7,900 characters of an invoked skill (CLI 0.167:
// "Skill ... exceeded the main prompt context limit and was truncated"). For every longer
// SKILL.md, put a read-in-full instruction right under the title, inside the injected part.
// Usage: node tools/ports/codex-long-skills.mjs <portDir>
import { readFileSync, writeFileSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";

export const LIMIT = 7000;
export const NOTE =
  "This SKILL.md is longer than the part Codex injects. Before acting, read this whole file from the path Codex shows for it, then follow all of it.";

const root = process.argv[2];
let n = 0;
for (const name of readdirSync(join(root, "skills"))) {
  const file = join(root, "skills", name, "SKILL.md");
  if (!existsSync(file)) continue;
  let text = readFileSync(file, "utf8");
  const had = text.includes(NOTE);
  if (had) text = text.replace(`${NOTE}\n\n`, "");
  if (Buffer.byteLength(text) <= LIMIT) {
    if (had) writeFileSync(file, text);
    continue;
  }
  const m = text.match(/^(---\n[\s\S]*?\n---\n\s*)(# .*\n\n)?/);
  const head = m[0];
  text = head + NOTE + "\n\n" + text.slice(head.length);
  writeFileSync(file, text);
  n++;
}
console.log(`${root}: ${n} long skills carry the read-in-full note`);
