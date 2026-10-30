#!/usr/bin/env bash
set -euo pipefail

APP_NAME="cter DEV"
BUNDLE_ID="com.cuonghx.cter.debug"
BASE_APP_NAME="cter DEV"
DERIVED_DATA=""
NAME_SET=0
BUNDLE_SET=0
DERIVED_SET=0
TAG=""

usage() {
  cat <<'EOF'
Usage: ./scripts/reload.sh [options]

Options:
  --tag <name>           Short tag for parallel builds (e.g., feature-xyz-lol).
                         Sets app name, bundle id, and derived data path unless overridden.
  --name <app name>      Override app display/bundle name.
  --bundle-id <id>       Override bundle identifier.
  --derived-data <path>  Override derived data path.
  -h, --help             Show this help.
EOF
}

sanitize_bundle() {
  local raw="$1"
  local cleaned
  cleaned="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/./g; s/^\\.+//; s/\\.+$//; s/\\.+/./g')"
  if [[ -z "$cleaned" ]]; then
    cleaned="agent"
  fi
  echo "$cleaned"
}

sanitize_path() {
  local raw="$1"
  local cleaned
  cleaned="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [[ -z "$cleaned" ]]; then
    cleaned="agent"
  fi
  echo "$cleaned"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      if [[ -z "$TAG" ]]; then
        echo "error: --tag requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --name)
      APP_NAME="${2:-}"
      if [[ -z "$APP_NAME" ]]; then
        echo "error: --name requires a value" >&2
        exit 1
      fi
      NAME_SET=1
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="${2:-}"
      if [[ -z "$BUNDLE_ID" ]]; then
        echo "error: --bundle-id requires a value" >&2
        exit 1
      fi
      BUNDLE_SET=1
      shift 2
      ;;
    --derived-data)
      DERIVED_DATA="${2:-}"
      if [[ -z "$DERIVED_DATA" ]]; then
        echo "error: --derived-data requires a value" >&2
        exit 1
      fi
      DERIVED_SET=1
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$TAG" ]]; then
  TAG_ID="$(sanitize_bundle "$TAG")"
  TAG_SLUG="$(sanitize_path "$TAG")"
  if [[ "$NAME_SET" -eq 0 ]]; then
    APP_NAME="cter DEV ${TAG}"
  fi
  if [[ "$BUNDLE_SET" -eq 0 ]]; then
    BUNDLE_ID="com.cuonghx.cter.debug.${TAG_ID}"
  fi
  if [[ "$DERIVED_SET" -eq 0 ]]; then
    DERIVED_DATA="/tmp/cter-${TAG_SLUG}"
  fi
fi

XCODEBUILD_ARGS=(
  -project GhosttyTabs.xcodeproj
  -scheme cter
  -configuration Debug
  -destination 'platform=macOS'
)
if [[ -n "$DERIVED_DATA" ]]; then
  XCODEBUILD_ARGS+=(-derivedDataPath "$DERIVED_DATA")
fi
if [[ -z "$TAG" ]]; then
  XCODEBUILD_ARGS+=(
    INFOPLIST_KEY_CFBundleName="$APP_NAME"
    INFOPLIST_KEY_CFBundleDisplayName="$APP_NAME"
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
  )
fi
XCODEBUILD_ARGS+=(build)

xcodebuild "${XCODEBUILD_ARGS[@]}"
sleep 0.2

FALLBACK_APP_NAME="$BASE_APP_NAME"
SEARCH_APP_NAME="$APP_NAME"
if [[ -n "$TAG" ]]; then
  SEARCH_APP_NAME="$BASE_APP_NAME"
fi
if [[ -n "$DERIVED_DATA" ]]; then
  APP_PATH="${DERIVED_DATA}/Build/Products/Debug/${SEARCH_APP_NAME}.app"
  if [[ ! -d "${APP_PATH}" && "$SEARCH_APP_NAME" != "$FALLBACK_APP_NAME" ]]; then
    APP_PATH="${DERIVED_DATA}/Build/Products/Debug/${FALLBACK_APP_NAME}.app"
  fi
else
  APP_BINARY="$(
    find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Debug/${SEARCH_APP_NAME}.app/Contents/MacOS/${SEARCH_APP_NAME}" -print0 \
    | xargs -0 /usr/bin/stat -f "%m %N" 2>/dev/null \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
  )"
  if [[ -n "${APP_BINARY}" ]]; then
    APP_PATH="$(dirname "$(dirname "$(dirname "$APP_BINARY")")")"
  fi
  if [[ -z "${APP_PATH}" && "$SEARCH_APP_NAME" != "$FALLBACK_APP_NAME" ]]; then
    APP_BINARY="$(
      find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Debug/${FALLBACK_APP_NAME}.app/Contents/MacOS/${FALLBACK_APP_NAME}" -print0 \
      | xargs -0 /usr/bin/stat -f "%m %N" 2>/dev/null \
      | sort -nr \
      | head -n 1 \
      | cut -d' ' -f2-
    )"
    if [[ -n "${APP_BINARY}" ]]; then
      APP_PATH="$(dirname "$(dirname "$(dirname "$APP_BINARY")")")"
    fi
  fi
