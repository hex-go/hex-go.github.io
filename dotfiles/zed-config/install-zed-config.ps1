# install-zed-config.ps1
# 在新的 Windows 机器上运行，安装 Zed keymap/tasks + WSL 速查表脚本。
# 用法（PowerShell）:
#   cd 到本 export 目录
#   powershell -ExecutionPolicy Bypass -File .\install-zed-config.ps1
# 可选参数:
#   -Distro Ubuntu-22.04   指定 WSL 发行版（默认自动取第一个）

param(
  [string]$Distro = ""
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Backup($path) {
  if (Test-Path $path) {
    $bak = "$path.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $path $bak -Force
    Write-Host "  备份原文件 -> $bak" -ForegroundColor DarkGray
  }
}

# ---- 1. Zed keymap.json / tasks.json ----------------------------------
$zedDir = "$env:APPDATA\Zed"
New-Item -ItemType Directory -Force -Path $zedDir | Out-Null

foreach ($f in @("keymap.json", "tasks.json")) {
  $src = Join-Path $here "zed\$f"
  $dst = Join-Path $zedDir $f
  if (Test-Path $src) {
    Backup $dst
    Copy-Item $src $dst -Force
    Write-Host "[OK] Zed $f -> $dst" -ForegroundColor Green
  } else {
    Write-Host "[跳过] 找不到 $src" -ForegroundColor Yellow
  }
}

# ---- 2. WSL 速查表脚本 -------------------------------------------------
$cheat = Join-Path $here "wsl\.zed-cheatsheet.sh"
if (Test-Path $cheat) {
  # 选择 WSL 发行版
  if (-not $Distro) {
    $distros = (wsl.exe -l -q) 2>$null | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }
    if ($distros -and $distros.Count -ge 1) { $Distro = $distros[0] }
  }
  if (-not $Distro) {
    Write-Host "[跳过] 未检测到 WSL 发行版，手动运行: wsl cp ... ~/.zed-cheatsheet.sh" -ForegroundColor Yellow
  } else {
    Write-Host "使用 WSL 发行版: $Distro" -ForegroundColor Cyan
    # 取 WSL 家目录，通过 \\wsl.localhost UNC 路径用 Copy-Item 写入（保持原始字节，不经控制台编码）
    $wslHome = (wsl.exe -d $Distro -- bash -lc 'printf %s "$HOME"').Trim()
    if ($wslHome) {
      $unc = "\\wsl.localhost\$Distro" + ($wslHome -replace '/','\') + "\.zed-cheatsheet.sh"
      Copy-Item $cheat $unc -Force
      # 规范化为 LF 换行 + 加可执行权限
      wsl.exe -d $Distro -- bash -lc "sed -i 's/\r$//' ~/.zed-cheatsheet.sh && chmod +x ~/.zed-cheatsheet.sh && bash -n ~/.zed-cheatsheet.sh && echo '[OK] ~/.zed-cheatsheet.sh 已安装并校验通过'"
    } else {
      Write-Host "[跳过] 取不到 WSL 家目录" -ForegroundColor Yellow
    }
  }
} else {
  Write-Host "[跳过] 找不到 $cheat" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "完成。请完全重启 Zed 使 keymap 生效。" -ForegroundColor Green
Write-Host "提示: settings.json 未自动覆盖（含代理/WSL 路径等机器相关配置），" -ForegroundColor DarkYellow
Write-Host "      如需参考请查看 export 里的 zed\settings.reference.json，手动挑选合并。" -ForegroundColor DarkYellow
