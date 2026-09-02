[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$QtDir = $env:Qt6_DIR,
    [string]$OutputDir = "dist\FlyDPI"
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

Require-Command cargo
Require-Command go
Require-Command cmake
Require-Command windeployqt

if (-not $IsWindows) { throw "FlyDPI release packaging is Windows-only." }

$BuildRoot = Join-Path $Root "build"
$UiBuild = Join-Path $BuildRoot "ui"
$GoOut = Join-Path $BuildRoot "flydpi-backend.exe"
$Dist = Join-Path $Root $OutputDir

if (Test-Path $Dist) { Remove-Item $Dist -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Dist | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Dist "bin") | Out-Null

Write-Host "[1/4] Checking Rust workspace..."
cargo check --workspace

Write-Host "[2/4] Building Go orchestrator..."
Push-Location (Join-Path $Root "orchestrator")
try {
    go build -trimpath -ldflags "-s -w" -o $GoOut .\cmd\flydpi
} finally {
    Pop-Location
}

Write-Host "[3/4] Building Qt GUI..."
cmake -S (Join-Path $Root "ui") -B $UiBuild -G "Visual Studio 17 2022" -A x64
cmake --build $UiBuild --config $Configuration
$UiExe = Join-Path $UiBuild "$Configuration\flydpi-ui.exe"
if (-not (Test-Path $UiExe)) { throw "GUI executable not found: $UiExe" }

Write-Host "[4/4] Creating portable distribution..."
Copy-Item $UiExe (Join-Path $Dist "FlyDPI.exe") -Force
Copy-Item $GoOut (Join-Path $Dist "bin\flydpi.exe") -Force

windeployqt --release --qmldir (Join-Path $Root "ui\qml") (Join-Path $Dist "FlyDPI.exe")

@'
FlyDPI diagnostic MVP

Run FlyDPI.exe to start the GUI. It expects bin\flydpi.exe next to it.
The current distribution is diagnostic-only and does not modify packet payloads.
'@ | Set-Content -Encoding UTF8 (Join-Path $Dist "README.txt")

Write-Host "Release ready: $Dist"
