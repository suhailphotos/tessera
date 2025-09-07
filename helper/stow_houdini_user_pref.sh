#!/usr/bin/env bash
# stow_houdini_user_pref.sh — Bash 3.2 compatible
# Robustly stow tessera Houdini prefs with conflict backups.
#
# Usage (shareable):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/tessera/refs/heads/main/helper/stow_houdini_user_pref.sh)" [-- --dry-run]
#
# Flags:
#   --tessera <dir>            Override tessera dir (default: $MATRIX/tessera or ~/Library/CloudStorage/Dropbox/matrix/tessera on mac)
#   --versions "21.0 20.5"     Stow only these X.Y versions
#   --yes | -y                 Assume yes (noninteractive)
#   --dry-run | -n             Dry run (pass -n -v to stow)
#   --ref <git ref> | --dev <branch>   Checkout tessera at ref/branch before stow

set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
stow_houdini_user_pref.sh — stow tessera Houdini prefs safely

Flags:
  --tessera <dir>            Override tessera dir (default: $MATRIX/tessera or ~/Library/CloudStorage/Dropbox/matrix/tessera on mac)
  --versions "21.0 20.5"     Stow only these X.Y versions
  --yes | -y                 Assume yes (noninteractive)
  --dry-run | -n             Dry run (pass -n -v to stow)
  --ref <git ref> | --dev <branch>   Checkout tessera at ref/branch before stow

Examples:
  # Dry-run (recommended first)
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/tessera/refs/heads/main/helper/stow_houdini_user_pref.sh)" -- --dry-run

  # Real run
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/tessera/refs/heads/main/helper/stow_houdini_user_pref.sh)"
EOF
}

# ---------------- Flags ----------------
TES_DIR=""; VERSIONS=""; ASSUME_YES=0; DRYRUN=0; REF=""; DEV=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tessera)  TES_DIR="${2:-}"; shift ;;
    --versions) VERSIONS="${2:-}"; shift ;;
    -y|--yes)   ASSUME_YES=1 ;;
    -n|--dry-run) DRYRUN=1 ;;
    --ref) REF="${2:-}"; shift ;;
    --dev) DEV="${2:-}"; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac; shift
done

log()  { printf '==> %s\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*" >&2; }
die()  { printf '❌ %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
timestamp() { date +"%Y%m%d-%H%M%S"; }
is_tty() { [ -t 0 ] && [ -t 1 ]; }
ask() {
  prompt="$1"; def="${2:-}"; ans=""
  if [ "$ASSUME_YES" -eq 1 ]; then echo "$def"; return 0; fi
  if is_tty; then read -r -p "$prompt ${def:+[$def]}: " ans || true; echo "${ans:-$def}"
  else echo "$def"; fi
}

# ---------------- OS detect ----------------
uname_s="$(uname -s || true)"
case "$uname_s" in
  Darwin) OS="mac" ;;
  Linux)  OS="linux" ;;
  CYGWIN*|MINGW*|MSYS*) OS="win" ;;
  *) die "Unsupported OS: ${uname_s}" ;;
esac
log "OS detected: $OS"

# ---------------- Ensure stow ----------------
ensure_stow() {
  if have stow; then return 0; fi
  case "$OS" in
    mac)
      if have brew; then
        log "Installing stow via Homebrew…"
        brew install stow >/dev/null || die "brew install stow failed"
      else
        die "GNU Stow not found and Homebrew missing. Install Homebrew (https://brew.sh) then re-run."
      fi ;;
    linux)
      if have apt-get; then
        if [ "$ASSUME_YES" -eq 1 ]; then sudo apt-get update -y && sudo apt-get install -y stow
        else warn "Install stow: sudo apt-get update && sudo apt-get install stow"; die "Re-run after installing stow."; fi
      elif have dnf; then
        if [ "$ASSUME_YES" -eq 1 ]; then sudo dnf install -y stow; else warn "Install stow: sudo dnf install stow"; die "Re-run after installing stow."; fi
      elif have pacman; then
        if [ "$ASSUME_YES" -eq 1 ]; then sudo pacman -Sy --noconfirm stow; else warn "Install stow: sudo pacman -S stow"; die "Re-run after installing stow."; fi
      elif have zypper; then
        if [ "$ASSUME_YES" -eq 1 ]; then sudo zypper install -y stow; else warn "Install stow: sudo zypper install stow"; die "Re-run after installing stow."; fi
      else
        die "Please install GNU Stow with your package manager, then re-run."
      fi ;;
    win)
      if have pacman; then
        if [ "$ASSUME_YES" -eq 1 ]; then pacman -S --noconfirm stow; else warn "Install stow: pacman -S stow"; die "Re-run after installing stow."; fi
      else
        die "Windows: run under MSYS2/Cygwin and install stow (pacman -S stow), then re-run."
      fi ;;
  esac
}
ensure_stow

