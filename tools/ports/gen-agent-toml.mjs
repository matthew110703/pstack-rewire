#!/usr/bin/env node
// Converts markdown agent definitions (frontmatter name/description + body) into Codex agent TOML.
// Usage: node tools/ports/gen-agent-toml.mjs <out-dir> <agent.md>...
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, basename } from "node:path";

const [out, ...files] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const tomlString = (s) => JSON.stringify(s);
for (const f of files) {
  const text = readFileSync(f, "utf8");
  const m = text.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!m) throw new Error(`no frontmatter: ${f}`);
  const get = (k) => (m[1].match(new RegExp(`^${k}:\\s*(.*)$`, "m")) || [])[1]?.replace(/^"|"$/g, "");
  const name = get("name") || basename(f, ".md");
  const body = m[2].trim();
  if (body.includes("'''")) throw new Error(`body contains ''' : ${f}`);
  const toml = [
    "# managed-by: pstack-rewire. Reinstalling pstack overwrites this file; remove this line to keep local edits.",
    `name = ${tomlString(name)}`,
    `description = ${tomlString(get("description") || name)}`,
    `developer_instructions = '''`,
    body,
    `'''`,
    "",
  ].join("\n");
  writeFileSync(join(out, `${name}.toml`), toml);
  console.log(`wrote ${join(out, name + ".toml")}`);
}
