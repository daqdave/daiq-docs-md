# setup-md-mirror.ps1
#
# Initialize the daiq-docs-md folder as a git repository and push it to the
# new daiq-docs-md repo on GitHub.
#
# Prerequisite: you must first create the empty repo on github.com:
#   1. Go to https://github.com/new
#   2. Repository name: daiq-docs-md
#   3. Public, no README, no .gitignore, no license (we have all those locally)
#   4. Create repository
#
# Then run this script from a Windows PowerShell terminal:
#   cd C:\Users\david.green\Dropbox\Work\GitHub\daiq-docs-md
#   powershell -ExecutionPolicy Bypass -File .\scripts\setup-md-mirror.ps1
#
# What this script does:
#   1. Locates git (PATH, then standard install paths, then GitHub Desktop's
#      bundled portable git).
#   2. Initializes a git repo in this folder.
#   3. Stages and commits all files with a one-shot initial commit message.
#   4. Configures the remote and pushes to origin/main.
#
# After it pushes, enable GitHub Pages on the new repo:
#   Settings -> Pages -> Source: Deploy from a branch -> main -> / (root) -> Save
# The site will be live at https://daqdave.github.io/daiq-docs-md/

$ErrorActionPreference = 'Stop'

$repo = Resolve-Path "$PSScriptRoot\.."
Set-Location $repo
Write-Host "Working in: $repo" -ForegroundColor Cyan

# Locate git.exe (same logic as finish-migration.ps1)
function Find-Git {
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        "$env:ProgramFiles\Git\cmd\git.exe",
        "$env:ProgramFiles\Git\bin\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
        "${env:ProgramFiles(x86)}\Git\bin\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    $ghdRoot = Join-Path $env:LOCALAPPDATA "GitHubDesktop"
    if (Test-Path $ghdRoot) {
        $latestApp = Get-ChildItem -Path $ghdRoot -Directory -Filter "app-*" -ErrorAction SilentlyContinue |
                     Sort-Object Name -Descending | Select-Object -First 1
        if ($latestApp) {
            $ghdGit = Join-Path $latestApp.FullName "resources\app\git\cmd\git.exe"
            if (Test-Path $ghdGit) { return $ghdGit }
            $ghdGit2 = Join-Path $latestApp.FullName "resources\app\git\mingw64\bin\git.exe"
            if (Test-Path $ghdGit2) { return $ghdGit2 }
        }
    }
    return $null
}

$git = Find-Git
if (-not $git) {
    Write-Host "Git not found. Install Git for Windows or run from a shell with git on PATH." -ForegroundColor Red
    exit 1
}
Write-Host "Using git at: $git" -ForegroundColor Cyan

# When using GitHub Desktop's bundled git, prepend its bin folders to PATH
$gitDir = Split-Path -Parent $git
$gitRoot = Split-Path -Parent $gitDir
if (Test-Path (Join-Path $gitRoot "mingw64\bin")) {
    $env:Path = "$gitRoot\mingw64\bin;$gitRoot\usr\bin;$env:Path"
}

# Sanity: did the user create the GitHub repo first?
Write-Host ""
Write-Host "[1/4] Confirm the empty GitHub repo was created" -ForegroundColor Yellow
Write-Host "  Before this script can push, you need an empty repo at:"
Write-Host "    https://github.com/daqdave/daiq-docs-md"
Write-Host "  If you have not created it, do so now (https://github.com/new)."
$ready = Read-Host "  Has the empty daiq-docs-md repo been created on github.com? (y/N)"
if ($ready -notmatch '^[Yy]') {
    Write-Host "  OK - create the repo first, then re-run this script." -ForegroundColor Yellow
    exit 0
}

# 2. git init (skip if already initialized)
Write-Host ""
Write-Host "[2/4] Initializing git repo..." -ForegroundColor Yellow
if (Test-Path ".git") {
    Write-Host "  .git already exists; using existing repo."
} else {
    & $git init -b main
    if ($LASTEXITCODE -ne 0) { Write-Host "  git init failed." -ForegroundColor Red; exit 1 }
    Write-Host "  Initialized empty repo on branch main."
}

# 3. Stage everything and commit
Write-Host ""
Write-Host "[3/4] Staging and committing all files..." -ForegroundColor Yellow
& $git add -A
if ($LASTEXITCODE -ne 0) { Write-Host "  git add failed." -ForegroundColor Red; exit 1 }

$commitMsg = @'
Initial commit - markdown mirror of daiq-docs

Snapshot of the original markdown-based documentation site, restored from
the pre-html-migration tag of the daiq-docs repository.

- 49 articles in docs/<slug>/index.md with separate per-article images/ folders
- Original Just-the-Docs Jekyll setup
- Sitemap includes per-image entries
- baseurl set to /daiq-docs-md so the site publishes at
  https://daqdave.github.io/daiq-docs-md/

Companion to the embedded-images version published at
https://daqdave.github.io/daiq-docs/
'@

& $git commit -m $commitMsg
if ($LASTEXITCODE -ne 0) {
    Write-Host "  git commit failed (maybe nothing new to commit)." -ForegroundColor Yellow
}

# 4. Set remote and push
Write-Host ""
Write-Host "[4/4] Setting remote and pushing..." -ForegroundColor Yellow

# Remove existing origin if present (idempotent re-runs)
$existingOrigin = & $git remote 2>$null | Where-Object { $_ -eq "origin" }
if ($existingOrigin) {
    & $git remote remove origin | Out-Null
}

# Try the user's preferred remote URL form. SSH first, fall back to HTTPS if SSH fails.
$sshUrl = "git@github.com:daqdave/daiq-docs-md.git"
$httpsUrl = "https://github.com/daqdave/daiq-docs-md.git"

Write-Host "  Trying SSH remote: $sshUrl"
& $git remote add origin $sshUrl
& $git push -u origin main 2>&1 | Tee-Object -Variable pushOutput | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Host "  SSH push failed. Switching to HTTPS..." -ForegroundColor Yellow
    & $git remote set-url origin $httpsUrl
    Write-Host "  Trying HTTPS remote: $httpsUrl"
    & $git push -u origin main
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  HTTPS push also failed." -ForegroundColor Red
        Write-Host "  Run 'git push -u origin main' manually after authenticating." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Pushed. Now enable GitHub Pages:" -ForegroundColor Green
Write-Host "  https://github.com/daqdave/daiq-docs-md/settings/pages" -ForegroundColor Green
Write-Host "  Source: Deploy from a branch -> main -> / (root) -> Save" -ForegroundColor Green
Write-Host ""
Write-Host "After 1-2 minutes, the site will be live at:" -ForegroundColor Green
Write-Host "  https://daqdave.github.io/daiq-docs-md/" -ForegroundColor Green
