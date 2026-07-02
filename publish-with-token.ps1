# ============================================================
#  VelocityIQ - finish publishing using a GitHub token
#  1) You paste a token into:  %TEMP%\vq_token.txt   (and save)
#  2) This script logs in, creates the repo, pushes, enables Pages,
#     and prints your permanent 24/7 link.
# ============================================================
$ErrorActionPreference = "Stop"
$proj = "C:\Users\Vasanth.Vaidya\VElocity"
Set-Location $proj
$gh = "C:\Program Files\GitHub CLI\gh.exe"
$repo = "velocityiq"
$tokenFile = "$env:TEMP\vq_token.txt"
$result = "$env:TEMP\vq_publish_result.txt"
Remove-Item $result -ErrorAction SilentlyContinue

function Save($msg) { $msg | Set-Content $result }

if (-not (Test-Path $tokenFile)) { Save "NO_TOKEN_FILE"; exit 1 }
$token = (Get-Content $tokenFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($token)) { Save "EMPTY_TOKEN"; exit 1 }

# 1) Authenticate gh with the token (non-interactive, reliable)
$env:GH_TOKEN = $token
$token | & $gh auth login --hostname github.com --git-protocol https --with-token 2>&1 | Out-Null

# 2) Confirm identity
$user = (& $gh api user --jq ".login" 2>&1).Trim()
if (-not $user -or $user -like "*error*" -or $user -like "*message*") { Save ("AUTH_FAILED=" + $user); exit 1 }

# 3) Configure git identity + credential helper so push uses the token
git config user.name  $user 2>$null
git config user.email "$user@users.noreply.github.com" 2>$null
& $gh auth setup-git 2>&1 | Out-Null

# 4) Ensure committed
git add -A 2>$null
if (git status --porcelain) { git commit -m "Publish VelocityIQ demo" 2>&1 | Out-Null }
git branch -M main 2>$null

# 5) Create repo if missing, else just set remote
& $gh repo view "$user/$repo" 1>$null 2>$null
if ($LASTEXITCODE -ne 0) {
  & $gh repo create "$repo" --public --description "VelocityIQ - The Used Car Profit Engine (demo)" 2>&1 | Out-Null
}

if (git remote | Select-String -SimpleMatch "origin") {
  git remote set-url origin "https://github.com/$user/$repo.git"
} else {
  git remote add origin "https://github.com/$user/$repo.git"
}

# 6) Push (token is used via gh credential helper)
$push = git push -u origin main 2>&1 | Out-String

# 7) Enable GitHub Pages via the Actions workflow
& $gh api -X POST "repos/$user/$repo/pages" -f "build_type=workflow" 1>$null 2>$null
& $gh api -X PUT  "repos/$user/$repo/pages" -f "build_type=workflow" 1>$null 2>$null
& $gh workflow run "deploy.yml" 1>$null 2>$null

$link = "https://$user.github.io/$repo/"
Set-Content "$proj\PUBLIC-LINK.txt" $link
Save ("SUCCESS`nUSER=$user`nREPO=https://github.com/$user/$repo`nLINK=$link`nACTIONS=https://github.com/$user/$repo/actions`n---push---`n$push")

# Clean up the token file for safety
Remove-Item $tokenFile -ErrorAction SilentlyContinue

