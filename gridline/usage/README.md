# Provider pricing maintenance

This guide is for the next developer or coding LLM that changes Gridline's
provider usage estimates. **Before changing a rate, check the provider's live
official API pricing page. Do not trust a price remembered from an earlier
task, copied from a third-party site, or inferred from a model's name.**

## Official rate cards

- OpenAI API: <https://developers.openai.com/api/docs/pricing>
- Anthropic API: <https://platform.claude.com/docs/en/about-claude/pricing>

Gridline does not fetch these pages on every refresh. The pages are intended
for people and their layout can change; scraping them in the running app could
silently produce wrong estimates. Keep a reviewed local rate snapshot and
update it from the official page when the model or pricing changes.

## Update procedure for an LLM

1. Read both `codex_cost_estimate.py` and `claude_usage.py` to identify which
   local model IDs and usage fields Gridline actually sees.
2. Browse the relevant official rate card above during this update. Match the
   exact model ID or a documented model alias, and verify standard input,
   cached input/read, cache writes when applicable, and output rates.
3. Keep rates in USD per million tokens. Preserve the token-category order
   documented immediately above each pricing map in its script.
4. If the official page does not publish a rate for an encountered model, do
   not guess, borrow a neighboring model's rate, or report it as `$0`. Leave
   that model unpriced and expose it through `unpricedModels`.
5. Update the source URL and the `Last verified` date below whenever a map is
   changed. Keep the estimate explicitly labeled API-equivalent, not a bill or
   subscription charge.
6. Do not use API token prices to derive ChatGPT subscription usage. The
   ChatGPT header meter uses the locally reported weekly plan allowance; its
   displayed plan-value amount is that percentage of the configured `$20`
   plan price.

## Per-terminal live usage

- `terminal_usage.py` tails only active Codex/Claude session logs associated
  with Gridline terminal process trees. It emits one machine-readable snapshot
  per Gridline terminal every three seconds.
- The script reads model, session, and token-usage metadata only. It does not
  emit or save prompts, assistant text, terminal output, or keystrokes.
- A terminal is matched to a provider log using the active provider process,
  its working folder, and the log's creation/update times. When focus and a new
  file update establish a match, the reader pins that file to the terminal's
  provider-process PID. Later focus changes cannot transfer its counts to a
  neighboring terminal. A newly created file can establish a new match after
  that terminal is focused; unclear matches remain unassigned.
- Codex session totals come from per-thread `total_token_usage`; the newest
  request's `last_token_usage` is exposed separately as latest-turn IN/OUT.
  The terminal popover labels both scopes so cumulative IN is not mistaken for
  the size of one short prompt. Per-turn deltas are priced using the model
  attached to each turn. Claude totals and estimates use assistant usage
  records within the matched session file.
- The `gridline.workspace.tokenUsage` popover has a separate
  `gridline.workspace.terminalUsage.disable` setting. Pausing stops this local
  watcher for every terminal and keeps the last in-memory snapshots visible;
  it does not change ChatGPT allowance polling or the Claude weekly meter.
- Estimates remain API-equivalent comparisons, not subscription charges.
  Unknown model rates are reported without pricing rather than treated as `$0`.
- Runtime diagnosis is documented in `AGENTS.md` under [Swift and external-script runtime state](../../AGENTS.md#swift-and-external-script-runtime-state). It covers the Swift snapshot events, Python reader status, and the difference between build logs and runtime state.
- Swift-launched usage readers use the shared `gridline/runtime/gridline_trace.py` stage helper and `DebugEvents.configurePythonProcess`; trace entries appear only while Gridline Debug is open and contain no exception messages or local paths.

## Current local rate snapshot

- Last verified: 2026-10-07
- OpenAI rates: `codex_cost_estimate.py` (`PRICING_PER_MILLION`)
- Anthropic rates: `claude_usage.py` (`PRICING_PER_MILLION`)
- Claude estimate window: rolling seven days of local assistant usage metadata
- Codex estimate window: local Codex session metadata; current map prices the
  short-context standard tier because local records do not reliably identify
  a separate billing tier
