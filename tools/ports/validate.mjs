#!/usr/bin/env node
// Static checks for a generated port.
// Usage: node tools/ports/validate.mjs <codex|default> <portDir>
import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const [target, root] = process.argv.slice(2);
const token = target === "codex" ? "<pstack>" : "<skills>";
const base = target === "codex" ? root : join(root, "skills");
const problems = [];

for (const name of readdirSync(join(root, "skills"))) {
  const dir = join(root, "skills", name);
  if (!statSync(dir).isDirectory()) continue;
  const text = readFileSync(join(dir, "SKILL.md"), "utf8");
  const fm = (text.match(/^---\n([\s\S]*?)\n---\n/) || [])[1];
  if (!fm) { problems.push(`${name}: no frontmatter`); continue; }
  const keys = fm.split("\n").filter((l) => /^[a-z-]+:/.test(l)).map((l) => l.split(":")[0]);
  if ((fm.match(/^name:\s*(.*)$/m) || [])[1]?.trim() !== name) problems.push(`${name}: name does not match dir`);
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(name) || name.length > 64) problems.push(`${name}: invalid Agent Skills name`);
  if (target === "codex" && keys.some((k) => !["name", "description"].includes(k))) problems.push(`${name}: extra frontmatter keys ${keys}`);
  if (target === "codex" && Buffer.byteLength(text) > 7000) {
    const at = text.indexOf("This SKILL.md is longer than the part Codex injects.");
    if (at < 0 || at > 2000) problems.push(`${name}: long skill without an early read-in-full note`);
  }
  const yaml = join(dir, "agents", "openai.yaml");
  if (!existsSync(yaml)) problems.push(`${name}: missing agents/openai.yaml`);
  else {
    const implicit = /allow_implicit_invocation:\s*true/.test(readFileSync(yaml, "utf8"));
    if (implicit !== (name === "setup-pstack")) problems.push(`${name}: wrong allow_implicit_invocation`);
  }
}

const walk = (dir, out = []) => {
  for (const n of readdirSync(dir)) {
    const p = join(dir, n);
    if (n === "node_modules") continue;
    if (statSync(p).isDirectory()) walk(p, out);
    else if (n.endsWith(".md")) out.push(p);
  }
  return out;
};
const pathRe = new RegExp(`${token.replace(/[<>]/g, "\\$&")}/([A-Za-z0-9_./-]+)`, "g");
for (const f of walk(root)) {
  if (f.includes(join("docs", "harness"))) continue;
  const text = readFileSync(f, "utf8");
  for (const m of text.matchAll(pathRe)) {
    let p = m[1].replace(/[.,;:)]+$/, "");
    if (/<|\*/.test(p) || p.endsWith("/")) p = p.replace(/\/[^/]*[<*].*$/, "").replace(/\/$/, "");
    if (!p || p === "skills" || p.endsWith("-")) continue;
    if (!existsSync(join(base, p))) problems.push(`${relative(root, f)}: missing ${token}/${m[1]}`);
  }
}

if (problems.length) {
  console.log(problems.join("\n"));
  console.log(`${target}: ${problems.length} problem(s)`);
  process.exit(1);
}
console.log(`${target}: OK`);
