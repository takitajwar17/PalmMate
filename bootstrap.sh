#!/usr/bin/env bash
# One-shot setup for the PalmMate iOS app.
#
#   ./bootstrap.sh           — install deps, copy Config.xcconfig template,
#                              generate the Xcode project
#   ./bootstrap.sh --open    — same, then open in Xcode
#
# After running, edit PalmMate/PalmMate/Config.xcconfig and paste your
# OpenAI API key, then build & run on a physical iPhone (Apple Sign-In
# does not work in the simulator).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$REPO_ROOT/PalmMate"
CONFIG_TEMPLATE="$APP_DIR/PalmMate/Config.xcconfig.example"
CONFIG_FILE="$APP_DIR/PalmMate/Config.xcconfig"

bold()   { printf "\033[1m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*" >&2; }

bold "→ PalmMate bootstrap"

# 1. Verify Xcode CLI tools.
if ! xcode-select -p >/dev/null 2>&1; then
  red "Xcode command-line tools are not installed."
  red "Run: xcode-select --install"
  exit 1
fi

# 2. Install xcodegen if missing.
if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    red "Homebrew is required to install xcodegen automatically."
    red "Install Homebrew (https://brew.sh) or install xcodegen manually,"
    red "then re-run this script."
    exit 1
  fi
  yellow "Installing xcodegen via Homebrew…"
  brew install xcodegen
else
  green "✓ xcodegen already installed ($(xcodegen --version 2>&1 | head -1))"
fi

# 3. Copy Config.xcconfig template if missing.
if [[ ! -f "$CONFIG_FILE" ]]; then
  cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
  yellow "✓ Created $CONFIG_FILE from template."
  yellow "  → Edit it and paste your OPENAI_API_KEY before building."
else
  green "✓ $CONFIG_FILE already exists (leaving it alone)."
fi

# 4. Generate the Xcode project.
bold "→ Generating Xcode project…"
( cd "$APP_DIR" && xcodegen generate )

green "✓ Done. Project is at: $APP_DIR/PalmMate.xcodeproj"

# 5. Open in Xcode if requested.
if [[ "${1:-}" == "--open" ]]; then
  open "$APP_DIR/PalmMate.xcodeproj"
fi

cat <<EOF

Next steps:
  1. Edit  PalmMate/PalmMate/Config.xcconfig  → paste your OpenAI API key.
  2. Open  PalmMate/PalmMate.xcodeproj        → set your Signing Team.
  3. Run on a physical iPhone (Apple Sign-In requires a real device).

For the optional Cloudflare Worker backend, see backend/README.md.
EOF
