# ============================================================
#  VelocityIQ - create a PUBLIC shareable link (anyone can open)
#  Serves the demo locally and exposes it via a Cloudflare quick tunnel.
#  Run:  powershell -ExecutionPolicy Bypass -File .\share-public-link.ps1
#  Stop: press Ctrl+C, or run .\share-public-link.ps1 -Stop
# ============================================================
param(
  [int]$Port = 8080,
  [switch]$Stop
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
$cf = Join-Path $root "cloudflared.exe"

if ($Stop) {
  Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
  $c = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  if ($c) { $c.OwningProcess | Select-Object -Unique | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue } }
  Write-Host "Stopped tunnel and local server." -ForegroundColor Yellow
  return
}

# 1) Make sure the local server is running
$serverUp = $false
try { Invoke-WebRequest -UseBasicParsing "http://localhost:$Port/" -TimeoutSec 3 | Out-Null; $serverUp = $true } catch {}
if (-not $serverUp) {
  Write-Host "Starting local server on port $Port ..." -ForegroundColor Cyan
  Start-Process -FilePath "node" -ArgumentList "serve-local.js","$Port" -WindowStyle Hidden
  Start-Sleep -Seconds 2
}

# 2) Download cloudflared if needed
if (-not (Test-Path $cf)) {
  Write-Host "Downloading cloudflared (one-time, ~50MB) ..." -ForegroundColor Cyan
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -UseBasicParsing "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile $cf -TimeoutSec 180
}

# 3) Start the quick tunnel and capture the public URL
$log = Join-Path $env:TEMP "vq_tunnel.log"
Remove-Item $log -ErrorAction SilentlyContinue
Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process -FilePath $cf -ArgumentList 'tunnel','--no-autoupdate','--url',"http://localhost:$Port" -RedirectStandardError $log -RedirectStandardOutput "$log.out" -WindowStyle Hidden

Write-Host "Opening a public tunnel..." -ForegroundColor Cyan
$url = $null
for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Seconds 1
  if (Test-Path $log) {
    $m = Select-String -Path $log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -AllMatches -ErrorAction SilentlyContinue
    if ($m) { $url = $m.Matches[0].Value; break }
  }
}

Write-Host ""
if ($url) {
  Write-Host "  PUBLIC LINK (share with anyone):" -ForegroundColor Green
  Write-Host "      $url" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  Keep this window open to keep the link alive." -ForegroundColor Green
  Write-Host "  Stop it with:  .\share-public-link.ps1 -Stop" -ForegroundColor DarkGray
  Set-Content (Join-Path $root "PUBLIC-LINK.txt") $url
} else {
  Write-Host "  Could not read the public URL yet. Check $log" -ForegroundColor Red
}

