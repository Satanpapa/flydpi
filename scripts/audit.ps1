[CmdletBinding()]
param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

function Invoke-Check([string]$Name, [string]$Executable, [string[]]$Arguments) {
    Write-Host "[AUDIT] $Name"
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

Invoke-Check "cargo fmt" "cargo" @("fmt", "--all", "--", "--check")
Invoke-Check "cargo check" "cargo" @("check", "--workspace")
Invoke-Check "cargo test" "cargo" @("test", "--workspace")

Push-Location (Join-Path $Root "orchestrator")
try {
    Invoke-Check "go fmt" "gofmt" @("-l", ".")
    Invoke-Check "go test" "go" @("test", "./...")
    Invoke-Check "go vet" "go" @("vet", "./...")
} finally {
    Pop-Location
}

Write-Host "[AUDIT] repository-level checks passed"
Write-Host "Note: Windows WFP runtime startup must be tested on an elevated Windows host."
Write-Host "Note: this project currently has no active packet-transformation engine."
