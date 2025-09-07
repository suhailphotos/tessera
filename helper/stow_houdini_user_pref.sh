#!/usr/bin/env bash
# stow_houdini_user_pref.sh  (Bash 3.2–compatible)
# - Detect Houdini installs
# - Ensure tessera repo exists (ask where to clone if missing)
# - Ensure stow is installed (auto-install on mac via Homebrew)
# - Write .stow-local-ignore (skip noisy host files)
# - Backup conflicts then stow common + OS overlay into each X.Y
#
# Usage (shareable):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/tessera/refs/heads/main/helper/stow_houdini_user_pref.sh)"
#
# Optional flags:
#   --tessera <dir>
#   --versions "21.0 20.5"
#   -y | --yes
#   -n | --dry-run
#   --ref <git-ref> | --dev <branch>
set -euo pipefail
IFS=$'\n\t'

# ---------- flags ----------
TES_DIR=""; VERSIONS=""; ASSUME_YES=0; DRYRUN=0; REF=""; DEV=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tessera) TES_DIR="${2:-}"; shift ;;
    --versions) VERSIONS="${2:-}"; shift ;;
    -y|--yes) ASSUME_YES=1 ;;
    -n|--dry-run) DRYRUN=1 ;;
    --ref) REF="${2:-}"; shift ;;
    --dev) DEV="${2:-}"; shift ;;
    -h|--help) sed -n '1,120p' "$0"; exit 0 ;;
    --) shift; break ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac; shift
done

log()  { printf '==> %s\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*" >&2; }
die()  { printf '❌ %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
timestamp() { date +"%Y%m%d-%H%M%S"; }
is_tty() { [[ -t 0 && -t 1 ]]; }
ask() {
  local prompt="$1" def="${2:-}" ans
  if (( ASSUME_YES )); then echo "$def"; return 0; fi
  if is_tty; then read -r -p "$prompt ${def:+[$def]}: " ans || true; echo "${ans:-$def}"
  else echo "$def"; fi
}

# ---------- OS detect ----------
unameOut="$(uname -s || true)"
case "$unameOut" in
  Darwin) OS="mac" ;;
  Linux)  OS="linux" ;;
  CYGWIN*|MINGW*|MSYS*) OS="win" ;;
  *) die "Unsupported OS: ${unameOut}" ;;
esac
log "OS detected: $OS"

# ---------- stow ensure ----------
ensure_stow() {
  if have stow; then return 0; fi
  case "$OS" in
    mac)
      if have brew; then
        log "Installing stow via Homebrew…"
        brew install stow >/dev/null || die "brew install stow failed"
      else
        die "GNU Stow not found and Homebrew missing. Install Homebrew first: https://brew.sh , then re-run."
      fi ;;
    linux)
      if have apt-get; then
        ((ASSUME_YES)) && sudo apt-get update -y && sudo apt-get install -y stow \
          || { warn "Install stow: sudo apt-get update && sudo apt-get install stow"; die "Re-run after installing stow."; }
      elif have dnf; then
        ((ASSUME_YES)) && sudo dnf install -y stow \
          || { warn "Install stow: sudo dnf install stow"; die "Re-run after installing stow."; }
      elif have pacman; then
        ((ASSUME_YES)) && sudo pacman -Sy --noconfirm stow \
          || { warn "Install stow: sudo pacman -S stow"; die "Re-run after installing stow."; }
      elif have zypper; then
        ((ASSUME_YES)) && sudo zypper install -y stow \
          || { warn "Install stow: sudo zypper install stow"; die "Re-run after installing stow."; }
      else
        die "Please install GNU Stow with your package manager, then re-run."
      fi ;;
    win)
      if have pacman; then
        ((ASSUME_YES)) && pacman -S --noconfirm stow \
          || { warn "Install stow: pacman -S stow"; die "Re-run after installing stow."; }
      else
        die "Windows: run under MSYS2/Cygwin and install stow (pacman -S stow), then re-run."
      fi ;;
  esac
}
ensure_stow

# ---------- find/confirm tessera ----------
DEFAULT_MATRIX="${MATRIX:-}"
if [[ -z "$DEFAULT_MATRIX" ]]; then
  case "$OS" in
    mac) DEFAULT_MATRIX="$HOME/Library/CloudStorage/Dropbox/matrix" ;;
    *)   DEFAULT_MATRIX="$HOME/Dropbox/matrix" ;;
  esac
fi
DEFAULT_TES="${DEFAULT_MATRIX}/tessera"
TES_DIR="${TES_DIR:-$DEFAULT_TES}"

if [[ ! -d "$TES_DIR/.git" ]]; then
  log "Tessera repo not found at: $TES_DIR"
  local_parent="$(dirname "$TES_DIR")"
  ((ASSUME_YES)) || local_parent="$(ask "Where should I clone 'tessera'?" "$local_parent")"
  mkdir -p "$local_parent"; have git || die "git is required to clone tessera."
  log "Cloning tessera → $local_parent/tessera"
  git clone --depth 1 https://github.com/suhailphotos/tessera.git "$local_parent/tessera"
  TES_DIR="$local_parent/tessera"
else
  log "Found tessera at: $TES_DIR"
fi

