#!/usr/bin/env bash
# stow_houdini_user_pref.sh
# Bullet-proof Houdini user-pref stow for Tessera
# - Detects Houdini installs per OS
# - Ensures tessera repo present (asks where to clone if missing)
# - Ensures stow is installed (auto-installs via brew on macOS)
# - Creates per-package ignore for noisy/host-local files
# - Backs up conflicts in target before stowing (timestamped .bak)
# - Stows common + OS overlay into each installed X.Y
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/suhailphotos/tessera/refs/heads/main/helper/stow_houdini_user_pref.sh | bash
#
# Optional flags when running locally:
#   --tessera <dir>     # path to existing tessera repo (default: $MATRIX/tessera or sane fallback)
#   --versions "21.0 20.5"  # only stow these X.Y versions
#   -y | --yes          # non-interactive (accept defaults, no prompts)
#   -n | --dry-run      # pass -n -v to stow (simulate)
#   --ref <git-ref>     # checkout tessera at ref/tag/branch after clone
#   --dev <branch>      # same as --ref but explicitly for dev branches
#
set -euo pipefail
IFS=$'\n\t'

# ---------- flags ----------
TES_DIR=""
VERSIONS=""
ASSUME_YES=0
DRYRUN=0
REF=""
DEV=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tessera) TES_DIR="${2:-}"; shift ;;
    --versions) VERSIONS="${2:-}"; shift ;;
    -y|--yes) ASSUME_YES=1 ;;
    -n|--dry-run) DRYRUN=1 ;;
    --ref) REF="${2:-}"; shift ;;
    --dev) DEV="${2:-}"; shift ;;
    -h|--help)
      sed -n '1,120p' "$0"; exit 0 ;;
    --) shift; break ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac; shift
done

# ---------- helpers ----------
log()  { printf '%s\n' "==> $*"; }
warn() { printf '%s\n' "⚠️  $*" >&2; }
die()  { printf '%s\n' "❌ $*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

timestamp() { date +"%Y%m%d-%H%M%S"; }

is_tty() { [[ -t 0 && -t 1 ]]; }

ask() {
  local prompt="$1" def="${2:-}" ans
  if (( ASSUME_YES )); then echo "$def"; return 0; fi
  if is_tty; then
    read -r -p "$prompt ${def:+[$def]}: " ans || true
    echo "${ans:-$def}"
  else
    echo "$def"
  fi
}

# ---------- OS detect ----------
unameOut="$(uname -s || true)"
case "$unameOut" in
  Darwin) OS="mac" ;;
  Linux)  OS="linux" ;;
  CYGWIN*|MINGW*|MSYS*) OS="win" ;;  # Git Bash / MSYS2 / Cygwin
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
      fi
      ;;
    linux)
      # Best-effort per common distros
      if have apt-get; then
        if (( ASSUME_YES )); then sudo apt-get update -y && sudo apt-get install -y stow
        else warn "Install stow with: sudo apt-get update && sudo apt-get install stow"; die "Re-run after installing stow."
        fi
      elif have dnf; then
        if (( ASSUME_YES )); then sudo dnf install -y stow
        else warn "Install stow with: sudo dnf install stow"; die "Re-run after installing stow."
        fi
      elif have pacman; then
        if (( ASSUME_YES )); then sudo pacman -Sy --noconfirm stow
        else warn "Install stow with: sudo pacman -S stow"; die "Re-run after installing stow."
        fi
      elif have zypper; then
        if (( ASSUME_YES )); then sudo zypper install -y stow
        else warn "Install stow with: sudo zypper install stow"; die "Re-run after installing stow."
        fi
      else
        die "Could not determine your package manager. Please install GNU Stow, then re-run."
      fi
      ;;
    win)
      # Expect MSYS2: pacman available; otherwise instruct
      if have pacman; then
        if (( ASSUME_YES )); then pacman -S --noconfirm stow
        else warn "Install stow with: pacman -S stow"; die "Re-run after installing stow."
        fi
      else
        die "Windows: please run under MSYS2/Cygwin and install stow (MSYS2 pacman: pacman -S stow). Then re-run."
      fi
      ;;
  esac
}
ensure_stow

# ---------- find/confirm tessera ----------
DEFAULT_MATRIX="${MATRIX:-}"
if [[ -z "$DEFAULT_MATRIX" ]]; then
  case "$OS" in
    mac)  DEFAULT_MATRIX="$HOME/Library/CloudStorage/Dropbox/matrix" ;;
    linux|win) DEFAULT_MATRIX="$HOME/Dropbox/matrix" ;;
  esac
fi
DEFAULT_TES="${DEFAULT_MATRIX}/tessera"
TES_DIR="${TES_DIR:-$DEFAULT_TES}"

