# ============================================================
#  VelocityIQ - GO LIVE (permanent 24/7 link on GitHub Pages)
#  One command. You just click "Authorize" in the browser once.
#
#  Run this in PowerShell from the project folder:
#     powershell -ExecutionPolicy Bypass -File .\go-live.ps1
# ============================================================
param([string]$Repo = "velocityiq")

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

# 1) Locate GitHub CLI
$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $gh) {
  foreach ($p in @("$env:ProgramFiles\GitHub CLI\gh.exe", "$env:LOCALAPPDATA\Microsoft\WinGet\Links\gh.exe")) {
    if (Test-Path $p) { $gh = $p; break }
  }
}
if (-not $gh) { Write-Host "GitHub CLI not found. Install it and re-run." -ForegroundColor Red; exit 1 }

# 2) Make sure everything is committed
git add -A 2>$null
if (git status --porcelain) { git commit -m "Publish VelocityIQ" | Out-Null }
git branch -M main 2>$null

# 3) Sign in to GitHub (opens your browser — click Authorize). One time only.
& $gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "  A browser will open. Sign in and click 'Authorize'." -ForegroundColor Cyan
  Write-Host "  (Choose: GitHub.com  ->  HTTPS  ->  Login with a web browser)" -ForegroundColor DarkGray
  Write-Host ""
  & $gh auth login --hostname github.com --git-protocol https --web
  if ($LASTEXITCODE -ne 0) { Write-Host "Login was not completed. Re-run when ready." -ForegroundColor Red; exit 1 }
}

# 4) Who am I
$user = (& $gh api user --jq ".login").Trim()
if (-not $user) { Write-Host "Could not read your GitHub username." -ForegroundColor Red; exit 1 }

# 5) Create the repo (or reuse it) and push
$exists = $false
& $gh repo view "$user/$Repo" 1>$null 2>$null
if ($LASTEXITCODE -eq 0) { $exists = $true }

if (-not $exists) {
  Write-Host "Creating public repo $user/$Repo and pushing..." -ForegroundColor Cyan
  & $gh repo create "$Repo" --public --source "." --remote origin --push
} else {
  Write-Host "Repo exists - pushing latest..." -ForegroundColor Cyan
  if (-not (git remote | Select-String -SimpleMatch "origin")) {
    git remote add origin "https://github.com/$user/$Repo.git"
  }
  git push -u origin main
}

# 6) Enable GitHub Pages (build from the Actions workflow already in .github/)
try {
  & $gh api -X POST "repos/$user/$Repo/pages" -f "build_type=workflow" 1>$null 2>$null
} catch { }

# 7) Kick the deploy workflow (in case it didn't auto-trigger)
try { & $gh workflow run "deploy.yml" 1>$null 2>$null } catch { }

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host "   YOUR PERMANENT 24/7 LINK (works with your laptop OFF):" -ForegroundColor Green
Write-Host "       https://$user.github.io/$Repo/" -ForegroundColor Yellow
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "   First deploy takes ~1-2 minutes. Watch it here:" -ForegroundColor Green
Write-Host "       https://github.com/$user/$Repo/actions" -ForegroundColor Cyan
Write-Host ""
Write-Host "   To update later, just run:  .\go-live.ps1" -ForegroundColor DarkGray
Set-Content "PUBLIC-LINK.txt" "https://$user.github.io/$Repo/"