# Optional checkout ref/branch
if [[ -n "${DEV:-}" || -n "${REF:-}" ]]; then
  REF="${DEV:-$REF}"
  log "Checking out tessera @ $REF"
  git -C "$TES_DIR" fetch --depth 1 origin "$REF" || true
  git -C "$TES_DIR" checkout -q "$REF" || git -C "$TES_DIR" checkout -q FETCH_HEAD || true
fi

STOW_DIR="$TES_DIR/apps/houdini/stow"
[[ -d "$STOW_DIR/common" ]] || die "Missing tessera package dir: $STOW_DIR/common"

# ---------- write ignore rules ----------
ensure_ignore() {
  # Bash 3.2-safe: set vars on separate lines (set -u friendly)
  local pkg_dir
  pkg_dir="$1"
  local f
  f="$pkg_dir/.stow-local-ignore"

  mkdir -p "$pkg_dir"
  touch "$f"

  # append-if-missing helper
  add_pat() {
    grep -qxF "$1" "$f" 2>/dev/null || echo "$1" >> "$f"
  }

  add_pat '(^|/)\.DS_Store$'
  add_pat '(^|/)\.git($|/)'
  add_pat '(^|/)\.gitignore$'
  add_pat '(^|/)README(\.md)?$'
  add_pat '(^|/)seed($|/)'
  add_pat '^houdini\.env$'
  # stow match is from the package root; these patterns work across platforms
  add_pat '(^|/)toolbar/default\.shelf$'
  add_pat '(^|/)toolbar/shelf_tool_assets\.json$'
}
ensure_ignore "$STOW_DIR/common"

# ---------- detect installed Houdini versions (no mapfile, no sort -V) ----------
versions=()
if [[ -n "$VERSIONS" ]]; then
  for v in $VERSIONS; do versions+=("$v"); done
else
  case "$OS" in
    mac)
      # Extract X.Y from /Applications/Houdini/HoudiniXX.Y.ZZZ
      list="$(ls -1d /Applications/Houdini/Houdini* 2>/dev/null \
              | sed -E 's#.*/Houdini([0-9]+\.[0-9]+)\..*#\1#' \
              | sort -u)"
      ;;
    linux)
      list="$(ls -1d /opt/hfs* 2>/dev/null \
              | sed -E 's#.*/hfs([0-9]+\.[0-9]+)\..*#\1#' \
              | sort -u)"
      ;;
    win)
      pf="/c/Program Files/Side Effects Software"
      pf86="/c/Program Files (x86)/Side Effects Software"
      list="$(ls -1d "$pf"/Houdini* "$pf86"/Houdini* 2>/dev/null \
              | sed -E 's#.*/Houdini[ _-]?([0-9]+\.[0-9]+)\..*#\1#' \
              | sort -u)"
      ;;
  esac
  # Fill array
  for v in $list; do [[ -n "$v" ]] && versions+=("$v"); done
fi
(( ${#versions[@]} )) || die "No Houdini installations detected. Install Houdini first, then re-run."
log "Houdini versions detected: ${versions[*]}"

# ---------- target dir helper ----------
pref_dir_for() {
  case "$OS" in
    mac)  echo "$HOME/Library/Preferences/houdini/$1" ;;
    linux) echo "$HOME/houdini$1" ;;
    win)  echo "$HOME/Documents/houdini$1" ;;
  esac
}

# ---------- seed once ----------
seed_once() {
  local target="$1" seed="$TES_DIR/apps/houdini/seed/assetGallery.db"
  [[ -f "$seed" && ! -e "$target/assetGallery.db" ]] && {
    cp "$seed" "$target/assetGallery.db"
    log "Seeded assetGallery.db → $target"
  }
}

# ---------- backup conflicts ----------
backup_conflicts() {
  local pkg="$1" target="$2" ts; ts="$(timestamp)"
  local out; out="$(stow -n -v -d "$STOW_DIR" -t "$target" "$pkg" 2>&1 || true)"
  echo "$out" | sed -n 's#.*existing target \(.*\) since neither a link.*#\1#p' | while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    local abs="$target/$rel"
    if [[ -e "$abs" && ! -L "$abs" ]]; then
      local bak="${abs}.pre-stow.${ts}.bak"
      mkdir -p "$(dirname "$bak")"
      mv "$abs" "$bak"
      warn "Backed up existing file: $abs → $bak"
    fi
  done
}

# --- helper to call stow with optional -n -v in dry-run
run_stow() {
  local target="$1"
  local -a flags=()      # always initialize the array
  if [[ ${DRYRUN:-0} -eq 1 ]]; then
    flags=(-n -v)
  fi

  stow "${flags[@]}" -d "$STOW_DIR" -t "$target" common
  if [[ -d "$STOW_DIR/$OS" ]]; then
    stow "${flags[@]}" -d "$STOW_DIR" -t "$target" "$OS"
  fi
}

# ---------- stow per version ----------
for ver in "${versions[@]}"; do
  target="$(pref_dir_for "$ver")"
  mkdir -p "$target"
  seed_once "$target"

  log "Stowing into: $target"
  DRY=(); (( DRYRUN )) && DRY=(-n -v)

  echo "==> Stowing into: $target"
  run_stow "$target"

  log "✔ Stowed for Houdini $ver → $target"
done

log "All done."
(( DRYRUN )) && warn "You ran with --dry-run. Re-run without -n to apply."
