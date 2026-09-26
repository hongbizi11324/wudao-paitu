# ==============================================
# 一键打包 Windows 可玩版本
#
# 用法（在任意目录）：
#   powershell -ExecutionPolicy Bypass -File tools\build_release.ps1
#
# 可选参数：
#   -Godot  <Godot编辑器路径>   默认自动探测常见位置
#   -Preset <导出预设名>        默认 "Windows Desktop"
#   -Debug                      导出调试版（可看控制台输出，便于排查）
#
# 产物：build\WuDaoPaiTu.exe（内嵌资源，单文件）
#      build\libluagdextension.windows.template_release.x86_64.dll（Lua运行库，必须与exe同目录）
# 分发：把整个 build 文件夹压缩发给别人即可（exe 与 dll 不能拆开）
# ==============================================
param(
	[string]$Godot = "",
	[string]$Preset = "Windows Desktop",
	[switch]$Debug
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "build"

# ---- 探测 Godot 编辑器 ----
if ($Godot -eq "") {
	$candidates = @(
		"E:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe",
		"C:\Program Files\Godot\Godot_v4.exe",
		"$env:LOCALAPPDATA\Programs\Godot\Godot_v4.exe"
	)
	foreach ($c in $candidates) {
		if (Test-Path $c) { $Godot = $c; break }
	}
}
if ($Godot -eq "" -or -not (Test-Path $Godot)) {
	Write-Error "找不到 Godot 编辑器，请用 -Godot <路径> 指定（例如 godot.windows.opt.tools.64.exe）"
}

Write-Host "Godot : $Godot"
Write-Host "项目  : $root"
Write-Host "预设  : $Preset"
Write-Host ""

# ---- 先导入资源（确保新加的脚本/场景/class_name 都注册）----
Write-Host "[1/3] 导入资源 ..."
& $Godot --headless --path $root --import | Out-Null

# ---- 导出 ----
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
# 让 Godot 忽略导出产物目录（避免扫描 exe/dll）
[System.IO.File]::WriteAllText((Join-Path $outDir ".gdignore"), "")
$exe = Join-Path $outDir "WuDaoPaiTu.exe"
if ($Debug) {
	Write-Host "[2/3] 导出调试版 -> $exe"
	& $Godot --headless --path $root --export-debug $Preset $exe
} else {
	Write-Host "[2/3] 导出发布版 -> $exe"
	& $Godot --headless --path $root --export-release $Preset $exe
}

# ---- 校验产物 ----
Write-Host "[3/3] 校验产物 ..."
if (-not (Test-Path $exe)) {
	Write-Error "导出失败：未生成 $exe（检查是否已安装导出模板：编辑器 → 编辑器菜单 → 管理导出模板）"
}
$dll = Get-ChildItem $outDir -Filter "libluagdextension*.dll" -ErrorAction SilentlyContinue
if (-not $dll) {
	Write-Warning "未找到 lua-gdextension 运行库 DLL，Lua 卡牌逻辑将回退到 GDScript 兜底实现"
}

Get-ChildItem $outDir | Where-Object { -not $_.PSIsContainer -and $_.Name -ne ".gdignore" } |
	ForEach-Object { "{0,-58} {1,8:N1} MB" -f $_.Name, ($_.Length / 1MB) }

Write-Host ""
Write-Host "完成 ✅  可玩版本在：$outDir"
Write-Host "分发提示：把整个 build 文件夹压缩发给别人（exe 与 dll 必须放在一起）"
