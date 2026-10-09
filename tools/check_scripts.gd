## 把全项目的 .gd 都加载一遍，抓出解析不了的。
##
##     "E:/Godot/..._console.exe" --headless --path . --script res://tools/check_scripts.gd
##
## [b]为什么需要它：[/b]单元测试只加载 `tests/run_tests.gd` 够得着的那些脚本。
## `ui/` 与 `tools/` 下的东西改接口时最容易漏，而漏掉的表现是「跑起来才炸」——
## 这一步已经吃过两次亏（bench_battle 的类型化数组、content_schema 的
## Variant 推断警告，后者让整个类静默加载失败，测试只表现为一堆莫名其妙的断言不过）。
##
## `--import` 抓不到这些：它只解析被场景引用到的脚本。
extends CliTool

const SKIP_DIRS := [".godot", "addons", ".git"]


func run() -> void:
	var paths := _all_scripts("res://")
	paths.sort()  # 顺序稳定，报错顺序才可复现

	# 只管【强制解析一遍】，判定交给调用方去 grep 引擎自己打的错误行。
	#
	# 不靠返回值：load() 对解析失败的脚本仍然返回一个空壳对象，不是 null。
	# 也不用 reload()：它会把正在执行的这个脚本自己判成失败。
	# 引擎在解析失败时必定往 stderr 打 "Failed to load script ... Parse error"，
	# 那一行才是可靠的信号（tools/test.sh 就是 grep 它）。
	for path in paths:
		load(path)

	# 措辞刻意避开引擎的错误字样：调用方 grep 的就是那几个词，
	# 这行自己带上就会把干净的一次也判成失败（踩过一次）。
	print("已加载 %d 个脚本；解析失败的话，上方会有引擎自己打的报错。" % paths.size())
	finish(0)


func _all_scripts(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root.path_join(f))
	for sub in dir.get_directories():
		# 隐藏目录（.godot / .git / .claude 的工作树……）与 Godot 自己也不扫的 .gdignore 目录都跳过：
		# 工作树里是整个项目的副本，装进来就是每个 class_name 各两份
		if sub.begins_with(".") or SKIP_DIRS.has(sub) or FileAccess.file_exists(root.path_join(sub).path_join(".gdignore")):
			continue
		out.append_array(_all_scripts(root.path_join(sub)))
	return out
