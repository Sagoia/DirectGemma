[CmdletBinding()]
param(
    [string]$Triplet = "x64-windows-static-md",
    [string]$VcpkgRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

Write-Host "Restoring vcpkg manifest for $Triplet with $vcpkg"
& $vcpkg install `
    "--x-manifest-root=$manifestRoot" `
    "--x-install-root=$installRoot" `
    "--triplet=$Triplet" `
    "--host-triplet=x64-windows"

if ($LASTEXITCODE -ne 0) {
    throw "vcpkg restore failed with exit code $LASTEXITCODE."
}
