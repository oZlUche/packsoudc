## 把主场景渲染几帧后截图存盘，用于在没有人盯着屏幕时验证 UI 真的画出来了。
## 必须在非 headless 下运行 —— headless 用的是空渲染驱动，截出来是黑的。
##
##     "E:/Godot/..._console.exe" --path . --script res://tools/capture_scene.gd -- <输出路径> [场景路径]
extends CliTool

const DEFAULT_SCENE := "res://ui/inventory/inventory_sandbox.tscn"
const WARMUP_FRAMES := 4

var _frames: int = 0
var _out: String = "user://capture.png"
var _scene: Node = null


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var scene_path: String = args[1] if args.size() > 1 else DEFAULT_SCENE
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("场景加载失败: " + scene_path)
		finish(1)
		return
	GameDirector.fades_allowed = false     # 157：截图不截到淡入一半的屏
	_scene = packed.instantiate()
	root.add_child(_scene)
	# 告诉 SceneTree 这就是当前场景。不设的话 current_scene 是 null，
	# 而靠它判断「现在在哪个场景」的东西（DevNav 的返回按钮）会以为自己不该出现 ——
	# 截图就会少掉一块真实运行时看得见的界面。
	current_scene = _scene


## 覆写 tick 而不是 _process —— 基类的 _process 里有「run() 被错误中断」的兜底，
## 直接覆写会把它盖掉，又变回挂住。
func tick(_delta: float) -> bool:
	_frames += 1
	# 截图用的演示钩子：场景如果提供了 demo_fill()，先调一下，
	# 否则截到的往往是一个空界面。必须等到进入帧循环：
	# 在 _initialize 里 add_child 后立刻调用，场景的 _ready 还没跑。
	if _frames == 1 and _scene != null and _scene.has_method("demo_fill"):
		_scene.call("demo_fill")
	if _frames < WARMUP_FRAMES:
		return false
	var img := root.get_texture().get_image()
	if img == null:
		push_error("取不到视口图像")
		finish(1)
		return true
	if img.save_png(_out) != OK:
		push_error("截图保存失败: " + _out)
		finish(1)
		return true
	print("已保存截图: %s (%dx%d)" % [_out, img.get_width(), img.get_height()])
	finish(0)
	return true
