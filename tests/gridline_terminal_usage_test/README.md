# Gridline per-terminal IN/OUT check

Run `./tests/gridline_terminal_usage_test/run.sh` from the repository root while the main Gridline build is current. This is an interactive UI check for the saved work groups whose names contain `1ABC` and `ZUZXY`.

The runner starts from fresh Gridline and Gridline Debug launches, then relaunches Gridline in test mode. Test 1 submits exactly `hello world!` followed by carriage return through terminal 1ABC's normal PTY path. It waits up to 15 seconds for Codex to be detected and then up to 15 seconds for changed, nonzero IN/OUT values and a resolved provider-session match. This exercises the same terminal submission and provider reader pipeline used by the UI. It then prints matching `terminal.inputSubmitted` and `TERMINAL_HEADER` usage events with the workgroup name, character counts, token counts, submission IDs, and Swift/Python source paths. The completed test prompt is saved to the ignored `gridline_debug/timeline.jsonl` while Gridline Debug is open; responses are not recorded. A transient progress file in `/tmp` is removed at cleanup; it is not a saved log.

The runner always quits and relaunches Gridline and Gridline Debug after Test 1, including when the check times out or fails. This ends the test terminal processes and clears the per-launch debug event log. The hot-reload watcher is left running; the test does not start a second watcher.

The test runs inside Gridline and sends input through the existing terminal PTY API; it does not require Accessibility permission for a separate helper.