if [[ ! -d "$TES_DIR/.git" ]]; then
  log "Tessera repo not found at: $TES_DIR"
  if (( ASSUME_YES )); then
    TES_PARENT="$(dirname "$TES_DIR")"
  else
    TES_PARENT="$(ask "Where should I clone 'tessera'?" "$(dirname "$TES_DIR")")"
  fi
  mkdir -p "$TES_PARENT"
  if ! have git; then die "git is required to clone tessera."; fi
  log "Cloning tessera → $TES_PARENT/tessera"
  git clone --depth 1 https://github.com/suhailphotos/tessera.git "$TES_PARENT/tessera"
  TES_DIR="$TES_PARENT/tessera"
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

# ---------- write ignore rules (idempotent) ----------
# We ignore files that are host/noise prone:
# - houdini.env (you keep it local when needed)
# - default.shelf and shelf_tool_assets.json (Houdini writes here)
ensure_ignore() {
  local pkg_dir="$1"
  local f="$pkg_dir/.stow-local-ignore"
  # Create/merge idempotently
  mkdir -p "$pkg_dir"
  touch "$f"
  # Append patterns if missing
  add_pat() { grep -qxF "$1" "$f" 2>/dev/null || echo "$1" >> "$f"; }
  add_pat '(^|/)\.DS_Store$'
  add_pat '(^|/)\.git($|/)'
  add_pat '(^|/)\.gitignore$'
  add_pat '(^|/)README(\.md)?$'
  add_pat '(^|/)seed($|/)'
  add_pat '^houdini\.env$'
  add_pat '(^|/)toolbar/default\.shelf$'
  add_pat '(^|/)toolbar/shelf_tool_assets\.json$'
}
ensure_ignore "$STOW_DIR/common"

# ---------- detect installed Houdini versions ----------
declare -a versions
if [[ -n "$VERSIONS" ]]; then
  for v in $VERSIONS; do versions+=("$v"); done
else
  case "$OS" in
    mac)
      # /Applications/Houdini/Houdini21.0.440 → 21.0
      mapfile -t versions < <(ls -1d /Applications/Houdini/Houdini* 2>/dev/null \
        | sed -E 's#.*/Houdini([0-9]+\.[0-9]+)\..*#\1#' \
        | sort -Vu)
      ;;
    linux)
      # Look for /opt/hfsXX.Y.Z (install) → XX.Y
      mapfile -t versions < <(ls -1d /opt/hfs* 2>/dev/null \
        | sed -E 's#.*/hfs([0-9]+\.[0-9]+)\..*#\1#' \
        | sort -Vu)
      ;;
    win)
      # MSYS path to Program Files (both)
      pf="/c/Program Files/Side Effects Software"
      pf86="/c/Program Files (x86)/Side Effects Software"
      mapfile -t versions < <(ls -1d "$pf"/Houdini* "$pf86"/Houdini* 2>/dev/null \
        | sed -E 's#.*/Houdini[ _-]?([0-9]+\.[0-9]+)\..*#\1#' \
        | sort -Vu)
      ;;
  esac
fi

(( ${#versions[@]} )) || die "No Houdini installations detected. Install Houdini first, then re-run."

log "Houdini versions detected: ${versions[*]}"

# ---------- target dir per-OS ----------
pref_dir_for() {
  local ver="$1"
  case "$OS" in
    mac)  echo "$HOME/Library/Preferences/houdini/$ver" ;;
    linux) echo "$HOME/houdini$ver" ;;
    win)  echo "$HOME/Documents/houdini$ver" ;;
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

# ---------- conflict backup ----------
# Parse stow -n output for "existing target ..." and move those to .bak.<ts>
backup_conflicts() {
  local pkg="$1" target="$2"
  local ts="$(timestamp)"
  local out
  # collect conflicts (common + optionally OS overlay)
  if ! out="$(stow -n -v -d "$STOW_DIR" -t "$target" "$pkg" 2>&1)"; then
    :
  fi
  # shellcheck disable=SC2001
  echo "$out" | sed -n 's#.*existing target \(.*\) since neither a link.*#\1#p' | while read -r rel; do
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

# ---------- stow per version ----------
for ver in "${versions[@]}"; do
  target="$(pref_dir_for "$ver")"
  mkdir -p "$target"
  seed_once "$target"

  log "Stowing into: $target"
  # back up conflicts for 'common'
  backup_conflicts "common" "$target"

  # build dry-run flags
  DRY=()
  (( DRYRUN )) && DRY=(-n -v)

  # link common
  stow "${DRY[@]}" -d "$STOW_DIR" -t "$target" common

  # OS overlay (e.g. mac/ocio)
  if [[ -d "$STOW_DIR/$OS" ]]; then
    backup_conflicts "$OS" "$target"
    stow "${DRY[@]}" -d "$STOW_DIR" -t "$target" "$OS"
  fi

  log "✔ Stowed for Houdini $ver → $target"
done

log "All done."
if (( DRYRUN )); then
  warn "You ran with --dry-run. Re-run without -n to apply."
fi
