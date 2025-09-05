# tessera

scripts + user prefs for houdini, nuke, resolve, photoshop, and lightroom — one mosaic.

## what is this?
a single place to version the useful bits from your media apps: startup scripts, menus, shelves, actions, presets, and small helpers. aim is portability and repeatability across machines.

## structure
tessera/
├── apps/
│   ├── houdini/     # $HOME/houdiniX.Y (prefs, scripts, shelves, otls) — curate what you track
│   ├── nuke/        # .nuke (menus.py, init.py, gizmos, plugins)
│   ├── resolve/     # Fusion macros, scripts, templates
│   ├── photoshop/   # actions, UXP/CEP scripts, generator plugins
│   ├── lightroom/   # Lua scripts, presets (not catalogs)
│   └── shared/      # cross-app utilities, linting, CI
└── helper/          # repo management helpers (collect/apply/sync)

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
