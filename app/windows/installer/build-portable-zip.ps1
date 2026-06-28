# 智阅 portable zip builder
# Usage (from app/):
#   powershell -ExecutionPolicy Bypass -File windows\installer\build-portable-zip.ps1
# Prerequisite: flutter build windows --release has been run.

param(
    [string]$Version = "0.5.0"
)

$ErrorActionPreference = "Stop"

$AppRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ReleaseDir = Join-Path $AppRoot "build\windows\x64\runner\Release"
$OutputDir = Join-Path $AppRoot "build\installer"
$ZipName = "zhiyue-portable-$Version.zip"
$ZipPath = Join-Path $OutputDir $ZipName

if (-not (Test-Path $ReleaseDir)) {
    Write-Error "Release directory not found: $ReleaseDir`nRun 'flutter build windows --release' first."
    exit 1
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

if (Test-Path $ZipPath) {
    Write-Host "Removing existing $ZipName ..."
    Remove-Item $ZipPath -Force
}

Write-Host "Zipping $ReleaseDir -> $ZipPath ..."
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal

$size = (Get-Item $ZipPath).Length / 1MB
Write-Host ("Done: {0} ({1:N1} MB)" -f $ZipPath, $size)
