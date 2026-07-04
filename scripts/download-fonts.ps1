# SPDX-License-Identifier: AGPL-3.0-or-later
# M3a/任务5：PowerShell 版字体下载脚本（与 download-fonts.sh 等价）。
#
# 用法（PowerShell）：
#   pwsh scripts/download-fonts.ps1   # 或 powershell -File scripts/download-fonts.ps1
#
# 字体均为 SIL Open Font License 1.1，不入 git，首次拉取后跑本脚本获取。

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$FontDir = Join-Path $RootDir "app\assets\fonts"

New-Item -ItemType Directory -Force -Path $FontDir | Out-Null

function Download-Font {
  param([string]$OutPath, [string[]]$Urls)
  foreach ($url in $Urls) {
    Write-Host "  try: $url"
    try {
      Invoke-WebRequest -Uri $url -OutFile $OutPath -TimeoutSec 180 -UseBasicParsing
      $size = (Get-Item $OutPath).Length
      Write-Host "  OK ($size bytes)"
      return $true
    } catch {
      Write-Host "  failed: $($_.Exception.Message)"
      if (Test-Path $OutPath) { Remove-Item $OutPath -Force }
    }
  }
  return $false
}

Write-Host "== M3a font download -> $FontDir =="

Write-Host "[1/3] NotoSansSC-Regular.otf (思源黑体)"
[void](Download-Font (Join-Path $FontDir "NotoSansSC-Regular.otf") @(
  "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf",
  "https://gh-proxy.com/https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf"
))

Write-Host "[2/3] NotoSerifSC-Regular.otf (思源宋体)"
[void](Download-Font (Join-Path $FontDir "NotoSerifSC-Regular.otf") @(
  "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Serif/SubsetOTF/SC/NotoSerifSC-Regular.otf",
  "https://gh-proxy.com/https://github.com/notofonts/noto-cjk/raw/main/Serif/SubsetOTF/SC/NotoSerifSC-Regular.otf"
))

Write-Host "[3/3] LXGWWenKai-Regular.ttf (霞鹜文楷)"
[void](Download-Font (Join-Path $FontDir "LXGWWenKai-Regular.ttf") @(
  "https://gh-proxy.com/https://github.com/lxgw/LxgwWenKai/releases/download/v1.522/LXGWWenKai-Regular.ttf",
  "https://ghfast.top/https://github.com/lxgw/LxgwWenKai/releases/download/v1.522/LXGWWenKai-Regular.ttf",
  "https://github.com/lxgw/LxgwWenKai/releases/download/v1.522/LXGWWenKai-Regular.ttf"
))

Write-Host "== verify =="
$ok = 0; $fail = 0
foreach ($f in @("NotoSansSC-Regular.otf", "NotoSerifSC-Regular.otf", "LXGWWenKai-Regular.ttf")) {
  $p = Join-Path $FontDir $f
  if ((Test-Path $p) -and (Get-Item $p).Length -gt 0) {
    Write-Host "  OK $f ($((Get-Item $p).Length) bytes)"
    $ok++
  } else {
    Write-Host "  MISSING $f"
    $fail++
  }
}
Write-Host ""
Write-Host "done: $ok ok / $fail failed"
if ($fail -gt 0) {
  Write-Host "WARNING: some fonts failed; the corresponding options will fall back to system fonts."
  exit 1
}
Write-Host "After download, run 'flutter pub get' in app/ to register fonts."
