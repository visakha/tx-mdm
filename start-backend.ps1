param(
    [switch]$Pull,     # git pull first
    [switch]$Install   # force pip install even if nothing changed
)
# start-backend.ps1 - tx-mdm backend starter for Windows PowerShell.
# Run from the repo root in a NEW PowerShell window:   .\start-backend.ps1
#   .\start-backend.ps1 -Pull      (git pull first)
#   .\start-backend.ps1 -Install   (force the pip install)
# What it does, in order:
#   1. optional git pull
#   2. creates backend\.venv if missing
#   3. activates it and ALWAYS uses .venv\Scripts\python.exe
#      (never the global Python in AppData - that caused "No module named faker")
#   4. runs pip install -e ".[dev]" when pyproject.toml changed since the last
#      install, or when a required package will not import
#   5. creates backend\.env from .env.example if missing (then stops so you can
#      fill in your IDMC username and password)
#   6. starts uvicorn on 0.0.0.0:8000
# Plain ASCII output only.

$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot
$backend = Join-Path $repo "backend"

if ($Pull) {
    Write-Host "[start-backend] git pull"
    git -C $repo pull
    if ($LASTEXITCODE -ne 0) { throw "git pull failed" }
}

Set-Location $backend

if (-not (Test-Path ".venv\Scripts\python.exe")) {
    Write-Host "[start-backend] creating .venv"
    python -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw "python -m venv failed - is Python 3.12+ installed?" }
    $Install = $true
}

. .\.venv\Scripts\Activate.ps1
$py = Join-Path $backend ".venv\Scripts\python.exe"

$stamp = ".venv\.pyproject.sha256"
$hash = (Get-FileHash "pyproject.toml" -Algorithm SHA256).Hash
$old = ""
if (Test-Path $stamp) { $old = (Get-Content $stamp -Raw).Trim() }
if ($hash -ne $old) {
    Write-Host "[start-backend] pyproject.toml changed since last install"
    $Install = $true
}

& $py -c "import fastapi, uvicorn, pydantic, httpx, faker" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[start-backend] a required package is missing in .venv"
    $Install = $true
}

if ($Install) {
    Write-Host "[start-backend] pip install -e .[dev]"
    & $py -m pip install -e ".[dev]"
    if ($LASTEXITCODE -ne 0) { throw "pip install failed" }
    Set-Content -Path $stamp -Value $hash -Encoding ascii
} else {
    Write-Host "[start-backend] packages up to date, skipping install"
}

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "[start-backend] created backend\.env from .env.example."
    Write-Host "[start-backend] put your IDMC username and password in it:  notepad .env"
    Write-Host "[start-backend] then run .\start-backend.ps1 again."
    exit 1
}

Write-Host "[start-backend] python: $py"
Write-Host "[start-backend] check after start:  Invoke-RestMethod http://127.0.0.1:8000/api/about"
& $py -m uvicorn app.main:app --host 0.0.0.0 --port 8000
