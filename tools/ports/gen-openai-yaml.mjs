#!/usr/bin/env node
// Writes agents/openai.yaml for each skill so Codex never invokes pstack skills implicitly
// (the Codex form of Cursor's `disable-model-invocation: true`), and, for --codex,
// strips SKILL.md frontmatter to the keys Codex honors (name, description).
// Usage: node tools/ports/gen-openai-yaml.mjs <portDir> <mention-prefix> [--strip]
//   mention-prefix: "$pstack:" for the Codex plugin, "$" for flat installs.
import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";

const [root, prefix, flag] = process.argv.slice(2);
const strip = flag === "--strip";
const IMPLICIT = new Set(["setup-pstack"]);
const q = (s) => JSON.stringify(s);

let n = 0;
for (const name of readdirSync(join(root, "skills"))) {
  const file = join(root, "skills", name, "SKILL.md");
  if (!existsSync(file)) continue;
  const text = readFileSync(file, "utf8");
  const m = text.match(/^---\n([\s\S]*?)\n---\n/);
  if (!m) throw new Error(`no frontmatter: ${file}`);
  const fm = m[1];
  const descLine = fm.match(/^description:\s*(.*(?:\n\s+.*)*)/m);
  let desc = descLine ? descLine[1].replace(/^>-?\s*/, "").replace(/\n\s+/g, " ").trim() : name;
  desc = desc.replace(/^"|"$/g, "").replace(/\\"/g, '"');
  let short = desc.split(/(?<=\.)\s/)[0];
  if (short.length > 120) short = short.slice(0, 117).replace(/\s+\S*$/, "") + "...";
  const yaml = [
    "interface:",
    `  display_name: ${q(name)}`,
    `  short_description: ${q(short)}`,
    `  default_prompt: ${q(`Use ${prefix}${name} for this task.`)}`,
    "policy:",
    `  allow_implicit_invocation: ${IMPLICIT.has(name)}`,
    "",
  ].join("\n");
  mkdirSync(join(root, "skills", name, "agents"), { recursive: true });
  writeFileSync(join(root, "skills", name, "agents", "openai.yaml"), yaml);
  if (strip) {
    const kept = fm.split("\n").filter((l, i, all) => {
      if (/^(name|description):/.test(l)) return true;
      if (/^\s/.test(l)) {
        for (let j = i - 1; j >= 0; j--) if (!/^\s/.test(all[j])) return /^description:/.test(all[j]);
      }
      return false;
    });
    writeFileSync(file, text.replace(m[0], `---\n${kept.join("\n")}\n---\n`));
  }
  n++;
}
console.log(`${root}: wrote ${n} openai.yaml files${strip ? ", stripped frontmatter" : ""}`);
