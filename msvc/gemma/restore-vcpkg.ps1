[CmdletBinding()]
param(
    [string]$Triplet = "x64-windows-static-md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$vcpkgRoots = @(
    $env:VCPKG_INSTALLATION_ROOT
    $env:VCPKG_ROOT
) | Where-Object { $_ }

$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path -LiteralPath $vswhere) {
    $visualStudioRoot = & $vswhere -latest -products * `
        -requires Microsoft.Component.MSBuild -property installationPath
    if ($LASTEXITCODE -eq 0 -and $visualStudioRoot) {
        $vcpkgRoots += Join-Path ($visualStudioRoot | Select-Object -First 1) "VC\vcpkg"
    }
}

$vcpkg = $vcpkgRoots |
    ForEach-Object { Join-Path $_ "vcpkg.exe" } |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1

if (-not $vcpkg) {
    throw "Could not find vcpkg.exe. Install the Visual Studio C++ workload with vcpkg."
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
