# ============================================================
#  VelocityIQ demo packager
#  Builds a clean, shareable ZIP with the demo + one-click launchers.
#  Run:  powershell -ExecutionPolicy Bypass -File .\package-demo.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$stage   = Join-Path $root "VelocityIQ-Demo"
$zipPath = Join-Path $root "VelocityIQ-Demo.zip"

# Files that go into the package
$include = @(
  "velocityiq.html",
  "Open VelocityIQ Demo.bat",
  "Open VelocityIQ Demo.command",
  "open-velocityiq-demo.sh",
  "README.md"
)

Write-Host "Packaging VelocityIQ demo..." -ForegroundColor Cyan

# Fresh staging folder
if (Test-Path $stage)   { Remove-Item $stage -Recurse -Force }
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
New-Item -ItemType Directory -Path $stage | Out-Null

foreach ($f in $include) {
  $src = Join-Path $root $f
  if (-not (Test-Path $src)) { throw "Missing required file: $f" }
  Copy-Item $src -Destination (Join-Path $stage $f) -Force
}

# Build the ZIP (top-level folder = VelocityIQ-Demo)
Compress-Archive -Path $stage -DestinationPath $zipPath -CompressionLevel Optimal

# Clean up staging
Remove-Item $stage -Recurse -Force

$kb = "{0:N0} KB" -f ((Get-Item $zipPath).Length / 1KB)
Write-Host "Created: $zipPath ($kb)" -ForegroundColor Green
Write-Host "Share the ZIP. Recipients unzip and double-click the launcher for their OS." -ForegroundColor Green

