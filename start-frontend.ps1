param(
    [switch]$Pull,     # git pull first
    [switch]$Install   # force npm install even if nothing changed
)
# start-frontend.ps1 - tx-mdm frontend starter for Windows PowerShell.
# Run from the repo root in a SECOND PowerShell window:   .\start-frontend.ps1
#   .\start-frontend.ps1 -Pull      (git pull first)
#   .\start-frontend.ps1 -Install   (force npm install)
# Runs npm install only when package-lock.json changed since the last install
# (or node_modules is missing), then starts Vite on http://localhost:5173.
# Plain ASCII output only.

$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot
$frontend = Join-Path $repo "frontend"

if ($Pull) {
    Write-Host "[start-frontend] git pull"
    git -C $repo pull
    if ($LASTEXITCODE -ne 0) { throw "git pull failed" }
}

Set-Location $frontend

$stamp = "node_modules\.package-lock.sha256"
$hash = (Get-FileHash "package-lock.json" -Algorithm SHA256).Hash
$old = ""
if (Test-Path $stamp) { $old = (Get-Content $stamp -Raw).Trim() }
if (-not (Test-Path "node_modules")) { $Install = $true }
if ($hash -ne $old) { $Install = $true }

if ($Install) {
    Write-Host "[start-frontend] npm install"
    npm install
    if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
    Set-Content -Path $stamp -Value $hash -Encoding ascii
} else {
    Write-Host "[start-frontend] node_modules up to date, skipping install"
}

Write-Host "[start-frontend] open http://localhost:5173"
npm run dev
