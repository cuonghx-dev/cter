# Agent notes

Minimal Ghostty-based macOS terminal (fork of cmux without auto-update, website, or release tooling).

## Setup

```bash
./scripts/setup.sh   # init ghostty submodule + build GhosttyKit.xcframework
```

## Build & run

```bash
xcodebuild -project GhosttyTabs.xcodeproj -scheme cmux -configuration Debug -destination 'platform=macOS' build
./scripts/reload.sh               # kill + launch Debug app
./scripts/reload.sh --tag <name>  # isolated side-by-side app (own bundle ID, socket, derived data)
```

When rebuilding GhosttyKit.xcframework, always use Release optimizations:

```bash
cd ghostty && zig build -Demit-xcframework=true -Doptimize=ReleaseFast
```

## Tests

Python socket tests in `tests/` drive a running app over `/tmp/cmux.sock`:

```bash
python3 tests/test_ctrl_socket.py
```

## Pitfalls

- Do not add an app-level display link or manual `ghostty_surface_draw` loop; rely on Ghostty wakeups/renderer to avoid typing lag.
