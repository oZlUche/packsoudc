@echo off
rem 启动正式游戏（Windows）。先 --import 重建全局类缓存：新加了带 class_name 的脚本后不这么做，
rem 依赖它的脚本会整体解析失败，场景挂不上脚本 —— 表现为一片灰屏（091）。
rem   set GODOT=E:\Godot\Godot_v4.7.1-stable_win64_console.exe && tools\run_game.bat
if "%GODOT%"=="" set GODOT=E:\Godot\Godot_v4.7.1-stable_win64_console.exe
"%GODOT%" --headless --path "%~dp0.." --import
"%GODOT%" --path "%~dp0.."
