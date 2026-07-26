[CmdletBinding(DefaultParameterSetName = "Restore", PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Restore")]
    [ValidateSet("x64", "ARM64")]
    [string]$Architecture,
    [Parameter(ParameterSetName = "Restore")]
    [string]$VcpkgRoot,
    [Parameter(Mandatory = $true, ParameterSetName = "Help")]
    [Alias("h", "?")]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Help) {
    Write-Host @"
Restore the vcpkg dependencies for one target architecture.

Usage:
  .\msvc\gemma\restore-vcpkg.ps1 -Architecture x64
  .\msvc\gemma\restore-vcpkg.ps1 -Architecture ARM64
  .\msvc\gemma\restore-vcpkg.ps1 -Architecture ARM64 -VcpkgRoot C:\vcpkg
  .\msvc\gemma\restore-vcpkg.ps1 -Help

Architectures:
  x64    uses x64-windows-static-md
  ARM64  uses arm64-windows-static-md
"@
    return
}

$targetTriplet = switch ($Architecture) {
    "x64" { "x64-windows-static-md" }
    "ARM64" { "arm64-windows-static-md" }
}

$hostArchitecture = $env:PROCESSOR_ARCHITECTURE
if (-not $hostArchitecture) {
    throw "PROCESSOR_ARCHITECTURE is not set."
}

$hostTriplet = switch ($hostArchitecture.ToUpperInvariant()) {
    "AMD64" { "x64-windows" }
    "ARM64" { "arm64-windows" }
    default {
        throw "Unsupported host architecture: $hostArchitecture"
    }
}

if ($env:VCPKG_DEFAULT_BINARY_CACHE) {
    $binaryCacheRoot = [System.IO.Path]::GetFullPath(
        $env:VCPKG_DEFAULT_BINARY_CACHE
    )
    New-Item -ItemType Directory -Force -Path $binaryCacheRoot | Out-Null
    $env:VCPKG_DEFAULT_BINARY_CACHE = $binaryCacheRoot
    Write-Host "Using vcpkg binary cache at $binaryCacheRoot"
}

$vcpkgCandidates = @(
    @(
        $VcpkgRoot
        $env:VCPKG_INSTALLATION_ROOT
        $env:VCPKG_ROOT
    ) | Where-Object { $_ } | ForEach-Object { Join-Path $_ "vcpkg.exe" }
)

$vcpkgCommand = Get-Command vcpkg.exe -ErrorAction SilentlyContinue
if ($vcpkgCommand) {
    $vcpkgCandidates += $vcpkgCommand.Source
}

# GitHub-hosted Windows runners install vcpkg separately from Visual Studio.
$vcpkgCandidates += "C:\vcpkg\vcpkg.exe"

$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path -LiteralPath $vswhere) {
    $visualStudioRoot = & $vswhere -latest -products * `
        -requires Microsoft.Component.MSBuild -property installationPath
    if ($LASTEXITCODE -eq 0 -and $visualStudioRoot) {
        $vcpkgCandidates += Join-Path `
            ($visualStudioRoot | Select-Object -First 1) "VC\vcpkg\vcpkg.exe"
    }
}

$vcpkgCandidates = $vcpkgCandidates | Select-Object -Unique
$vcpkg = $vcpkgCandidates |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1

if (-not $vcpkg) {
    throw "Could not find vcpkg.exe. Checked: $($vcpkgCandidates -join ', ')"
}

$manifestRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$installRoot = Join-Path $manifestRoot "vcpkg_installed"

Write-Host "Restoring vcpkg manifest for $Architecture ($targetTriplet) with $vcpkg"
Write-Host "Using vcpkg host triplet $hostTriplet"
& $vcpkg install `
    "--x-manifest-root=$manifestRoot" `
    "--x-install-root=$installRoot" `
    "--triplet=$targetTriplet" `
    "--host-triplet=$hostTriplet"

if ($LASTEXITCODE -ne 0) {
    throw "vcpkg restore failed with exit code $LASTEXITCODE."
}
