# Puckyto — User Guide

Puckyto is built to run several AI agents (Claude / ChatGPT / Gemini) across multiple terminals from a single screen. This guide walks through every section and workflow.

*Türkçe sürüm: [KULLANIM.md](KULLANIM.md)*

## Contents
1. [Layout](#1-layout)
2. [Workspaces and Terminals](#2-workspaces-and-terminals)
3. [AI Agents](#3-ai-agents)
4. [Task Queue and Quick Commands](#4-task-queue-and-quick-commands)
5. [Agent Coordination](#5-agent-coordination)
6. [Wiki and Files](#6-wiki-and-files)
7. [Git Safety](#7-git-safety)
8. [Neural Map](#8-neural-map)
9. [Logs](#9-logs)
10. [Notifications and Menu Bar](#10-notifications-and-menu-bar)
11. [Prompt Engineering Tools](#11-prompt-engineering-tools)
12. [Settings](#12-settings)
13. [Keyboard Shortcuts](#13-keyboard-shortcuts)

---

## 1. Layout
![Terminal grid](images/01-terminals.png)

- **Left rail:** section icons — Workspaces, Sessions, Wiki, Files, Agents, Logs, Neural Map, Settings. Clicking the active section again hides/shows the side panel.
- **Side panel:** the selected section's content. Drag its edge handle to resize between 220–520 px; the strip at its bottom pins it to the left/right edge or hides it (`⌘\`).
- **Top bar:** panel toggle, workspace name, the 🧪 prompt-tools menu, "Send Task" (broadcast) and "+ Terminal". **Double-click** its empty area to zoom the window.
- **Main area:** the terminal grid (1→single, 2–4→two columns, 5+→three columns), or the Neural Map / Logs reader.

## 2. Workspaces and Terminals

- A **workspace** is a group of terminals (typically one per project). `⇧⌘N` creates a workspace, `⌘T` adds a terminal to the selected one.
- **Default folder:** right-click a workspace → "📁 Choose Default Folder..." — every new terminal in that workspace opens there, so you never `cd` again. The chosen path appears under the workspace name; "Remove Default Folder" reverts to your home directory.
- **Renaming:** double-click the name in the terminal header, or right-click in the Sessions/Workspaces list → Rename. A terminal and its agent share one identity — one name, everywhere.
- **Terminal header chips:**
  - `Executing / Idle` — whether output appeared in the last 2 seconds
  - `🤖 Name` + `CLAUDE/GPT/GEMINI` — the agent and its provider (in the provider's brand color)
  - `🔔 awaiting approval` — the agent rang the bell and wants input
  - `⚠️ same folder` — another agent is working in the same directory (conflict risk!)
  - `Δ +120 −34` — git changes since the agent started
  - `⏭ 3` — tasks waiting in the queue
  - `✓ 12.3k tok` — real Claude token usage (`≈` means a PTY estimate)
- **Header buttons:** ⚡ quick commands · 🧠 start/restart the agent · ⤢ maximize · ✕ close.
- **Right-click menu:** view the system prompt, edit CLAUDE.md, act on the last reply, task queue, git worktree, session history, revert to checkpoint.
- **Drag and drop:** drop a file from the Files panel or Finder onto a terminal and its shell-escaped path is pasted. Wiki notes can be dropped too.

## 3. AI Agents
![Agents panel](images/02-agents.png)

Every terminal has one agent, configured in the **Agents** panel (click a terminal to focus it):

- **Name + icon:** clicking the icon opens an emoji picker. The name is shared with the terminal.
- **AI Provider:** Claude / ChatGPT / Gemini. A CLI that is not installed is flagged with ⚠️.
- **Model & Effort:** pick from the versioned list (e.g. Opus 4.8 + xhigh). The lists are editable in Settings → AI Models, so you can add a model the day it ships.
- **Permission Mode (Claude):**
  - *Ask* — asks before every critical action (default)
  - *Plan* — proposes a plan first and applies it after you approve
  - *Auto-accept edits* — does not ask for file edits
  - *⚡ Fully autonomous* — never asks (`--dangerously-skip-permissions`); best confined to an isolated worktree
- **Task Description:** what the agent should do; added to the system prompt.
- **Rules:** one rule per line — persistent behavioural limits ("never push to main", "don't call it done until tests pass").
- **Persistent Memory:** the contents of MEMORY.md. The agent reads it on start and updates it while working; the editor is file-backed and refreshes every 3s, so whatever the agent writes shows up here.
- **Start automatically:** launches the agent when the terminal opens.
- **🎯 Coordinator:** see [section 5](#5-agent-coordination).

**Starting:** the "Start Agent" button (or 🧠 in the header). The launch command is previewed underneath. If an agent is already open the button becomes **"Restart Agent"**: it closes the session with a double Ctrl+C and reopens it with the new settings — model and rule changes only take effect on a restart.

**Templates:** "Apply Template" applies a ready-made configuration (Builder, Reviewer, Test Engineer, Documentarian); "Save as Template" turns the current agent into one. Manage them in Settings → Agent Templates.

**What the agent knows:** on start its system prompt carries the task + rules, the path to MEMORY.md, the terminal's **wiki folder** (which it reads and writes), the workspace's **shared board**, and — for coordinators — the task queue. The prompt is written in the interface language.

**Session history:** right-click → "Claude Session History" lists the past sessions of that folder; "Resume" reopens one via `claude --resume`.

## 4. Task Queue and Quick Commands

- **Task queue** (right-click → Task Queue): an ordered list per agent. When the agent finishes a reply and goes idle, the next task is **sent automatically** — queue five jobs at night, find them done in the morning. Nothing is sent while the agent awaits approval (🔔). Tasks can be reordered by dragging; "Send Now" skips the wait. The pending count shows as `⏭ 3` in the header.
- **Quick commands** (⚡ in the header): saved prompts such as "Status report" or "Run & fix tests" go to that agent with one click. Edit them in Settings → Quick Commands.
- **Send Task / broadcast** (top bar): write one task, tick the target agents, and it goes to all of them at once ("everyone, give me a status report").
- **Variables:** any prompt may contain `{{folder}}`, `{{branch}}`, `{{agent}}` and `{{time}}`, expanded per terminal when sent.

## 5. Agent Coordination
![Shared board](images/03-board.png)

- **Shared board:** one `BOARD.md` per workspace. Every agent learns about it on start: it writes its status there and reads the others'. Each entry carries an `[HH:MM:SS]` timestamp so the ordering shows who did what and when. View it in the Logs section, or right-click a workspace → "📋 Show Shared Board".
- **Coordinator agent:** enable the 🎯 toggle in the Agents panel and start the agent. It is taught a queue folder; when it drops a JSON file shaped like `{"target": "Terminal 2", "message": "..."}`, the app delivers the message to that terminal's agent within seconds and logs the hand-off to the board. Typical use: tell the coordinator "split the project into modules and hand each one to the right agent" and let it drive.

## 6. Wiki and Files

- **Wiki:** each terminal has its own markdown notebook. The two pickers at the top select the *Workspace* (which grid is shown on the right — the drop target) and the *Wiki source* (whose notes are listed, across all workspaces). Type a title → ⏎ → the content editor focuses; 👁 switches to a full markdown preview (headings, lists, task boxes, quotes, code blocks). Drag a note onto a terminal to paste its path, or right-click → "Send Content to Terminal" for the raw text. Agents know their own wiki — you can tell one to "note the architecture decisions in your wiki".
- **Files:** a simple browser. Double-click to enter a folder or paste a file's path into the focused terminal. Right-click for paste-path, `cd`, or reveal in Finder. The terminal icon button jumps to the focused terminal's folder.

## 7. Git Safety

- **Checkpoint:** every time an agent starts, a snapshot of the repo is taken (`git stash create` — it does not touch the working tree or pollute history).
- **Change watcher:** the `Δ +a −r` chip refreshes every 6s; hover it to list the changed files (new files included).
- **Reverting:** right-click → "⏪ Revert to Checkpoint" types `git restore --source=<sha> -- .` into the terminal (restoring tracked files; files the agent created remain — sort them out from `git status`).
- **Conflict prevention:** when two agents are active in the same folder the `⚠️ same folder` chip lights up. The fix: right-click → "Open Git Worktree" creates a new branch and an isolated copy in a sibling folder and `cd`s the terminal into it.

## 8. Neural Map
![Neural map](images/04-neural-map.png)

Open **Neural Map** from the left rail: a central PUCKYTO core → workspace nodes → agent nodes (ringed in their provider's color). Particles along the edges speed up and brighten with activity.

- **Click:** a workspace node selects that workspace; an agent node focuses its terminal (a dashed ring marks the selection).
- **Drag:** move nodes into any layout you like ("Reset Layout" restores the default). The stats column on the right is resizable (220–460 px).
- Agent cards on the right show tokens, memory, an activity bar and status.

## 9. Logs

The **Logs** section pairs a workspace control panel with a full-width board reader:

- Left: pick a workspace, rename it, set or clear its default folder, reveal or reset its board.
- Right: the shared board rendered as markdown, refreshed from disk every 2 seconds. **"Follow tail"** keeps scrolling to the newest entry — turn it off while reading older history.

## 10. Notifications and Menu Bar

- **"✅ Agent is ready"** when an agent finishes a reply and goes idle. **"🔔 Agent needs approval"** when it rings the bell (e.g. claude asking permission). Rate-limited per session, so no flooding.
- **Click a notification** to bring the app forward and focus that terminal.
- **Menu bar icon:** a "🟢 2 agents running · 🔔 1 awaiting approval" summary plus every terminal grouped by workspace (🟢 running / 🟡 idle / 🔔 approval); click a row to focus it. Your control tower while you are in another app.
- Turn it all off with the Notifications toggle in Settings.

## 11. Prompt Engineering Tools

From the 🧪 menu in the top bar and the terminal's right-click menu:

- **System prompt preview:** the exact text injected into the agent plus the full launch command, both copyable — no more guessing what the agent actually received.
- **Last reply:** copy it, save it to the wiki as a timestamped note, or **forward it to another agent** — the simplest way to chain agents (a builder's output becomes a reviewer's input).
- **A/B run:** write one task, pick 2–3 Claude agents (configured with different models/efforts/prompts) and send it to all of them in parallel. Replies land side by side with the real tokens each variant spent; rate them 👍/👎, add a note, and "Save to Log" appends a dated entry to `experiments.md`.
- **Send history:** every prompt sent to an agent is recorded with its source (⚡ quick, 📣 broadcast, ⏭ queue, 📮 coordinator, 🧪 a/b). Searchable, with copy and re-send.
- **CLAUDE.md editor:** edit the CLAUDE.md in the terminal's folder without leaving the app.

## 12. Settings
![Settings](images/06-settings.png)

| Row | What opens |
|---|---|
| **Language** | English / Türkçe. Also switches the language of the system prompt sent to agents (restart an agent for it to apply). |
| **Theme** | The five built-in themes (One Dark Pro, Dracula, GitHub Dark, Tokyo Night, Monokai Pro) plus custom JSON themes, with preview cards. "New Theme (JSON)" writes a copy of the current theme into the `themes/` folder — edit the file, hit "Refresh". Below that, **Terminal Font**: the global family (Automatic = detect a Nerd Font) and size; "Write to This Theme" pins a font to a custom theme. JSON fields: the colors (`RRGGBB` hex), `ansi` (16 colors), `fontFamily`, `fontSize`. |
| **AI Models** | Per-provider model lists: display name + CLI identifier. Add a row when a new model ships and it appears in the Agents panel immediately. |
| **Agent Templates** | Add/delete/edit templates (name, icon, provider, model, effort, task, rules). |
| **Quick Commands** | The saved prompts behind the ⚡ menu. |

The panel also holds the **Notifications** toggle and the **Usage — Last 7 Days** chart (real Claude tokens; with "All Workspaces" selected it also breaks usage down per workspace — click a row to drill in).

Every settings window is movable, resizable above its minimum size, and floats above the main window.

## 13. Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘T` | New terminal |
| `⌘W` | Close the focused terminal (confirmed); quit the app once no terminals remain (also confirmed) |
| `⌘Q` | Quit — with an "are you sure?" confirmation |
| `⇧⌘N` | New workspace |
| `⌘\` | Hide/show the side panel |
| `⌘F` | Search in the focused terminal (⏎ next, ▲▼ back/forward, ✕ close) |
| `⌘↑` / `⌘↓` | Scroll a page up/down · `⇧⌘↓` jump to the bottom |
| Double-click the top bar | Zoom the window |
| Double-click a terminal name | Rename it |

## A Typical Multi-Agent Session

1. Open a workspace for your project and add three terminals; right-click each → **Open Git Worktree** to isolate them.
2. Assign templates: Builder (auto-accept edits), Reviewer (plan mode), Test Engineer.
3. Fill the Builder's **task queue**; send the Reviewer a ⚡ "Summarize changes".
4. Watch from the Neural Map or the menu bar; when a 🔔 arrives, click it and approve.
5. Follow who did what on the shared board in Logs, and check the day's token cost in Settings → Usage.
