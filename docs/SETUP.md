# Puckyto — Setup & Build Guide

Puckyto is a macOS app that manages multiple terminals and the AI agents (Claude / ChatGPT / Gemini) running inside them. This document covers installing from scratch, building, and troubleshooting.

*Türkçe sürüm: [KURULUM.md](KURULUM.md)*

## 1. Requirements

| Requirement | Version | Note |
|---|---|---|
| macOS | 14.0+ (Sonoma or newer) | Apple Silicon and Intel both supported |
| Swift | 5.9+ | Ships with Xcode 15+ or the Command Line Tools |
| Git | any | Needed to fetch the SwiftTerm dependency |
| Internet | first build only | SPM pulls SwiftTerm from GitHub |

Verify Swift is installed:

```bash
swift --version    # expect "Apple Swift version 5.9" or newer
```

If it is missing: `xcode-select --install` (the Command Line Tools are enough, full Xcode is not required).

### CLIs for the AI agents (optional but recommended)

The app works as a terminal manager without any CLI; to start an agent, the matching CLI must be installed:

```bash
# Claude Code (recommended)
npm install -g @anthropic-ai/claude-code    # or: brew install claude
claude --version

# OpenAI Codex CLI (for ChatGPT agents)
npm install -g @openai/codex

# Gemini CLI
npm install -g @google/gemini-cli
```

Missing CLIs are marked with ⚠️ in the app; install one later and press "Rescan" in the Agents panel.

### Nerd Font (recommended)

If your shell prompt uses powerlevel10k / starship icons, install a Nerd Font (the app detects it automatically):

```bash
brew install --cask font-meslo-lg-nerd-font
```

## 2. Getting the Source

```bash
git clone <repo-url> puckyto
cd puckyto
```

(Skip this if you already have the folder.)

## 3. Building

### Option A — one command (recommended): the .app bundle

```bash
./scripts/build-app.sh
open "build/Puckyto.app"
```

The script runs `swift build -c release`, wraps the output into `build/Puckyto.app` (with Info.plist), and ad-hoc signs it. **Launch the app from this bundle so notifications work.**

For a debug build: `./scripts/build-app.sh debug`

### Option B — plain SPM

```bash
swift build -c release
.build/release/Puckyto        # runs directly (notification permissions are limited)
```

### Installing it permanently

```bash
cp -R "build/Puckyto.app" /Applications/
```

## 4. First Launch

1. The app opens with a sample workspace and two terminals.
2. macOS asks for **notification permission** — allow it to be told when an agent finishes or needs approval.
3. Click a terminal, configure its agent in the Agents panel, and start it with 🧠.

The interface is in **English by default**; switch to Turkish from Settings → Language.

## 5. Where Data Lives

| What | Where |
|---|---|
| Settings, workspaces, agents | `~/Library/Application Support/dev.puckyto.app/state.json` |
| Wiki notes | `.../dev.puckyto.app/wiki/<terminalID>/*.md` |
| Agent memories | `.../dev.puckyto.app/agents/<agentID>/MEMORY.md` |
| Shared boards | `.../dev.puckyto.app/boards/<workspaceID>.md` |
| Custom themes | `.../dev.puckyto.app/themes/*.json` |
| Coordinator queue | `.../dev.puckyto.app/queue/<workspaceID>/` |

Copy that folder to back everything up. To reset the app, delete `state.json` while the terminals are closed.

Nothing is sent anywhere: all state stays on your machine, and the app makes no network calls of its own — only the AI CLIs you start talk to their providers.

## 6. The App Icon

The icon lives as a single SVG at [`Resources/icon.svg`](../Resources/icon.svg) — a black cat with
terminal-green eyes. After editing it, regenerate the bundled `.icns`:

```bash
./scripts/make-icon.sh
./scripts/build-app.sh
```

The script renders the SVG, builds every required size and writes `Resources/AppIcon.icns`.

## 7. Updating

```bash
git pull
./scripts/build-app.sh
```

Your data lives under Application Support, so building or updating never touches it.

## 8. Troubleshooting

**`swift package resolve` fails with "cannot use bare repository"**
If your git config sets `safe.bareRepository=explicit`, SPM stalls. `build-app.sh` works around it; when building by hand:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift build -c release
```

**"command not found: claude" when starting an agent**
The CLI is not installed or not on PATH. Install it, then press "Rescan" in the Agents panel.

**Question-mark boxes (▯?) in the prompt**
A Nerd Font is missing. Install one with `brew install --cask font-meslo-lg-nerd-font`; the app detects it automatically. You can also pick a font explicitly in Settings → Theme → Terminal Font.

**No notifications**
Make sure you launched the `.app` bundle, and allow Puckyto under System Settings → Notifications. The "Notifications" toggle in the Settings panel must also be on.

**The token chip shows `≈` and never becomes a real count**
Real counting only works for Claude agents and reads the session files under `~/.claude/projects/`. Start the agent from inside the app (🧠); the chip flips to `✓` after the first message.
