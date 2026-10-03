@echo off
rem 启动正式游戏（Windows），先 --import 重建全局类缓存。可选（115）：直接用 Godot 跑项目（普通快捷方式）也行 ——
rem 缓存过期时游戏会自己重导、自己重开，这个脚本只是省掉那一次重启。
rem   set GODOT=E:\Godot\Godot_v4.7.1-stable_win64_console.exe && tools\run_game.bat
if "%GODOT%"=="" set GODOT=E:\Godot\Godot_v4.7.1-stable_win64_console.exe
"%GODOT%" --headless --path "%~dp0.." --import
"%GODOT%" --path "%~dp0.."
