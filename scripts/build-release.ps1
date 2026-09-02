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

function Resolve-WindeployQt {
    $fromPath = Get-Command windeployqt.exe -ErrorAction SilentlyContinue
    if ($fromPath) { return $fromPath.Source }

    $candidates = @(
        "$env:QT_ROOT\bin\windeployqt.exe",
        "$env:QTDIR\bin\windeployqt.exe",
        "$env:Qt6Dir\bin\windeployqt.exe",
        "$env:QtDir\bin\windeployqt.exe",
        "C:\Qt\6.10.0\msvc2022_64\bin\windeployqt.exe",
        "C:\Qt\6.9.3\msvc2022_64\bin\windeployqt.exe",
        "C:\Qt\6.8.3\msvc2022_64\bin\windeployqt.exe",
        "C:\Qt\6.7.3\msvc2022_64\bin\windeployqt.exe",
        "C:\Qt\6.6.3\msvc2022_64\bin\windeployqt.exe",
        "C:\Qt\6.5.3\msvc2022_64\bin\windeployqt.exe"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return (Resolve-Path $candidate).Path }
    }

    foreach ($root in @("C:\Qt", "$env:LOCALAPPDATA\Programs\Qt")) {
        if (Test-Path $root) {
            $found = Get-ChildItem $root -Filter windeployqt.exe -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match '\\msvc2022_64\\bin\\windeployqt\.exe$' } |
                Sort-Object FullName -Descending |
                Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }

    throw @"
windeployqt.exe was not found.
Install Qt 6.x MSVC 2022 x64, or add its 'bin' directory to PATH.
The script also accepts QT_ROOT/QTDIR/Qt6Dir/QtDir pointing at the Qt root.
"@
}

Require-Command cargo
Require-Command go
Require-Command cmake
$WindeployQt = Resolve-WindeployQt

$BuildRoot = Join-Path $Root "build"
$UiBuild = Join-Path $BuildRoot "ui"
$WfpBuild = Join-Path $BuildRoot "wfp-observer"
$BackendOut = Join-Path $BuildRoot "flydpi-backend.exe"
$LauncherOut = Join-Path $BuildRoot "FlyDPI.exe"
$Dist = Join-Path $Root $OutputDir
$CargoTarget = Join-Path $Root "target\release\flydpi_core.dll"
$ObserverDll = Join-Path $WfpBuild "$Configuration\flydpi_wfp_observer.dll"

if (-not ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)) {
    throw "FlyDPI release packaging is Windows-only."
}

if (Test-Path $Dist) { Remove-Item $Dist -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Dist | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Dist "bin") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Dist "ui") | Out-Null

Write-Host "[1/7] Building Rust core runtime..."
cargo check --workspace
cargo build -p flydpi-core --release
if (-not (Test-Path $CargoTarget)) { throw "Rust runtime DLL not found: $CargoTarget" }

Write-Host "[2/7] Building native WFP observer..."
cmake -S (Join-Path $Root "native\wfp-observer") -B $WfpBuild -G "Visual Studio 17 2022" -A x64
cmake --build $WfpBuild --config $Configuration
if (-not (Test-Path $ObserverDll)) { throw "WFP observer DLL not found: $ObserverDll" }

Write-Host "[3/7] Building Go backend..."
Push-Location (Join-Path $Root "orchestrator")
try {
    go build -trimpath -ldflags "-s -w" -o $BackendOut .\cmd\flydpi
} finally {
    Pop-Location
}

Write-Host "[4/7] Building launcher..."
Push-Location (Join-Path $Root "launcher")
try {
    go build -trimpath -ldflags "-s -w" -o $LauncherOut .
} finally {
    Pop-Location
}

Write-Host "[5/7] Building Qt GUI..."
cmake -S (Join-Path $Root "ui") -B $UiBuild -G "Visual Studio 17 2022" -A x64
cmake --build $UiBuild --config $Configuration
$UiExe = Join-Path $UiBuild "$Configuration\flydpi-ui.exe"
if (-not (Test-Path $UiExe)) { throw "GUI executable not found: $UiExe" }

Write-Host "[6/7] Creating portable distribution..."
Copy-Item $LauncherOut (Join-Path $Dist "FlyDPI.exe") -Force
Copy-Item $BackendOut (Join-Path $Dist "bin\flydpi.exe") -Force
Copy-Item $CargoTarget (Join-Path $Dist "bin\flydpi-core.dll") -Force
Copy-Item $ObserverDll (Join-Path $Dist "bin\flydpi_wfp_observer.dll") -Force
Copy-Item $UiExe (Join-Path $Dist "ui\flydpi-ui.exe") -Force

Write-Host "[7/7] Deploying Qt runtime..."
& $WindeployQt --release --qmldir (Join-Path $Root "ui\qml") (Join-Path $Dist "ui\flydpi-ui.exe")

@'
FlyDPI diagnostic MVP + low-level observation runtime

Run FlyDPI.exe. It starts the local backend and Qt GUI.

The bundled Rust runtime and native WFP observer are enabled when Windows
permits WFP net-event subscription. Network payload transformation is not enabled.
'@ | Set-Content -Encoding UTF8 (Join-Path $Dist "README.txt")

Write-Host "Release ready: $Dist"
