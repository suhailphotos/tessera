# tessera

Scripts + user prefs for Houdini (and room for Nuke, Resolve, Photoshop, Lightroom) — one mosaic, versioned.

> **Goal:** keep the *useful, portable* bits (shelves, scripts, VEX headers, packages) under Git, and sync them into Houdini’s user preference folder with minimal fuss.

---

## Table of contents

- [Folder structure](#folder-structure)
- [What gets linked vs ignored](#what-gets-linked-vs-ignored)
- [Quick start](#quick-start)
  - [One-liner (macOS/Linux) — curl + bootstrap](#one-liner-macoslinux--curl--bootstrap)
  - [Direct script usage (macOS/Linux)](#direct-script-usage-macoslinux)
  - [Windows (experimental, native PowerShell)](#windows-experimental-native-powershell)
- [How to maintain going forward](#how-to-maintain-going-forward)
  - [Common stow commands](#common-stow-commands)
  - [Scenarios & recipes](#scenarios--recipes)
  - [Flags explained](#flags-explained)
- [Current state / tested platforms](#current-state--tested-platforms)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [License](#license)

---

## Folder structure

```
tessera/
├── apps/
│   ├── houdini/
│   │   ├── seed/                     # files copied once (never symlinked)
│   │   │   └── assetGallery.db
│   │   └── stow/                     # Stow "packages"
│   │       ├── common/               # cross-platform Houdini user prefs
│   │       │   ├── packages/         # .json packages (env, OCIO, paths)
│   │       │   ├── scripts/          # 456.py etc.
│   │       │   ├── toolbar/          # custom shelves (default.* is ignored)
│   │       │   ├── vex/              # headers, includes
│   │       │   ├── jump.pref
│   │       │   └── .stow-local-ignore
│   │       ├── mac/                  # mac-only overlay (e.g., OCIO files)
│   │       ├── linux/                # linux-only overlay (placeholder)
│   │       └── win/                  # windows-only overlay (placeholder)
│   ├── nuke/         # placeholder
│   ├── resolve/      # placeholder
│   ├── photoshop/    # placeholder
│   ├── lightroom/    # placeholder
│   └── shared/       # placeholder
└── helper/
    ├── stow_houdini_user_pref.sh     # main cross-platform bootstrap (mac/linux)
    ├── houdini_stow.sh               # local convenience wrapper
    └── windows/
        └── Link-HoudiniUserPrefs.ps1 # experimental native Windows bootstrap
```

### What gets linked vs ignored

- **Linked (from `apps/houdini/stow/common`)**
  - `jump.pref`, `scripts/`, `vex/`, custom shelves (e.g. `suhail.shelf`), `packages/…`
- **Ignored (by `.stow-local-ignore`)**
  - `houdini.env`  
  - `toolbar/default.shelf` and `toolbar/shelf_tool_assets.json`  
  - repo dust: `.git`, `.gitignore`, `README*`, `.DS_Store`, `seed/`

> Rationale: let Houdini keep writing *its* default shelf and env file locally; you version your custom shelves and env via packages instead.

---

## Quick start

> You need Houdini installed. The bootstrap will auto-install **GNU Stow** on macOS (via Homebrew) and prompt you on Linux if it’s missing.

### One-liner (macOS/Linux) — curl + bootstrap

Dry run (recommended first):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/tessera/refs/heads/main/helper/stow_houdini_user_pref.sh)" -- --dry-run
```

Apply for real:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/suhailphotos/tessera/refs/heads/main/helper/stow_houdini_user_pref.sh)"
```

Options you can append after the `--`:

- `--versions "21.0 20.5"` — only link these X.Y versions
- `--tessera "/path/to/tessera"` — repo location (otherwise defaults to `$MATRIX/tessera` or mac Dropbox path)
- `--yes` — non-interactive (assume defaults)
- `--ref v1.2.3` or `--dev feature-branch` — checkout a ref/branch before linking

**What it does:**
1) Ensures **stow** is available.
2) Finds (or clones) the repo into `$MATRIX/tessera` (or asks where to clone).
3) Detects Houdini versions on your machine (e.g., `21.0`).
4) Seeds `assetGallery.db` once if missing.
5) Backs up any conflicting files as `*.pre-stow.<timestamp>.bak`.
6) Stows `common/` and your OS overlay (e.g., `mac/`) into your Houdini user pref dir.

### Direct script usage (macOS/Linux)

If you already have the repo locally:

```bash
# Choose the target Houdini version automatically (or pass X.Y)
helper/houdini_stow.sh
# or
helper/houdini_stow.sh 21.0
```

This is a simple wrapper around GNU Stow for local usage.

### Windows (experimental, native PowerShell)

There’s an initial PowerShell helper you can try (untested):

```powershell
# Allow this session to run the bootstrap, then fetch & run:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
iwr -UseBasicParsing https://raw.githubusercontent.com/suhailphotos/tessera/refs/heads/main/helper/windows/Link-HoudiniUserPrefs.ps1 | iex
```

What it aims to do:
- Detect a Houdini user pref folder (or use `HOUDINI_USER_PREF_DIR` if you’ve set it at the OS level).
- Link files from `apps/houdini/stow/common` (and later `win/`) into that folder.
- Seed `assetGallery.db` once if missing.

> **Status:** untested on Windows. Expect iterations here. See [Roadmap](#roadmap).

---

## How to maintain going forward

Once the initial link is in place, day-to-day maintenance is just **add/edit files in the repo**, then use Stow to sync (or let symlinks reflect the change immediately, depending on your workflow).

### Common stow commands

> Substitute the variables below:
> - `STOW_DIR=apps/houdini/stow`
> - `TARGET` → your Houdini user pref dir (e.g., mac: `~/Library/Preferences/houdini/21.0`)
> - `PKG` → `common` (and `mac`, `linux`, or `win` overlays)

Dry run (see what would happen):

```bash
stow -n -v -d "$STOW_DIR" -t "$TARGET" common
```

Link a package:

```bash
stow -d "$STOW_DIR" -t "$TARGET" common
```

Unlink a package (remove the symlinks it created):

```bash
stow -d "$STOW_DIR" -t "$TARGET" -D common
```

Restow (smart re-link after renames/moves):

```bash
stow -d "$STOW_DIR" -t "$TARGET" -R common
```

Adopt existing files (pull host files *into* your package):

> ⚠️ Dangerous if misused — this **moves** files from the target into your repo.

```bash
stow -d "$STOW_DIR" -t "$TARGET" --adopt common
```

### Scenarios & recipes

**Add a new file (e.g., a new shelf)**
1. Create it inside `apps/houdini/stow/common/toolbar/your.shelf`.
2. `stow -n -v -d "$STOW_DIR" -t "$TARGET" common` (simulate).
3. `stow -d "$STOW_DIR" -t "$TARGET" common` (apply) — creates/updates the link.

**Rename or move something inside the package**
- `stow -d "$STOW_DIR" -t "$TARGET" -R common` (re-evaluate symlinks; cleans up obsolete ones).

**Delete something from the package**
- Delete from the repo, then `-R` to prune any orphaned links:
  ```bash
  stow -d "$STOW_DIR" -t "$TARGET" -R common
  ```

**Target already has a real file (conflict)**
- You’ll see: `existing target ... since neither a link nor a directory`.
- Option A (safer): move it aside, then `stow`:
  ```bash
  mv "$TARGET/toolbar/default.shelf" "$TARGET/toolbar/default.shelf.bak"
  stow -d "$STOW_DIR" -t "$TARGET" common
  ```
- Option B (advanced): `--adopt` (moves host file into your repo).
  ```bash
  stow -d "$STOW_DIR" -t "$TARGET" --adopt common
  ```

**Change what gets ignored**
- Edit `apps/houdini/stow/common/.stow-local-ignore`.
- Current rules skip:
  - `houdini.env`
  - `toolbar/default.shelf`
  - `toolbar/shelf_tool_assets.json`
- Patterns are regular expressions matched **relative to the package root**.  
  Example lines:
  ```
  (^|/)toolbar/default\.shelf$
  (^|/)toolbar/shelf_tool_assets\.json$
  ```

**Multiple Houdini versions**
- Repeat stow against each version’s user pref dir:
  ```bash
  V21="$HOME/Library/Preferences/houdini/21.0"
  V205="$HOME/Library/Preferences/houdini/20.5"
  stow -d "$STOW_DIR" -t "$V21"  common
  stow -d "$STOW_DIR" -t "$V205" common
  ```

**Undo everything (for a package)**
```bash
stow -d "$STOW_DIR" -t "$TARGET" -D common
```

### Flags explained

- `-d DIR` / `--dir=DIR` — the Stow *packages* directory (here: `apps/houdini/stow`).
- `-t DIR` / `--target=DIR` — the destination root (your Houdini user pref folder).
- `-n` / `--no` / `--simulate` — simulation mode, no filesystem changes.
- `-v` / `--verbose` — show what would be linked (repeat `-v` for more verbosity).
- `-D` / `--delete` — **unstow**: remove links created by a package.
- `-R` / `--restow` — **restow**: re-apply (good after renames/moves).
- `--adopt` — (use with caution) move existing *real* files from target into the package, replacing them with symlinks.

---

## Current state / tested platforms

- **macOS:** ✅ working & tested (via `helper/stow_houdini_user_pref.sh`)
- **Linux:** ⚠️ assumed compatible — not yet tested end-to-end
- **Windows:** ⚠️ experimental PowerShell script available: `helper/windows/Link-HoudiniUserPrefs.ps1` (untested)

---

## Troubleshooting

**“existing target … since neither a link nor a directory”**
- Means a *real* file already exists at the link path.  
  Fix: move it aside (or use `--adopt`) and run `stow` again.

**`stow` not found**
- macOS: the bootstrap installs it via Homebrew.
- Linux: install with your package manager:
  - Debian/Ubuntu: `sudo apt-get install stow`
  - Fedora: `sudo dnf install stow`
  - Arch: `sudo pacman -S stow`
- Windows/MSYS2: `pacman -S stow` (if you choose to use MSYS2).

**Houdini doesn’t “see” your shelves / scripts**
- Confirm your target path is right (`~/Library/Preferences/houdini/21.0` on mac).
- Check the symlink points to the repo file (`ls -l`).
- Verify `packages/*.json` are valid JSON and expand to existing paths.

**About `HOUDINI_USER_PREF_DIR`**
- On Windows you *can* set this as a system/user env var so both GUI and CLI see it. This repo doesn’t require it on macOS/Linux, but it’s compatible with that approach.

---

## Roadmap

- **Windows mini-package** (`tessera-link`): a tiny Python CLI published to PyPI that mimics Stow’s behavior (default to hardlinks; fallback to symlinks if cross-volume & Developer Mode/Elevation available). The macOS/Linux bootstrap would keep using GNU Stow; Windows bootstrap would install and call the Python CLI automatically.
- **Windows overlay package** (`apps/houdini/stow/win`) as needed.
- **Linux validation** and overlay if needed.
- Optional: `--adopt` flow with confirmations and dry-run preview.

---

## License

MIT — see [LICENSE](./LICENSE).

---

### Notes for reviewers / contributors

- The main bootstrap you’ll interact with is:  
  `helper/stow_houdini_user_pref.sh`  
  It:
  - verifies Stow,
  - finds or clones the repo,
  - detects Houdini versions,
  - seeds `assetGallery.db` once,
  - backs up conflicts (`*.pre-stow.<timestamp>.bak`),
  - stows `common` and the current OS overlay.

- For quick local testing, `helper/houdini_stow.sh` is a lightweight wrapper.

- Ignore patterns live in `apps/houdini/stow/common/.stow-local-ignore`.  
  Adjust them if you want to version `default.shelf` or `houdini.env` (not recommended unless you really want global defaults across machines).

Happy linking ✨