# ---------------- Tessera repo ----------------
DEFAULT_MATRIX="${MATRIX:-}"
if [ -z "$DEFAULT_MATRIX" ]; then
  case "$OS" in
    mac) DEFAULT_MATRIX="$HOME/Library/CloudStorage/Dropbox/matrix" ;;
    *)   DEFAULT_MATRIX="$HOME/Dropbox/matrix" ;;
  esac
fi
DEFAULT_TES="${DEFAULT_MATRIX}/tessera"
TES_DIR="${TES_DIR:-$DEFAULT_TES}"

if [ ! -d "$TES_DIR/.git" ]; then
  log "Tessera repo not found at: $TES_DIR"
  parent="$(dirname "$TES_DIR")"
  parent="$(ask "Where should I clone 'tessera'?" "$parent")"
  mkdir -p "$parent"
  have git || die "git is required to clone tessera."
  log "Cloning tessera → $parent/tessera"
  git clone --depth 1 https://github.com/suhailphotos/tessera.git "$parent/tessera"
  TES_DIR="$parent/tessera"
else
  log "Found tessera at: $TES_DIR"
fi

# Optional checkout
if [ "${DEV-}" != "" ] || [ "${REF-}" != "" ]; then
  REF="${DEV:-$REF}"
  log "Checking out tessera @ $REF"
  git -C "$TES_DIR" fetch --depth 1 origin "$REF" || true
  git -C "$TES_DIR" checkout -q "$REF" || git -C "$TES_DIR" checkout -q FETCH_HEAD || true
fi

STOW_DIR="$TES_DIR/apps/houdini/stow"
[ -d "$STOW_DIR/common" ] || die "Missing tessera package dir: $STOW_DIR/common"

# ---------------- Ignore rules ----------------
ensure_ignore() {
  pkg_dir="$1"; f="$1/.stow-local-ignore"
  mkdir -p "$pkg_dir"; touch "$f"
  _add() { grep -qxF "$1" "$f" 2>/dev/null || echo "$1" >> "$f"; }
  _add '(^|/)\.DS_Store$'
  _add '(^|/)\.git($|/)'
  _add '(^|/)\.gitignore$'
  _add '(^|/)README(\.md)?$'
  _add '(^|/)seed($|/)'
  _add '^houdini\.env$'
  _add '(^|/)toolbar/default\.shelf$'
  _add '(^|/)toolbar/shelf_tool_assets\.json$'
}
ensure_ignore "$STOW_DIR/common"

# ---------------- Version detection ----------------
versions=()
if [ -n "$VERSIONS" ]; then
  for v in $VERSIONS; do [ -n "$v" ] && versions+=("$v"); done
else
  case "$OS" in
    mac)
      shopt -s nullglob
      uniqfile="$(mktemp /tmp/houvers.XXXXXX)"
      for p in /Applications/Houdini/Houdini*; do
        base="${p##*/}"  # Houdini21.0.440
        case "$base" in
          Houdini*.*.*)
            num="${base#Houdini}"   # 21.0.440
            IFS='.' read -r maj min patch <<<"$num"
            if [ -n "${maj:-}" ] && [ -n "${min:-}" ]; then printf '%s.%s\n' "$maj" "$min" >>"$uniqfile"; fi
            ;;
        esac
      done
      shopt -u nullglob
      if [ -s "$uniqfile" ]; then
        # de-dup via awk (portable)
        while IFS= read -r line; do versions+=("$line"); done < <(awk '!seen[$0]++' "$uniqfile")
      fi
      rm -f "$uniqfile" || true
      ;;
    linux)
      shopt -s nullglob
      uniqfile="$(mktemp /tmp/houvers.XXXXXX)"
      for p in /opt/hfs*; do
        base="${p##*/}"  # hfs21.0.440
        case "$base" in
          hfs*.*.*)
            num="${base#hfs}"   # 21.0.440
            IFS='.' read -r maj min patch <<<"$num"
            if [ -n "${maj:-}" ] && [ -n "${min:-}" ]; then printf '%s.%s\n' "$maj" "$min" >>"$uniqfile"; fi
            ;;
        esac
      done
      shopt -u nullglob
      if [ -s "$uniqfile" ]; then
        while IFS= read -r line; do versions+=("$line"); done < <(awk '!seen[$0]++' "$uniqfile")
      fi
      rm -f "$uniqfile" || true
      ;;
    win)
      shopt -s nullglob
      uniqfile="$(mktemp /tmp/houvers.XXXXXX)"
      for p in "/c/Program Files/Side Effects Software"/Houdini* "/c/Program Files (x86)/Side Effects Software"/Houdini*; do
        [ -e "$p" ] || continue
        base="${p##*/}"  # Houdini21.0.440
        case "$base" in
          Houdini*.*.*)
            num="${base#Houdini}"
            IFS='.' read -r maj min patch <<<"$num"
            if [ -n "${maj:-}" ] && [ -n "${min:-}" ]; then printf '%s.%s\n' "$maj" "$min" >>"$uniqfile"; fi
            ;;
        esac
      done
      shopt -u nullglob
      if [ -s "$uniqfile" ]; then
        while IFS= read -r line; do versions+=("$line"); done < <(awk '!seen[$0]++' "$uniqfile")
      fi
      rm -f "$uniqfile" || true
      ;;
  esac
