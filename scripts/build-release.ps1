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

function Invoke-NativeBuild([string]$Name, [string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
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
        "C:\Qt\6.11.2\msvc2022_64\bin\windeployqt.exe",
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

function Resolve-QtPrefix([string]$WindeployQtPath) {
    $binDir = Split-Path $WindeployQtPath -Parent
    $prefix = Split-Path $binDir -Parent
    $config = Join-Path $prefix "lib\cmake\Qt6\Qt6Config.cmake"
    if (Test-Path $config) { return (Resolve-Path $prefix).Path }

    foreach ($root in @("C:\Qt", "$env:LOCALAPPDATA\Programs\Qt")) {
        if (Test-Path $root) {
            $found = Get-ChildItem $root -Filter Qt6Config.cmake -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match '\\lib\\cmake\\Qt6\\Qt6Config\.cmake$' -and $_.FullName -match 'msvc2022_64' } |
                Sort-Object FullName -Descending |
                Select-Object -First 1
            if ($found) {
                return (Split-Path (Split-Path (Split-Path (Split-Path $found.FullName -Parent) -Parent) -Parent) -Parent)
            }
        }
    }

    throw @"
Qt6Config.cmake was not found for the detected windeployqt:
$WindeployQtPath
Install the Qt 6 MSVC 2022 x64 development package, or set QT_ROOT to the
Qt installation prefix containing lib\cmake\Qt6\Qt6Config.cmake.
"@
}

Require-Command cargo
Require-Command go
Require-Command cmake
$WindeployQt = Resolve-WindeployQt
$QtPrefix = Resolve-QtPrefix $WindeployQt
Write-Host "Using Qt prefix: $QtPrefix"
Write-Host "Using windeployqt: $WindeployQt"

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
Invoke-NativeBuild "cargo check --workspace" "cargo" @("check", "--workspace")
Invoke-NativeBuild "cargo build -p flydpi-core --release" "cargo" @("build", "-p", "flydpi-core", "--release")
if (-not (Test-Path $CargoTarget)) { throw "Rust runtime DLL not found: $CargoTarget" }

Write-Host "[2/7] Building native WFP observer..."
Invoke-NativeBuild "cmake configure WFP observer" "cmake" @("-S", (Join-Path $Root "native\wfp-observer"), "-B", $WfpBuild, "-G", "Visual Studio 17 2022", "-A", "x64")
Invoke-NativeBuild "cmake build WFP observer" "cmake" @("--build", $WfpBuild, "--config", $Configuration)
if (-not (Test-Path $ObserverDll)) { throw "WFP observer DLL not found: $ObserverDll" }

Write-Host "[3/7] Building Go backend..."
Push-Location (Join-Path $Root "orchestrator")
try {
    Invoke-NativeBuild "go build backend" "go" @("build", "-trimpath", "-ldflags", "-s -w", "-o", $BackendOut, ".\cmd\flydpi")
} finally {
    Pop-Location
}

Write-Host "[4/7] Building launcher..."
Push-Location (Join-Path $Root "launcher")
try {
    Invoke-NativeBuild "go build launcher" "go" @("build", "-trimpath", "-ldflags", "-s -w", "-o", $LauncherOut, ".")
} finally {
    Pop-Location
}

Write-Host "[5/7] Building Qt GUI..."
$QtArgs = @(
    "-DQt6_ROOT=$QtPrefix",
    "-DCMAKE_PREFIX_PATH=$QtPrefix"
)
Invoke-NativeBuild "cmake configure Qt GUI" "cmake" ($QtArgs + @("-S", (Join-Path $Root "ui"), "-B", $UiBuild, "-G", "Visual Studio 17 2022", "-A", "x64"))
Invoke-NativeBuild "cmake build Qt GUI" "cmake" @("--build", $UiBuild, "--config", $Configuration)
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
if ($LASTEXITCODE -ne 0) {
    throw "windeployqt failed with exit code $LASTEXITCODE."
}

@'
FlyDPI diagnostic MVP + low-level observation runtime

Run FlyDPI.exe. It starts the local backend and Qt GUI.

The bundled Rust runtime and native WFP observer are enabled when Windows
permits WFP net-event subscription. Network payload transformation is not enabled.
'@ | Set-Content -Encoding UTF8 (Join-Path $Dist "README.txt")

Write-Host "Release ready: $Dist"