# roadrunner wrapper for Windows PowerShell. First run makes .venv and installs the runner.
# Usage: .\run.ps1 [roadrunner arguments]   e.g.  .\run.ps1 --local --auto run TTF --all
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
if (-not (Test-Path ".venv\Scripts\python.exe")) {
    Write-Host "Creating .venv and installing roadrunner (first run only)..."
    python -m venv .venv
    .\.venv\Scripts\python.exe -m pip install --quiet --upgrade pip
    .\.venv\Scripts\python.exe -m pip install --quiet -e ".[dev]"
}
.\.venv\Scripts\python.exe -m roadrunner.cli @args
exit $LASTEXITCODE
