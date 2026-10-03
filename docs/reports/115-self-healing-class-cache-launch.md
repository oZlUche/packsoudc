# 115 · 小修：缓存过期时游戏自己重导、自己重启 —— 本地启动不再要特定命令行

> 架构设计线程，2026-10-03。作者原话：「关于缓存类和本地启动的问题，如果不同步缓存类就会需求本地用特定命令行启动游戏，但这对我来说十分不方便」。
> 本文只做方案，不实施。

## 一、问题

102 定了类缓存（`.godot/global_script_class_cache.cfg`）不进仓库。于是「拉了带新 `class_name` 的代码、不开编辑器直接跑游戏」这条路必须先 `--import`，现在靠 `tools/run_game.bat` 包一层：作者得用这个脚本（或命令行）启动，普通的「双击 / 快捷方式」会灰屏，`DevNav` 只能顶一条红字说「去跑 tools/run_game」。

不方便的根源不在「缓存进不进仓库」，而在**缓存过期时游戏只会报错、不会自救**。缓存回仓库（102 的 B2）会把冲突和脏工作区的代价重新背上，而且作者在本地改一个类、执行线程在另一支改一个类的情形现在天天发生，所以不走回头路。

## 二、方案：`DevNav` 自救

`DevNav` 是 autoload、只用内建类型，缓存坏了它也活着（094 就是这么设计的，`stale_classes()` 已经能查出缺哪些类）。把它现在的「红字提示」换成「自己修」：

1. 启动时（非编辑器、非导出包，和现在 `_check_class_cache` 的门一样）`stale_classes()` 非空 →
2. 全屏盖一块面板写「脚本缓存过期，正在重建……」，用 `OS.create_process(OS.get_executable_path(), ["--headless", "--path", <项目根>, "--import"])` 起一个导入进程（**不用 `OS.execute`**：它会卡住主线程，窗口变成未响应），在 `_process` 里 `OS.is_process_running(pid)` 轮询；
3. 导入进程退出后，`OS.create_process(OS.get_executable_path(), ["--path", <项目根>] + 原来的用户参数 + ["--", "cache-rebuilt"])` 重开一份游戏，自己 `get_tree().quit()`；
4. 新进程启动时若用户参数里有 `cache-rebuilt` 且 `stale_classes()` 还是非空（导入失败、磁盘只读之类），**不再循环**：回落到现在的红字提示，并附上缺的类名。

项目根用 `ProjectSettings.globalize_path("res://")`；可执行文件用 `OS.get_executable_path()`，作者用的是 console 版 Godot，`--headless --import` 跑完就退，几秒。

效果：桌面上放一个普通快捷方式（目标 `Godot_console.exe --path G:\oziuc\背包搜打撤`），拉完代码直接双击 —— 缓存旧了会看到几秒「正在重建」然后游戏自己起来；编辑器里 F5 照旧（编辑器自己重建，这条路不经过自救）。`tools/run_game.bat` 留着，省掉一次重启，不再是必经之路。

## 三、改动点

| 处 | 改 |
|---|---|
| `ui/dev_nav.gd` | `_check_class_cache()` 改成上面的流程；拆成可测的纯函数 `import_args(root) -> PackedStringArray`、`relaunch_args(root, user_args) -> PackedStringArray`、`already_rebuilt(user_args) -> bool`；红字分支保留为回落 |
| `tests/ui/test_dev_nav.gd` | 加断言：两个参数函数的输出；带 `cache-rebuilt` 时不再起进程；缓存齐全时什么也不做（现有断言） |
| `tools/run_game.bat / .sh` | 注释改成「可选：省一次重启」 |
| `docs/status.md`、架构文档 11.1 | 「不开编辑器直接跑游戏走 run_game」改成「直接跑即可，缓存过期会自重建」；版本记录一条 |

不碰 `.gitignore`，不碰 `test.sh`（它跑在无窗口环境，照旧先 `--import`）。

## 四、待定

| # | 事 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 重建期间的界面 | 全屏一句话 / 什么都不画 | **全屏一句话**（不然几秒黑窗像卡死） |
| 2 | 重启后要不要回到原来的场景 | 只回主菜单 / 带上原用户参数 | **带上原用户参数**（F6 跑单场景的路径不变） |
