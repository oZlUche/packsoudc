#!/bin/bash
# 用法：xr.sh <项目路径> <脚本> [用户参数...]
P=$1; S=$2; shift 2
exec xvfb-run -a -s "-screen 0 1920x1200x24" godot --path "$P" --rendering-driver opengl3 --script "$S" -- "$@" --calib-source=auto
