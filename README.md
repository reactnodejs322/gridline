<p align="left">
  <img src="https://img.shields.io/badge/macOS-13%2B%20Support-18181b?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="macOS 13+ support" />
  <a href="#vibe-code-your-terminal-workflow"><img src="https://img.shields.io/badge/Vibe--code-Your%20Workflow-ff3045?style=for-the-badge" alt="Vibe-code your workflow" /></a>
</p>

<div align="center">
  <img src="logo/Gridline2x.png" alt="Gridline logo" width="160" />
  <h1>Gridline</h1>
  <p><strong><img src="logo/tab-phantom.svg" alt="A tab phantom" width="48" align="middle" /> Lost in the terminal tab maze?</strong></p>
  <p>Give every Codex/Claude agent one mission, one terminal, and a place in the grid.</p>
</div>

<p align="center">
  <img src="Horror.png" alt="A crowded terminal tab bar illustrates how parallel work gets hard to track" width="78%" />
</p>

That wall of tabs is the problem: every new request adds another place to lose context. Which agent is handling what? Which project belongs to this terminal? Gridline turns tab sprawl into a clear map of work. Give each human request a named workflow, its own Codex terminal, and the right project folder—then see every assignment side by side.

## A focused home for every workflow

- **Name the mission.** Create a work group for a request like “Fix sign-in” or “Prepare the release.”
- **Give it a dedicated terminal.** Start Codex in that group so the session has a clear home and purpose.
- **Set the project context.** Choose the folder where that assignment belongs.
- **Keep parallel work legible.** Arrange groups in one, two, or three columns, collapse what is not in focus, and jump to an assignment from the sidebar.
- **Return to an organized workspace.** Gridline saves group names, folders, labels, and layout on your Mac. Terminal sessions start fresh after the app closes.
- **Built for macOS.** A native SwiftUI and AppKit app, with local terminal sessions powered by SwiftTerm.

## Vibe-code your terminal workflow

Gridline is open source and made to grow with the way you work. Use the companion **Gridline Debug** inspector to click an interface element, copy its Accessibility details and likely source-code path, then tell your coding assistant what you want changed. Describe the workflow you want; Gridline gives your assistant useful context to start shaping it.

When extending Gridline's interface, reuse and extend its existing controls, spacing, colors, and button styles. Add a new component only when the interaction needs one, and keep its appearance consistent with the rest of the workspace.

## Build and run

Gridline is an open source macOS app. To build it from this repository, use macOS 13 or newer with Xcode Command Line Tools installed:

```sh
git clone https://github.com/reactnodejs322/gridline.git
cd gridline
./start.sh
```

The first build downloads the speech models into `skill_script/resources/models` and SwiftTerm through Swift Package Manager. Model versions are pinned and their hashes verified; the models are ignored by Git. `start.sh` builds and opens Gridline and its companion Gridline Debug inspector, then keeps a watcher running in the terminal. Install the Codex CLI separately to start Codex sessions.

Gridline Debug uses macOS Accessibility permission to inspect Gridline’s interface. The inspector does not read terminal text or keystrokes. You can also build just Gridline with `./gridline/build-app.sh` and open `gridline/Gridline.app`.

## Project status

Gridline is under active development. It focuses on organizing parallel terminal work: groups, folders, labels, navigation, and a persistent workspace layout. Closing or rebuilding the app ends active terminal sessions; the workspace organization is saved locally.

## License and attribution

Gridline's original code is © 2026 **reactnodejs322** and is licensed under **GNU GPL-3.0-or-later**. You may use, modify, and redistribute it under those terms. If you distribute a modified version, the GPL requires you to mark your changes and provide the corresponding source under the same license. Keep the license and copyright notices with copies of the project. See [LICENSE](LICENSE) for the terms.

The Gridline name and logo identify this project; the software license does not grant trademark rights or permission to present another project as an official Gridline release or imply endorsement. Forks should use distinct branding. Third-party components keep their own licenses; see [NOTICE](NOTICE.md).