fi

# If still empty: harvest user-pref dirs (mac fallback)
if [ "${#versions[@]}" -eq 0 ] && [ "$OS" = "mac" ]; then
  shopt -s nullglob
  for d in "$HOME/Library/Preferences/houdini"/*; do
    [ -d "$d" ] || continue
    bn="${d##*/}"        # X.Y
    case "$bn" in
      *.*) IFS='.' read -r maj min <<<"$bn"; [ -n "${maj:-}" ] && [ -n "${min:-}" ] && versions+=("$maj.$min");;
    esac
  done
  shopt -u nullglob
fi

[ "${#versions[@]}" -gt 0 ] || die "No Houdini installations detected. Install Houdini first, then re-run."
log "Houdini versions detected: ${versions[*]}"

# ---------------- Paths/helpers ----------------
pref_dir_for() {
  case "$OS" in
    mac)  echo "$HOME/Library/Preferences/houdini/$1" ;;
    linux) echo "$HOME/houdini$1" ;;
    win)  echo "$HOME/Documents/houdini$1" ;;
  esac
}

seed_once() {
  target="$1"; seed="$TES_DIR/apps/houdini/seed/assetGallery.db"
  if [ -f "$seed" ] && [ ! -e "$target/assetGallery.db" ]; then
    cp "$seed" "$target/assetGallery.db"
    log "Seeded assetGallery.db → $target"
  fi
}

# Move pre-existing *files* (not symlinks) that would conflict with stow
backup_conflicts() {
  pkg="$1"; target="$2"; ts="$(timestamp)"
  out="$(stow -n -v -d "$STOW_DIR" -t "$target" "$pkg" 2>&1 || true)"
  echo "$out" | sed -n 's#.*existing target \(.*\) since neither a link.*#\1#p' \
    | while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        abs="$target/$rel"
        if [ -e "$abs" ] && [ ! -L "$abs" ]; then
          bak="${abs}.pre-stow.${ts}.bak"
          mkdir -p "$(dirname "$bak")"
          mv "$abs" "$bak"
          warn "Backed up: $abs → $bak"
        fi
      done
}

run_stow() {
  target="$1"
  flags=""
  if [ "$DRYRUN" -eq 1 ]; then flags="-n -v"; fi
  # shellcheck disable=SC2086
  stow $flags -d "$STOW_DIR" -t "$target" common
  if [ -d "$STOW_DIR/$OS" ]; then
    # shellcheck disable=SC2086
    stow $flags -d "$STOW_DIR" -t "$target" "$OS"
  fi
}

# ---------------- Do the work per version ----------------
for ver in "${versions[@]}"; do
  target="$(pref_dir_for "$ver")"
  mkdir -p "$target"
  seed_once "$target"

  log "Preparing to stow into: $target"
  backup_conflicts "common" "$target"
  if [ -d "$STOW_DIR/$OS" ]; then backup_conflicts "$OS" "$target"; fi

  log "Stowing into: $target"
  run_stow "$target"

  log "✔ Finished Houdini $ver → $target"
done

log "All done."
if [ "$DRYRUN" -eq 1 ]; then warn "This was a dry run. Re-run without --dry-run to apply."; fi
