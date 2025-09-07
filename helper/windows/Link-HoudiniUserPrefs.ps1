param(
  [string]$TesseraRoot = "$env:USERPROFILE\Dropbox\matrix\tessera",
  [string[]]$Versions,            # e.g. -Versions 21.0,20.5 (optional)
  [switch]$DryRun                 # show actions only
)

$ErrorActionPreference = 'Stop'

function Write-Step($msg){ Write-Host "==> $msg" }
function Write-Warn($msg){ Write-Host "⚠ $msg" -ForegroundColor Yellow }
function TS(){ Get-Date -Format 'yyyyMMdd-HHmmss' }

# --- Validate repo ---------------------------------------------------
if (-not (Test-Path $TesseraRoot)) {
  throw "Tessera repo not found at: $TesseraRoot  (set -TesseraRoot ...)"
}

# Canonical repo locations
$RepoCommon = Join-Path $TesseraRoot 'apps\houdini\stow\common'
$RepoWinOcio = Join-Path $TesseraRoot 'apps\houdini\stow\win\ocio'
$SeedDb = Join-Path $TesseraRoot 'apps\houdini\seed\assetGallery.db'

# --- Detect Houdini versions ----------------------------------------
if (-not $Versions -or $Versions.Count -eq 0) {
  $versions = @()

  # From installs
  $roots = @(
    'C:\Program Files\Side Effects Software',
    'C:\Program Files (x86)\Side Effects Software'
  ) | Where-Object { Test-Path $_ }

  foreach ($r in $roots) {
    Get-ChildItem $r -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      if ($_.Name -match 'Houdini(?:\s|_)?([0-9]+\.[0-9]+)') { $versions += $matches[1] }
    }
  }

  # From existing pref dirs
  Get-ChildItem "$env:USERPROFILE\Documents" -Directory -Filter 'houdini*.*' -ErrorAction SilentlyContinue |
    ForEach-Object {
      if ($_.Name -match 'houdini([0-9]+\.[0-9]+)$') { $versions += $matches[1] }
    }

  $Versions = ($versions | Sort-Object -Unique)
  if (-not $Versions -or $Versions.Count -eq 0) { $Versions = @('21.0') } # sensible default
}
Write-Step "Houdini versions: $($Versions -join ', ')"

# --- Helpers ---------------------------------------------------------
function Is-ReparsePoint($path) {
  try {
    $gi = Get-Item -LiteralPath $path -Force -ErrorAction Stop
    return [bool]($gi.Attributes -band [IO.FileAttributes]::ReparsePoint)
  } catch { return $false }
}

function Backup-IfReal($path) {
  if (Test-Path $path) {
    if (-not (Is-ReparsePoint $path)) {
      $bak = "$path.pre-link.$(TS).bak"
      if ($DryRun) { Write-Host "BACKUP  $path  ->  $bak" }
      else { Move-Item -LiteralPath $path -Destination $bak }
      Write-Warn "Backed up: $path -> $bak"
    } else {
      # If it’s a link already, remove it so we can recreate
      if ($DryRun) { Write-Host "REMOVE LINK $path" }
      else { Remove-Item -LiteralPath $path -Force }
    }
  }
}

function Ensure-DirJunction($linkPath, $targetPath) {
  if (-not (Test-Path $targetPath -PathType Container)) { return } # nothing to link
  if ((Test-Path $linkPath) -and (Is-ReparsePoint $linkPath)) { return } # already linked
  Backup-IfReal $linkPath
  if ($DryRun) { Write-Host "JUNCTION $linkPath  ->  $targetPath" }
  else { New-Item -ItemType Junction -Path $linkPath -Target $targetPath | Out-Null }
}

function Same-Volume($a,$b) {
  ([IO.Path]::GetPathRoot((Resolve-Path $a))).ToLower() -eq ([IO.Path]::GetPathRoot((Resolve-Path $b))).ToLower()
}

function Ensure-FileLink($linkPath, $targetPath) {
  if (-not (Test-Path $targetPath -PathType Leaf)) { return }  # nothing to link
  if ((Test-Path $linkPath) -and (Is-ReparsePoint $linkPath)) { return } # already a link
  Backup-IfReal $linkPath
  $linkDir = Split-Path $linkPath -Parent
  if (-not (Test-Path $linkDir)) { New-Item -ItemType Directory -Path $linkDir | Out-Null }

  if ((Test-Path $linkPath)) { Remove-Item -LiteralPath $linkPath -Force } # if backup left a stub

  if (Same-Volume $linkDir $targetPath) {
    # Hardlink (no admin needed)
    if ($DryRun) { Write-Host "HARDLINK $linkPath  ==  $targetPath" }
    else {
      cmd /c "mklink /H `"$linkPath`" `"$targetPath`"" | Out-Null
    }
  } else {
    # Fallback to symlink (needs Developer Mode or admin)
    if ($DryRun) { Write-Host "SYMLINK $linkPath  ->  $targetPath" }
    else {
      try {
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath | Out-Null
      } catch {
        Write-Warn "Symlink failed for $linkPath. Copying file instead (edits won’t auto-sync back)."
        Copy-Item -LiteralPath $targetPath -Destination $linkPath -Force
      }
    }
  }
}

function Seed-IfMissing($destDir, $seedFile) {
  if ((Test-Path $seedFile -PathType Leaf)) {
    $dst = Join-Path $destDir (Split-Path $seedFile -Leaf)
    if (-not (Test-Path $dst)) {
      if ($DryRun) { Write-Host "SEED $seedFile -> $dst" }
      else { Copy-Item $seedFile $dst }
    }
  }
}

# --- Link for each version ------------------------------------------
foreach ($v in $Versions) {
  $pref = Join-Path $env:USERPROFILE "Documents\houdini$v"
  if (-not (Test-Path $pref)) {
    if ($DryRun) { Write-Host "MKDIR $pref" } else { New-Item -ItemType Directory -Path $pref | Out-Null }
  }
  Write-Step "Configuring $pref"

  # Seed DB (once)
  Seed-IfMissing $pref $SeedDb

  # Directories → junctions (create only if present in repo)
  $dirMap = @{
    'packages' = (Join-Path $RepoCommon 'packages')
    'scripts'  = (Join-Path $RepoCommon 'scripts')
    'toolbar'  = (Join-Path $RepoCommon 'toolbar')
    'otls'     = (Join-Path $RepoCommon 'otls')
    'vex'      = (Join-Path $RepoCommon 'vex')
    'ocio'     = $RepoWinOcio   # optional; link only if you keep a win/ocio tree
  }
  foreach ($name in $dirMap.Keys) {
    $target = $dirMap[$name]
    if (Test-Path $target -PathType Container) {
      $link = Join-Path $pref $name
      Ensure-DirJunction $link $target
    }
  }

  # Files → hardlink (or symlink/copy fallback)
  $fileMap = @{
    'jump.pref'    = (Join-Path $RepoCommon 'jump.pref')
    'houdini.env'  = (Join-Path $RepoCommon 'houdini.env')   # link only if you actually keep one
  }
  foreach ($name in $fileMap.Keys) {
    $src = $fileMap[$name]
    if (Test-Path $src -PathType Leaf) {
      $dst = Join-Path $pref $name
      Ensure-FileLink $dst $src
    }
  }

  Write-Host "✔ Linked → $pref"
}

Write-Step "Done. Launch Houdini and verify Help → About Houdini → Environment."
if ($DryRun) { Write-Warn "This was a dry run. Re-run without -DryRun to apply." }