fi
if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
  echo "${APP_NAME}.app not found in DerivedData" >&2
  exit 1
fi

if [[ -n "$TAG" && "$APP_NAME" != "$SEARCH_APP_NAME" ]]; then
  TAG_APP_PATH="$(dirname "$APP_PATH")/${APP_NAME}.app"
  rm -rf "$TAG_APP_PATH"
  cp -R "$APP_PATH" "$TAG_APP_PATH"
  INFO_PLIST="$TAG_APP_PATH/Contents/Info.plist"
  if [[ -f "$INFO_PLIST" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$INFO_PLIST" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_NAME" "$INFO_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$INFO_PLIST" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_NAME" "$INFO_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$INFO_PLIST" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$INFO_PLIST"
    if [[ -n "${TAG_SLUG:-}" ]]; then
      CTER_SOCKET="/tmp/cter-debug-${TAG_SLUG}.sock"
      echo "$CTER_SOCKET" > /tmp/cter-last-socket-path || true
      /usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$INFO_PLIST" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Set :LSEnvironment:CTER_SOCKET_PATH \"${CTER_SOCKET}\"" "$INFO_PLIST" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :LSEnvironment:CTER_SOCKET_PATH string \"${CTER_SOCKET}\"" "$INFO_PLIST"
      if [[ -S "$CTER_SOCKET" ]]; then
        rm -f "$CTER_SOCKET"
      fi
    fi
    /usr/bin/codesign --force --sign - --timestamp=none --generate-entitlement-der "$TAG_APP_PATH" >/dev/null 2>&1 || true
  fi
  APP_PATH="$TAG_APP_PATH"
fi

# Ensure any running instance is fully terminated, regardless of DerivedData path.
/usr/bin/osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
sleep 0.3
if [[ -z "$TAG" ]]; then
  # Non-tag mode: kill any running instance (across any DerivedData path) to avoid socket conflicts.
  pkill -f "/${BASE_APP_NAME}.app/Contents/MacOS/${BASE_APP_NAME}" || true
else
  # Tag mode: only kill the tagged instance; allow side-by-side with the main app.
  pkill -f "${APP_NAME}.app/Contents/MacOS/${BASE_APP_NAME}" || true
fi
sleep 0.3
# Avoid inheriting cter/ghostty environment variables from the terminal that
# runs this script (often inside another cter instance), which can cause
# socket and resource-path conflicts.
OPEN_CLEAN_ENV=(
  env
  -u CTER_SOCKET_PATH
  -u CTER_TAB_ID
  -u CTER_PANEL_ID
  -u CTER_TAG
  -u CTER_BUNDLE_ID
  -u CTER_SHELL_INTEGRATION
  -u GHOSTTY_BIN_DIR
  -u GHOSTTY_RESOURCES_DIR
  -u GHOSTTY_SHELL_FEATURES
  # Dev shells (including CI/Codex) often force-disable paging by exporting these.
  # Don't leak that into cter, otherwise `git diff` won't page even with PAGER=less.
  -u GIT_PAGER
  -u GH_PAGER
  -u TERMINFO
  -u XDG_DATA_DIRS
)

if [[ -n "${TAG_SLUG:-}" && -n "${CTER_SOCKET:-}" ]]; then
  # Ensure tag-specific socket paths win even if the caller has CTER_* overrides.
  "${OPEN_CLEAN_ENV[@]}" CTER_SOCKET_PATH="$CTER_SOCKET" open "$APP_PATH"
else
  "${OPEN_CLEAN_ENV[@]}" open "$APP_PATH"
fi
osascript -e "tell application id \"${BUNDLE_ID}\" to activate" || true

# Safety: ensure only one instance is running.
sleep 0.2
PIDS=($(pgrep -f "${APP_PATH}/Contents/MacOS/" || true))
if [[ "${#PIDS[@]}" -gt 1 ]]; then
  NEWEST_PID=""
  NEWEST_AGE=999999
  for PID in "${PIDS[@]}"; do
    AGE="$(ps -o etimes= -p "$PID" | tr -d ' ')"
    if [[ -n "$AGE" && "$AGE" -lt "$NEWEST_AGE" ]]; then
      NEWEST_AGE="$AGE"
      NEWEST_PID="$PID"
    fi
  done
  for PID in "${PIDS[@]}"; do
    if [[ "$PID" != "$NEWEST_PID" ]]; then
      kill "$PID" 2>/dev/null || true
    fi
  done
fi
