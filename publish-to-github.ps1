# ============================================================
#  VelocityIQ - publish to GitHub Pages (one-time setup + updates)
#  After you create an EMPTY repo on github.com, run:
#     powershell -ExecutionPolicy Bypass -File .\publish-to-github.ps1 -User <you> -Repo velocityiq
#  For later updates just run:  .\publish-to-github.ps1 -Update "your message"
# ============================================================
param(
  [string]$User,
  [string]$Repo = "velocityiq",
  [string]$Update
)
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

# --- Update mode: commit + push current changes ---------------
if ($Update) {
  git add -A
  git commit -m $Update
  git push
  Write-Host "Pushed. GitHub will redeploy the live link in ~1 minute." -ForegroundColor Green
  return
}

# --- First-time setup ----------------------------------------
if (-not $User) { throw "Provide your GitHub username:  -User <you>  (and optional -Repo <name>)" }

if (-not (Test-Path ".git")) {
  git init | Out-Null
  git branch -M main
}

git add -A
# commit only if there is something to commit
if (git status --porcelain) { git commit -m "VelocityIQ demo" | Out-Null }

$remoteUrl = "https://github.com/$User/$Repo.git"
if (git remote 2>$null | Select-String -SimpleMatch "origin") {
  git remote set-url origin $remoteUrl
} else {
  git remote add origin $remoteUrl
}

Write-Host "Pushing to $remoteUrl ..." -ForegroundColor Cyan
git push -u origin main

Write-Host ""
Write-Host "Done. Your shareable link (live in ~1-2 min after the first deploy):" -ForegroundColor Green
Write-Host "    https://$User.github.io/$Repo/" -ForegroundColor Yellow
Write-Host "Track the deploy here:" -ForegroundColor Green
Write-Host "    https://github.com/$User/$Repo/actions" -ForegroundColor Yellow

