#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "==> Initializing submodules..."
git submodule update --init --recursive

echo "==> Checking for zig..."
if ! command -v zig &> /dev/null; then
    echo "Error: zig is not installed."
    echo "Install via: brew install zig"
    exit 1
fi

# Ghostty pins a minimum zig version; an older zig fails with confusing errors.
REQUIRED_ZIG="$(sed -n 's/.*minimum_zig_version = "\(.*\)".*/\1/p' ghostty/build.zig.zon)"
CURRENT_ZIG="$(zig version)"
if [ -n "$REQUIRED_ZIG" ] && [ "$(printf '%s\n%s\n' "$REQUIRED_ZIG" "$CURRENT_ZIG" | sort -V | head -1)" != "$REQUIRED_ZIG" ]; then
    echo "Error: zig $REQUIRED_ZIG or newer is required (found $CURRENT_ZIG)."
    echo "Download it from https://ziglang.org/download/ and put it first in PATH."
    exit 1
fi

echo "==> Building GhosttyKit.xcframework (this may take a few minutes)..."
cd ghostty
zig build -Demit-xcframework=true -Demit-macos-app=false -Doptimize=ReleaseFast
cd "$PROJECT_DIR"

echo "==> Creating symlink for GhosttyKit.xcframework..."
ln -sf ghostty/macos/GhosttyKit.xcframework GhosttyKit.xcframework

echo "==> Setup complete!"
echo ""
echo "You can now build and run the app:"
echo "  ./scripts/reload.sh"
