// Skill commands for OpenCode.
//
// Registers one slash command per globally discovered SKILL.md so skills
// autocomplete in the TUI. Skills themselves are available without this plugin
// (the `skill` tool and the /skills pane); only the `/skill-name` autocomplete
// entry needs a command. Auto-loaded from ~/.config/opencode/plugins/.

import fs from "fs";
import os from "os";
import path from "path";

const MAX_DEPTH = 6;

// Built-in TUI commands and aliases (docs: opencode.ai/docs/tui#commands).
const RESERVED = new Set([
  "agent",
  "clear",
  "compact",
  "connect",
  "continue",
  "details",
  "editor",
  "exit",
  "export",
  "help",
  "init",
  "models",
  "new",
  "q",
  "quit",
  "redo",
  "resume",
  "sessions",
  "share",
  "skill",
  "skills",
  "summarize",
  "themes",
  "thinking",
  "undo",
  "unshare",
]);

const validName = (name) => /^[a-z0-9]+(-[a-z0-9]+)*$/.test(name);

function frontmatter(content) {
  const match = content.match(/^---[^\S\r\n]*\r?\n([\s\S]*?)\r?\n---[^\S\r\n]*/);
  if (!match) return {};
  const lines = match[1].split(/\r?\n/);
  const fields = {};
  for (let i = 0; i < lines.length; i++) {
    if (/^\s/.test(lines[i])) continue;
    const colon = lines[i].indexOf(":");
    if (colon <= 0) continue;
    const key = lines[i].slice(0, colon).trim();
    let value = lines[i].slice(colon + 1).trim();
    if (value === ">" || value === "|" || value === ">-" || value === "|-") {
      const block = [];
      while (i + 1 < lines.length && (/^\s+\S/.test(lines[i + 1]) || lines[i + 1].trim() === "")) {
        block.push(lines[++i].trim());
      }
      value = block.join(" ").trim();
    }
    fields[key] = value.replace(/^["']|["']$/g, "");
  }
  return fields;
}

function skillFiles(dir, depth = 0, found = [], seen = new Set()) {
  if (depth > MAX_DEPTH) return found;
  let real;
  try {
    real = fs.realpathSync(dir);
  } catch {
    return found;
  }
  if (seen.has(real)) return found;
  seen.add(real);
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return found;
  }
  for (const entry of entries) {
    if (entry.name.startsWith(".")) continue;
    const full = path.join(dir, entry.name);
    let isDirectory = entry.isDirectory();
    if (!isDirectory && entry.isSymbolicLink()) {
      try {
        isDirectory = fs.statSync(full).isDirectory();
      } catch {
        continue;
      }
    }
    if (isDirectory) skillFiles(full, depth + 1, found, seen);
    else if (entry.name === "SKILL.md") found.push(full);
  }
  return found;
}

function commandFileNames(dir, names) {
  try {
    for (const entry of fs.readdirSync(dir)) {
      if (entry.endsWith(".md")) names.add(entry.slice(0, -3));
    }
  } catch {
    // Missing command directory: nothing to reserve.
  }
  return names;
}

export const SkillCommandsPlugin = async ({ directory }) => ({
  config: async (config) => {
    try {
      const home = os.homedir();
      const configDir = path.join(
        process.env.XDG_CONFIG_HOME || path.join(home, ".config"),
        "opencode",
      );

      const roots = [
        ...(config.skills?.paths ?? []),
        path.join(configDir, "skills"),
        path.join(home, ".claude", "skills"),
        path.join(home, ".agents", "skills"),
      ];

      const taken = new Set([...RESERVED, ...Object.keys(config.command ?? {})]);
      for (const dir of [
        path.join(configDir, "command"),
        path.join(configDir, "commands"),
        path.join(directory ?? "", ".opencode", "command"),
        path.join(directory ?? "", ".opencode", "commands"),
      ]) {
        commandFileNames(dir, taken);
      }

      config.command = config.command ?? {};
      for (const root of new Set(roots)) {
        for (const file of skillFiles(root)) {
          const name = path.basename(path.dirname(file));
          if (!validName(name) || taken.has(name)) continue;
          let description;
          try {
            description = frontmatter(fs.readFileSync(file, "utf8")).description;
          } catch {
            description = undefined;
          }
          taken.add(name);
          config.command[name] = {
            description: description || `Load the ${name} skill`,
            template: `Use the skill tool to load the \`${name}\` skill and follow it exactly.\n\n$ARGUMENTS`,
          };
        }
      }
    } catch {
      // Never break opencode startup over command generation.
    }
  },
});
