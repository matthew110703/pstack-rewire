#!/usr/bin/env node
// Mechanical, exact-token rewrites from the Cursor reference into a port.
// Prose that needs judgment is left for hand edits; see <port>/docs/harness/*.md.
// Usage: node tools/ports/tokens.mjs <codex|default> <portDir>
import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join, extname } from "node:path";

const [target, root] = process.argv.slice(2);
if (!["codex", "default"].includes(target) || !root) {
  console.error("usage: tokens.mjs <codex|default> <portDir>");
  process.exit(2);
}

const skills = readdirSync(join(root, "skills")).filter((n) => statSync(join(root, "skills", n)).isDirectory());
const skillAlt = skills.sort((a, b) => b.length - a.length).join("|");

const common = [
  [/\.cursor\/skills\//g, ".agents/skills/"],
  [/@cursor-skill\//g, target === "codex" ? "@codex-skill/" : "@agents-skill/"],
];

const rules = {
  codex: [
    [/`~\/\.cursor\/rules\/pstack-models\.mdc`/g, "the `pstack-models` block of `~/.codex/AGENTS.md`"],
    [/`pstack-models\.mdc` rule/g, "`pstack-models` block"],
    [/pstack-models\.mdc/g, "pstack-models block"],
    [/subagent_type: "poteto-agent"/g, 'agent_type: "poteto-agent"'],
    [/subagent_type: "comment-sicko"/g, 'agent_type: "comment-sicko"'],
    [/subagent_type: generalPurpose/g, 'agent_type: "worker"'],
    [/claude-opus-5-5-xhigh/g, "gpt-6-astra xhigh"],
    [/claude-opus-5-5-max/g, "gpt-6-astra max"],
    [/claude-opus-5-5-medium/g, "gpt-6-astra medium"],
    [/grok-4\.7-(xhigh|medium)-fast/g, "inherit-parent"],
    [/(~?\/?)\.cursor\/automations\/benny\//g, "$1.agents/automations/benny/"],
    [/\.cursor\/benny\//g, ".agents/benny/"],
    [new RegExp(`(?<![\\w./~:\\-$])/(${skillAlt})(?![\\w/\\-])`, "g"), "$$pstack:$1"],
  ],
  default: [
    [/`~\/\.cursor\/rules\/pstack-models\.mdc`/g, "`~/.agents/pstack-models.md`"],
    [/`pstack-models\.mdc` rule/g, "`~/.agents/pstack-models.md` file"],
    [/pstack-models\.mdc/g, "~/.agents/pstack-models.md"],
    [/claude-opus-5-5-(xhigh|max|medium)/g, "inherit"],
    [/grok-4\.7-(xhigh|medium)-fast/g, "inherit"],
    [/(~?\/?)\.cursor\/automations\/benny\//g, "$1.agents/automations/benny/"],
    [/\.cursor\/benny\//g, ".agents/benny/"],
  ],
}[target];

let changed = 0;
const walk = (dir) => {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (name === "node_modules" || name === ".git" || p.endsWith(join("docs", "harness"))) continue;
    const st = statSync(p);
    if (st.isDirectory()) walk(p);
    else if ([".md", ".yaml", ".json", ".lock", ".tsv"].includes(extname(name))) {
      const before = readFileSync(p, "utf8");
      let after = before;
      for (const [re, to] of [...common, ...rules]) after = after.replace(re, to);
      if (after !== before) {
        writeFileSync(p, after);
        changed++;
      }
    }
  }
};
walk(root);
console.log(`${target}: rewrote ${changed} files`);
