## 176：启动屏，项目的主场景。第一帧只画游戏名和一条进度；正式游戏 `game.tscn`（连同它引用到的几百个脚本）
## 在后台线程载入，好了再切过去。原来脚本全量编译挡在第一帧之前，窗口「无响应」两三秒（Windows 更久）；
## 总时长不变，但窗口一直在刷新。`game_director._ready` 里的内容加载仍在主线程（176 待定 2 选 A）。
##
## **不引用任何全局类**（自己不写 class_name，不碰 UiPalette 等）：引用一个，那个类的整张引用图就又回到第一帧之前。
## 颜色写死（与 UiPalette 同值），字体按路径 load()。`tests/tools/test_startup_graph.gd` 守着这条
extends Control

const TARGET := "res://ui/game/game.tscn"
## 与 UiPalette.BG / FG / DIM 同值（不能引用它）
const BG := Color("101216")
const FG := Color("dfe3ea")
const DIM := Color("8b93a1")
const TITLE_FONT := "res://assets/fonts/zhuque_fangsong.ttf"
const BODY_FONT := "res://assets/fonts/serif_regular.otf"
const BAR_W := 360.0
const BAR_H := 4.0

## 载好之后自己切过去（测试关掉，只看载没载好）
var auto_switch := true
## 0–1
var progress := 0.0
var failed := false
## 载好的主场景（切之前）
var scene: PackedScene = null
var _title_font: Font = null
var _body_font: Font = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_font = _font(TITLE_FONT)
	_body_font = _font(BODY_FONT)
	start()


func start() -> void:
	failed = ResourceLoader.load_threaded_request(TARGET) != OK


func _process(_delta: float) -> void:
	if scene == null and not failed:
		poll()
		queue_redraw()


## 查一次后台载入的进度；载好了记下场景（[member auto_switch] 时下一帧切过去）。返回 [enum ResourceLoader.ThreadLoadStatus]
func poll() -> int:
	var p: Array = []
	var status := ResourceLoader.load_threaded_get_status(TARGET, p)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		progress = maxf(progress, float(p[0]) if not p.is_empty() else 0.0)
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		progress = 1.0
		scene = ResourceLoader.load_threaded_get(TARGET) as PackedScene
		failed = scene == null
		if not failed and auto_switch:
			get_tree().change_scene_to_packed.call_deferred(scene)
	else:
		failed = true
	return status


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var mid := size * 0.5
	if _title_font != null:
		draw_string(_title_font, Vector2(0, mid.y - 24), "背包搜打撤", HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, FG)
	var bar := Rect2(mid.x - BAR_W * 0.5, mid.y + 20, BAR_W, BAR_H)
	draw_rect(bar, Color(DIM, 0.35))
	draw_rect(Rect2(bar.position, Vector2(BAR_W * progress, BAR_H)), FG)
	if _body_font != null:
		var note := "载入失败，请重启游戏" if failed else "载入中……"
		draw_string(_body_font, Vector2(0, bar.end.y + 30), note, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, DIM)


## 打包的字体；不在就用引擎默认（不崩）
static func _font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path) as Font
	return ThemeDB.fallback_font
