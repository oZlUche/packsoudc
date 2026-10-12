@echo off
rem 启动正式游戏（Windows）。可选：直接用 Godot 跑项目（普通快捷方式）完全一样 ——
rem 158 起不再先 --import：类缓存过期时游戏自己不到一秒重写、重开；有没导入的新素材才在后台导，不挡游戏。
rem   set GODOT=E:\Godot\Godot_v4.7.1-stable_win64_console.exe && tools\run_game.bat
if "%GODOT%"=="" set GODOT=E:\Godot\Godot_v4.7.1-stable_win64_console.exe
"%GODOT%" --path "%~dp0.."
