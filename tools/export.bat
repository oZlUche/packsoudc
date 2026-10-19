@echo off
rem 200：导出两种包（同一份代码，两个导出预设，见 export_presets.cfg）：
rem   玩家版 = release 模板、无 dev 特性：没有启动器、调试台、开发开关，也不出 .console.exe → build\packsoudc.exe
rem   开发版 = debug 模板 + dev 特性：启动器、调试台都在，带控制台窗口看报错 → build\dev\packsoudc.exe
rem 需要先在编辑器里装好 4.7.1 的导出模板（编辑器 → 管理导出模板）。
rem   set GODOT=E:\Godot\Godot_v4.7.1-stable_win64_console.exe && tools\export.bat
chcp 65001 >nul
if "%GODOT%"=="" set GODOT=E:\Godot\Godot_v4.7.1-stable_win64_console.exe
cd /d "%~dp0.."
if not exist build\dev mkdir build\dev
"%GODOT%" --headless --export-release "玩家版" build/packsoudc.exe
"%GODOT%" --headless --export-debug "开发版" build/dev/packsoudc.exe
