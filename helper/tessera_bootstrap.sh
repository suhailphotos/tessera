#!/usr/bin/env bash
# tessera bootstrap
# Creates the GitHub repo, clones it into $MATRIX/tessera, scaffolds folders/files,
# sets a token-based remote via 1Password CLI for pushing, commits, and pushes.
#
# Requirements:
#   - gh (GitHub CLI) authenticated to your account
#   - git
#   - 1Password CLI (`op`) logged in and able to `op read` the secret
#   - $MATRIX environment variable set to your workspace root
#
# NOTE: The remote is temporarily configured with a token embedded in the URL.
#       This can appear in `git remote -v` and your .git/config. If you prefer,
#       after the first push you can switch back to a standard URL:
#         git remote set-url origin "https://github.com/suhailphotos/tessera"
#       or use: `gh auth setup-git` to configure a credential helper.
set -euo pipefail
IFS=$'\n\t'

REPO_OWNER="suhailphotos"
REPO_NAME="tessera"
REPO_SLUG="${REPO_OWNER}/${REPO_NAME}"
DESC="scripts + user prefs for houdini, nuke, resolve, photoshop, and lightroom — one mosaic"

require() { command -v "$1" >/dev/null 2>&1 || { echo "Error: missing dependency '$1'." >&2; exit 1; }; }
require gh
require git
require op

: "${MATRIX:?Set MATRIX to your workspace root, e.g. /Users/suhail/Library/CloudStorage/Dropbox/matrix}"

echo "==> Ensuring GitHub repo exists: ${REPO_SLUG}"
if ! gh repo view "${REPO_SLUG}" >/dev/null 2>&1; then
  gh repo create "${REPO_SLUG}"     --public     --description "${DESC}"     --license mit     --add-readme
else
  echo "    Repo already exists on GitHub."
fi

echo "==> Cloning repo into ${MATRIX}/${REPO_NAME} (if missing)"
cd "${MATRIX}"
if [ ! -d "${REPO_NAME}" ]; then
  gh repo clone "${REPO_SLUG}" "${REPO_NAME}"
else
  echo "    Directory already exists; skipping clone."
fi

cd "${REPO_NAME}"

echo "==> Configuring remote with PAT from 1Password (for push)"
# This embeds your token into the remote URL — see note at top of file
GH_TOKEN="$(op read 'op://devTools/GitHub Repo Key/secret key')"
git remote set-url origin "https://${GH_TOKEN}@github.com/${REPO_SLUG}"

echo "==> Building folder structure"
mkdir -p apps/{houdini,nuke,resolve,photoshop,lightroom,shared} helper
touch apps/houdini/.gitkeep       apps/nuke/.gitkeep       apps/resolve/.gitkeep       apps/photoshop/.gitkeep       apps/lightroom/.gitkeep       apps/shared/.gitkeep       helper/.gitkeep

echo "==> Writing .gitignore"
cat > .gitignore <<'EOF'
# OS junk
.DS_Store
Thumbs.db
Icon?
._*

# macOS metadata
.Spotlight-V100
.Trashes
.fseventsd

# Editors / IDEs
.vscode/
.idea/
*.swp
*.swo
*.tmp

# Python
__pycache__/
*.py[cod]
*.pyo
*.pyd
*.egg-info/
.venv/
.env
pytest_cache/
.mypy_cache/

# Node (if any helper tools use it)
node_modules/
dist/
build/

# Logs
*.log

# Lightroom (we keep scripts/presets, not catalogs/previews)
*.lrcat*
*.lrdata/
*.lrprev/

# Binary caches/archives you don’t intend to version
*.zip
*.tar
*.tar.gz
*.7z

# Keep empty directories tracked
!.gitkeep
EOF

echo "==> Writing README.md"
cat > README.md <<'EOF'
# tessera

scripts + user prefs for houdini, nuke, resolve, photoshop, and lightroom — one mosaic.

## what is this?
a single place to version the useful bits from your media apps: startup scripts, menus, shelves, actions, presets, and small helpers. aim is portability and repeatability across machines.

## structure
```
tessera/
├── apps/
│   ├── houdini/     # $HOME/houdiniX.Y (prefs, scripts, shelves, otls) — curate what you track
│   ├── nuke/        # .nuke (menus.py, init.py, gizmos, plugins)
│   ├── resolve/     # Fusion macros, scripts, templates
│   ├── photoshop/   # actions, UXP/CEP scripts, generator plugins
│   ├── lightroom/   # Lua scripts, presets (not catalogs)
│   └── shared/      # cross-app utilities, linting, CI
└── helper/          # repo management helpers (collect/apply/sync)
```

> empty folders contain a `.gitkeep` so they stay in git.

## philosophy
- **track code & small text assets** (py/lua/js/json/toml/xml).
- **avoid heavy, machine-specific blobs** (databases, previews, transient caches).
- prefer **deterministic setup** via helper scripts (symlinks or copy-once).

## getting started
- add app-specific setup notes in each `apps/<app>/README.md` as you go.
- use `helper/` for scripts like `collect.sh` (pull from user dirs) and `apply.sh` (symlink/push to user dirs).

## license
MIT — see [LICENSE](./LICENSE).
EOF

echo "==> Writing LICENSE"
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2025 Suhail

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
EOF

echo "==> Commit & push"
git add .
if git commit -m "chore: scaffold tessera structure, README, LICENSE, .gitignore" ; then
  :
else
  echo "    Nothing to commit (working tree clean)."
fi

echo "==> Pushing to origin main"
git push -u origin main

echo "==> Optional: reset remote to standard URL (commented)"
# git remote set-url origin "https://github.com/${REPO_SLUG}"

echo "✅ Done. Repo is ready: https://github.com/${REPO_SLUG}"
