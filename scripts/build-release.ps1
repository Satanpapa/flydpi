[CmdletBinding()]
param(
    [string]$Configuration = "Release",
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

$BuildRoot = Join-Path $Root "build"
$UiBuild = Join-Path $BuildRoot "ui"
$BackendOut = Join-Path $BuildRoot "flydpi-backend.exe"
$LauncherOut = Join-Path $BuildRoot "FlyDPI.exe"
$Dist = Join-Path $Root $OutputDir

if (-not ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)) {
    throw "FlyDPI release packaging is Windows-only."
}

if (Test-Path $Dist) { Remove-Item $Dist -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Dist | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Dist "bin") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Dist "ui") | Out-Null

Write-Host "[1/5] Checking Rust workspace..."
cargo check --workspace

Write-Host "[2/5] Building Go backend..."
Push-Location (Join-Path $Root "orchestrator")
try {
    go build -trimpath -ldflags "-s -w" -o $BackendOut .\cmd\flydpi
} finally {
    Pop-Location
}

Write-Host "[3/5] Building launcher..."
Push-Location (Join-Path $Root "launcher")
try {
    go build -trimpath -ldflags "-s -w" -o $LauncherOut .
} finally {
    Pop-Location
}

Write-Host "[4/5] Building Qt GUI..."
cmake -S (Join-Path $Root "ui") -B $UiBuild -G "Visual Studio 17 2022" -A x64
cmake --build $UiBuild --config $Configuration
$UiExe = Join-Path $UiBuild "$Configuration\flydpi-ui.exe"
if (-not (Test-Path $UiExe)) { throw "GUI executable not found: $UiExe" }

Write-Host "[5/5] Creating portable distribution..."
Copy-Item $LauncherOut (Join-Path $Dist "FlyDPI.exe") -Force
Copy-Item $BackendOut (Join-Path $Dist "bin\flydpi.exe") -Force
Copy-Item $UiExe (Join-Path $Dist "ui\flydpi-ui.exe") -Force

windeployqt --release --qmldir (Join-Path $Root "ui\qml") (Join-Path $Dist "ui\flydpi-ui.exe")

@'
FlyDPI diagnostic MVP

Run FlyDPI.exe. It starts the local diagnostic backend and the Qt GUI,
then stops the backend when the GUI exits.

Current build is diagnostic-only. No packet payload transformation is enabled.
'@ | Set-Content -Encoding UTF8 (Join-Path $Dist "README.txt")

Write-Host "Release ready: $Dist"
