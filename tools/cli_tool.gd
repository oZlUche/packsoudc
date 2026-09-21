## 命令行工具的公共外壳。`--script` 跑的脚本一律继承它，不要直接继承 SceneTree。
##
## [b]它解决一件事：脚本出错时进程要退出，而不是挂住。[/b]
##
## [codeblock]
## extends CliTool
##
## func run() -> void:
##     ...做事...
##     finish(0)          # 必须调，见下
## [/codeblock]
##
## 需要跑多帧的（比如等渲染出图）覆写 [method tick]，在那里调 [method finish]。
class_name CliTool
extends SceneTree

## 工具自身崩了的退出码。与 run_tests.gd 一致 ——
## 和「跑完了但结果不合格」（1）分开：后者是内容的问题，前者是代码的问题。
const EXIT_CRASHED := 2

var _done: bool = false


func _initialize() -> void:
	run()


## 子类在这里做事，**结束前必须调 [method finish]**。
func run() -> void:
	push_error("CliTool: 子类没有实现 run()")
	finish(EXIT_CRASHED)


## 收尾。**一律用它代替 quit()** —— 兜底靠「有没有调过它」来判断这次是不是正常结束。
func finish(code: int = 0) -> void:
	_done = true
	quit(code)


## 每帧调用，返回 true 表示收工。默认 run() 一结束就退出；
## 需要等渲染的工具覆写它。
func tick(_delta: float) -> bool:
	return true


## 兜底。[b]这两件事都是实测出来的，不要想当然：[/b]
##
## 1. GDScript 的运行时错误**只中断出错的那一层函数**，调用方会继续往下走。
##    所以「在 run() 后面放一句 _completed = true」判断不出 run() 有没有崩 ——
##    它照样会执行到。判据只能是「run() 自己有没有走到 finish()」。
## 2. 若出错的正好是 `_initialize`（比如没有这层外壳、直接在里面做事），
##    那一层就被整个中断，`quit()` 永远执行不到。无头 SceneTree 没有别的事干，
##    于是进程一直空转 —— 在 CI 里表现为**超时**，本地表现为「命令跑了几分钟没回来」。
##    两种都比一条报错难查得多。这正是本类存在的理由：
##    只要 `_process` 存在，进程就一定会结束。
##
## 这个坑在 [code]tests/run_tests.gd[/code] 里踩过一次并加了兜底，
## 但每个工具各写一份迟早漏掉一个（收进基类时，七个工具里有六个没有）。
func _process(delta: float) -> bool:
	if _done:
		return true
	var wants_exit := tick(delta)
	if _done:
		return true  # tick 里调了 finish，正常收尾
	if not wants_exit:
		return false  # 还要再跑几帧
	push_error("CliTool: 没有走到 finish()，run() 多半被错误中断了")
	print("")
	print("!! 工具没有正常收尾，往上看 SCRIPT ERROR")
	quit(EXIT_CRASHED)
	return true
