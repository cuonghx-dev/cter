<h1 align="center">cter</h1>
<p align="center">A Ghostty-based macOS terminal with vertical tabs and notifications for AI coding agents</p>

## Features

- **Native macOS app** — Built with Swift and AppKit, not Electron. Fast startup, low memory.
- **Vertical tabs** — See all your terminals at a glance in a sidebar
- **Notification panel** — See which agents are waiting for input at a glance
- **Notification rings** — Tabs flash when AI agents (Claude Code, Codex) need your attention
- **Lightweight** — Small binary, minimal resource footprint. No bundled browser engine.
- **GPU-accelerated** — Powered by libghostty for smooth rendering

## Build from source

This is a minimal fork without auto-update, crash reporting, or the website.
Build it yourself (requires Xcode and zig 0.15.2):

```bash
./scripts/setup.sh
./scripts/reload.sh --tag dev
```

## Why cter?

Running multiple AI coding agents? cter helps you manage them. Instead of losing track of which terminal needs input, the notification panel shows you exactly where to look.

A native macOS app means it launches instantly, uses minimal RAM, and feels right at home on your Mac.

## Keyboard Shortcuts

### Workspaces

| Shortcut | Action |
|----------|--------|
| ⌘ N | New workspace |
| ⌘ 1–8 | Jump to workspace 1–8 |
| ⌘ 9 | Jump to last workspace |
| ⌘ ⇧ W | Close workspace |

### Surfaces

| Shortcut | Action |
|----------|--------|
| ⌘ T | New surface |
| ⌘ ⇧ [ | Previous surface |
| ⌃ ⇧ Tab | Previous surface |
| ⌃ 1–8 | Jump to surface 1–8 |
| ⌃ 9 | Jump to last surface |
| ⌘ W | Close surface |

### Split Panes

| Shortcut | Action |
|----------|--------|
| ⌘ D | Split right |
| ⌘ ⇧ D | Split down |
| ⌥ ⌘ ← → ↑ ↓ | Focus pane directionally |

### Notifications

| Shortcut | Action |
|----------|--------|
| ⌘ ⇧ I | Show notifications panel |
| ⌘ ⇧ U | Jump to latest unread |

### Find

| Shortcut | Action |
|----------|--------|
| ⌘ F | Find |
| ⌘ G / ⌘ ⇧ G | Find next / previous |
| ⌘ ⇧ F | Hide find bar |
| ⌘ E | Use selection for find |

### Terminal

| Shortcut | Action |
|----------|--------|
| ⌘ K | Clear scrollback |
| ⌘ C | Copy (with selection) |
| ⌘ V | Paste |
| ⌘ + / ⌘ - | Increase / decrease font size |
| ⌘ 0 | Reset font size |

### Window

| Shortcut | Action |
|----------|--------|
| ⌘ ⇧ N | New window |
| ⌘ , | Settings |
| ⌘ ⇧ R | Reload configuration |
| ⌘ Q | Quit |
