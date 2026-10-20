#!/usr/bin/env node
// GRIDLINE_MANAGED_CODEX_HOOK
const fs = require('node:fs');
const path = require('node:path');
const { buildMap } = require('./ponytail-map.js');

const projectRoot = path.resolve(__dirname, '../../..');
const contextPath = path.join(projectRoot, '.codex', 'ponytail.md');
const startMarker = '<!-- ponytail-map:start -->';
const endMarker = '<!-- ponytail-map:end -->';
const event = process.argv[2];

function updateMap() {
  const oldText = fs.readFileSync(contextPath, 'utf8');
  const start = oldText.indexOf(startMarker);
  const end = oldText.indexOf(endMarker);
  if (start < 0 || end < 0 || end < start ||
      oldText.indexOf(startMarker, start + startMarker.length) >= 0 ||
      oldText.indexOf(endMarker, end + endMarker.length) >= 0) return false;

  const map = buildMap(projectRoot) || 'No eligible source symbols found yet.';
  const nextText = oldText.slice(0, start + startMarker.length) + '\n' + map + '\n' + oldText.slice(end);
  if (nextText === oldText) return false;

  const tempPath = `${contextPath}.${process.pid}.tmp`;
  try {
    fs.writeFileSync(tempPath, nextText, { encoding: 'utf8', flag: 'wx', mode: 0o600 });
    fs.renameSync(tempPath, contextPath);
  } finally {
    try { fs.unlinkSync(tempPath); } catch {}
  }
  return true;
}

function emit(hookEventName, additionalContext) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName, additionalContext },
  }));
}

try {
  const changed = updateMap();
  if (event === 'session-start') {
    emit('SessionStart', fs.readFileSync(contextPath, 'utf8'));
  } else if (event === 'prompt-submit' || event === 'post-tool') {
    if (changed) emit(event === 'prompt-submit' ? 'UserPromptSubmit' : 'PostToolUse', fs.readFileSync(contextPath, 'utf8'));
    else process.stdout.write('{}');
  } else if (event === 'refresh') {
    process.stdout.write(changed ? 'Updated Ponytail project map.\n' : 'Ponytail project map is already current.\n');
  } else {
    process.stdout.write('{}');
  }
} catch {
  // Hook failures must not block the Codex session or expose paths in hook output.
  if (event === 'session-start') {
    try { emit('SessionStart', fs.readFileSync(contextPath, 'utf8')); }
    catch { process.stdout.write('{}'); }
  } else {
    process.stdout.write('{}');
  }
}
