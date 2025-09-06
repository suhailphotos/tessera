#!/usr/bin/env bash
set -euo pipefail

# --- config --------------------------------------------------------------
# Where this script lives -> repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STOW_DIR="$REPO_ROOT/apps/houdini/stow"
SEED_DIR="$REPO_ROOT/apps/houdini/seed"

# Pick which stow packages to apply in order
PACKAGES_COMMON="common"

# Detect OS (mac/linux/windows via Git Bash/MSYS)
unameOut="$(uname -s || true)"
case "${unameOut}" in
  Darwin) OS="mac" ;;
  Linux)  OS="linux" ;;
  CYGWIN*|MINGW*|MSYS*) OS="win" ;;
  *) echo "Unsupported OS: ${unameOut}"; exit 1 ;;
esac

# --- helpers -------------------------------------------------------------
die() { echo "Error: $*" >&2; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing '$1'. Install it and retry."
}

# Determine default user pref base & pattern by OS
pref_base_and_glob() {
  case "$OS" in
    mac)  echo "$HOME/Library/Preferences/houdini::[0-9][0-9]*.[0-9]*" ;;
    linux) echo "$HOME::houdini[0-9][0-9]*.[0-9]*" ;;
    win)  echo "$HOME/Documents::houdini[0-9][0-9]*.[0-9]*" ;;
  esac
}

# Find the latest existing Houdini X.Y dir, or create target if not present
resolve_target_dir() {
  local ver="${1:-}"
  IFS="::" read -r base glob <<<"$(pref_base_and_glob)"
  mkdir -p "$base"

  if [[ -n "${ver}" ]]; then
    case "$OS" in
      mac)  echo "$base/$ver" ;;
      linux) echo "$base/houdini${ver}" ;;
      win)  echo "$base/houdini${ver}" ;;
    esac
    return
  fi

  # autodetect newest existing by lexicographic order (works fine for X.Y)
  local candidates
  mapfile -t candidates < <(ls -1d "${base}/${glob}" 2>/dev/null | sort -V || true)
  if (( ${#candidates[@]} > 0 )); then
    echo "${candidates[-1]}"
  else
    # No existing version; fall back to creating a placeholder 21.0
    case "$OS" in
      mac)  echo "$base/21.0" ;;
      linux) echo "$base/houdini21.0" ;;
      win)  echo "$base/houdini21.0" ;;
    esac
  fi
}

# Copy seed files once (never overwrite user modifications)
seed_once() {
  local target="$1"
  [[ -d "$SEED_DIR" ]] || return 0
  if [[ -f "$SEED_DIR/assetGallery.db" && ! -e "$target/assetGallery.db" ]]; then
    cp "$SEED_DIR/assetGallery.db" "$target/assetGallery.db"
    echo "Seeded assetGallery.db → $target"
  fi
}

# --- main ---------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") [HOU_VER]

Examples:
  $(basename "$0")           # autodetect latest (or create 21.0)
  $(basename "$0") 21.0      # force specific X.Y
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

need stow

TARGET_DIR="$(resolve_target_dir "${1:-}")"
mkdir -p "$TARGET_DIR"

echo "OS: $OS"
echo "Target Houdini user pref dir: $TARGET_DIR"

# Seed writable binaries once (don’t symlink these)
seed_once "$TARGET_DIR"

# Stow common package first, then OS overlay
stow -d "$STOW_DIR" -t "$TARGET_DIR" $PACKAGES_COMMON
if [[ -d "$STOW_DIR/$OS" ]]; then
  stow -d "$STOW_DIR" -t "$TARGET_DIR" "$OS"
fi

echo "Done. Linked tessera prefs into: $TARGET_DIR"
