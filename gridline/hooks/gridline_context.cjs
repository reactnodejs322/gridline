#!/usr/bin/env node
// GRIDLINE_MANAGED_CLAUDE_HOOK
const fs = require('node:fs');
const path = require('node:path');

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => { input += chunk; });
process.stdin.on('end', () => {
  try {
    const event = JSON.parse(input);
    const root = process.env.CLAUDE_PROJECT_DIR || event.cwd || process.cwd();
    let hooks = {};
    try { hooks = JSON.parse(fs.readFileSync(path.join(root, '.codex/hooks.json'), 'utf8')).hooks || {}; } catch {}
    let claudeSettings = {};
    try { claudeSettings = JSON.parse(fs.readFileSync(path.join(root, '.claude/settings.json'), 'utf8')); } catch {}
    const claudeHooks = claudeSettings.hooks || {};
    const rustEnabled = fs.existsSync(path.join(root, '.claude/hooks/gridline/rust-enabled'));
    const docs = [
      ['.codex/ponytail.md', 'ponytail_context.cjs'],
      ['app_design/this_app_design_today.md', 'map_design_context.cjs'],
      ['.codex/RUST_SKILL.md', 'rust_skill_context.cjs'],
    ];
    const active = docs.filter(([file, hook]) => fs.existsSync(path.join(root, file)) &&
      (hook === 'rust_skill_context.cjs' ? rustEnabled : JSON.stringify(hooks).includes(hook) || JSON.stringify(claudeHooks).includes(hook)));
    const content = Array.from(active.map(([file]) => `Project guidance from ${file}:\n\n${fs.readFileSync(path.join(root, file), 'utf8')}`).join('\n\n---\n\n'));
    const part = Number(process.argv[4]);
    const parts = Number(process.argv[5]);
    if (Number.isInteger(part) && part >= 0 && Number.isInteger(parts) && parts > part && content.length > part * 4000) {
      const hookEventName = event.hook_event_name === 'SessionStart' ? 'SessionStart' : 'UserPromptSubmit';
      let chunk = content.slice(part * 4000, (part + 1) * 4000).join('');
      if (part === parts - 1 && content.length > parts * 4000) chunk += '\nGridline guidance is incomplete; refresh the project hooks.';
      process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName, additionalContext: `Gridline guidance part ${part + 1} of ${parts}:\n${chunk}` } }));
    } else {
      process.stdout.write('{}');
    }
  } catch {
    process.stdout.write('{}');
  }
});
