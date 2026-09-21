## 把主场景渲染几帧后截图存盘，用于在没有人盯着屏幕时验证 UI 真的画出来了。
## 必须在非 headless 下运行 —— headless 用的是空渲染驱动，截出来是黑的。
##
##     "E:/Godot/..._console.exe" --path . --script res://tools/capture_scene.gd -- <输出路径> [场景路径]
extends SceneTree

const DEFAULT_SCENE := "res://ui/inventory/inventory_sandbox.tscn"
const WARMUP_FRAMES := 4

var _frames: int = 0
var _out: String = "user://capture.png"
var _scene: Node = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var scene_path: String = args[1] if args.size() > 1 else DEFAULT_SCENE
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("场景加载失败: " + scene_path)
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
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
		quit(1)
		return true
	if img.save_png(_out) != OK:
		push_error("截图保存失败: " + _out)
		quit(1)
		return true
	print("已保存截图: %s (%dx%d)" % [_out, img.get_width(), img.get_height()])
	quit(0)
	return true
