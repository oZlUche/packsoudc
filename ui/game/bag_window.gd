## 背包浮窗（216 补充，作者 2026-10-20 选乙：一格 72）：地图 / 事件 / 休息屏按 B 开的那一块。
##
## 定尺寸的石板窗，全按 `assets/ui/stats_strip/layout.json` 的 `bag_window`（窗左上起的设计像素）摆：
## 标题行不写字、整行是拖动把手，右上一枚圆钮收起；标题行下一条分隔线（左右各缩 `gap`）；
## 皮带外框（九宫格）里 72 一格的棋盘，道具图取 @2x 缩到 72；棋盘下居中一条数值栏（[StatsStrip]）。
## 包把棋盘撑大时窗跟着长（左、右、下边距不变）。
class_name BagWindow
extends FloatingWindow

const InventoryPanelScript := preload("res://ui/game/inventory_panel.gd")
const ContainerScreenScript := preload("res://ui/game/container_screen.gd")
const ART_DIR := "res://assets/ui/stats_strip/"
const LAYOUT := ART_DIR + "layout.json"
## 收起钮用战利品屏那枚（56 的切图按 `minimize.scale` 画）
const MINIMIZE_DIR := "res://assets/ui/board/"
const MINIMIZE_ART := "btn_minimize"
const MINIMIZE_SIDE := 56.0
const DIVIDER_COLOR := Color("786e64")
const DIVIDER_W := 1.2
## 没有 `layout.json` 时的摆位（和精修稿同一份）
const DEFAULTS := {
	"cell": 72, "board": [8, 6], "window_size": [660, 620], "window_center": [800, 510], "gap": 26, "header_h": 52,
	"board_cells_topleft_rel_window": [42, 82],
	"board_frame": {"file": "frame_player_72.png", "margin": 54, "cells_offset": 24},
	"minimize": {"scale": 0.72, "topleft_rel_window": [594, 13], "tooltip": "收起（B）"},
}
const DESIGN := Vector2(1600, 1000)
## 218 补充一（217 批三）：背包窗教程能指的地方（[method control_rect]）
const COACH_TARGETS: Array[StringName] = [&"board", &"strip_stamina", &"strip_dps", &"strip_load"]

## 窗里那块背包面板
var panel: InventoryPanelScript = null
var frame: NinePatchRect = null
## 218 补充一：开着的背包窗教程（没开 null）
var coach: CoachOverlay = null
var _canvas: Control
var _font: Font = null
var _spec: Dictionary = {}


## 搭好整块窗并返回里面的面板。[param drag] 同 [method InventoryPanelScript.setup]；[param hint_sink] 是面板回话的去处
func setup_bag(run: RunState, font: Font, on_close: Callable, drag: DragLayer = null, hint_sink: Callable = Callable()) -> InventoryPanelScript:
	key = "bag"
	_font = font
	_spec = spec()
	UiTheme.panel(self, 0, UiTheme.PANEL_WINDOW)     # 内边距 0：子节点按窗左上的设计像素摆
	mouse_filter = Control.MOUSE_FILTER_STOP
	center_shift = _vec(_spec["window_center"]) - DESIGN * 0.5

	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_divider)
	add_child(_canvas)
	var grip := Control.new()     # 标题行空着，整行都是把手
	grip.name = "Grip"
	_grip(grip)
	_canvas.add_child(grip)

	frame = NinePatchRect.new()
	frame.name = "Frame_player"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs: Dictionary = _spec["board_frame"]
	frame.texture = EventImage.load_texture(ART_DIR + String(fs.get("file", "frame_player_72.png")))
	var m := int(fs.get("margin", 54))
	frame.patch_margin_left = m
	frame.patch_margin_top = m
	frame.patch_margin_right = m
	frame.patch_margin_bottom = m
	frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_canvas.add_child(frame)

	panel = InventoryPanelScript.new()
	panel.cell_px = float(_spec["cell"])
	panel.hint_sink = hint_sink
	panel.setup(run, font, drag)
	panel.board_view.seams = ContainerScreenScript.board_layout().get("cell_seams", {})
	_canvas.add_child(panel)

	var ms: Dictionary = _spec["minimize"]
	var side := MINIMIZE_SIDE * float(ms.get("scale", 0.72))
	var b := IconButton.make_art(MINIMIZE_DIR, MINIMIZE_ART, "－", String(ms.get("tooltip", "收起（B）")), on_close)
	b.custom_minimum_size = Vector2(side, side)
	b.size = b.custom_minimum_size
	close_button = b
	_canvas.add_child(b)

	panel.board_view.resized.connect(_layout)
	resized.connect(_clamp)
	_layout()
	return panel


## 218 补充一：这一章写了背包窗教程（章节 `coaches` 的 `bag`）、这个存档还没看过就放 —— 窗摆稳了再放（等一帧），铺满 [param host]（压暗那一层）
func maybe_coach(flow: GameFlow, host: Control) -> void:
	if not CoachOverlay.due(flow, coach_id(flow)) or not is_inside_tree():
		return
	get_tree().process_frame.connect(show_coach.bind(flow, host), CONNECT_ONE_SHOT)     # 窗关了连接跟着断


## 放背包窗教程（调试 / 测试也直接叫）。没有步骤、已经开着返回 false
func show_coach(flow: GameFlow, host: Control) -> bool:
	if coach != null or not is_inside_tree() or not is_instance_valid(host):
		return false
	coach = CoachOverlay.run_on(host, coach_id(flow), flow, _font, control_rect)
	if coach == null:
		return false
	coach.finished.connect(func(): coach = null)
	return true


static func coach_id(flow: GameFlow) -> StringName:
	return flow.run.chapter.coach_for(&"bag") if flow != null and flow.run != null and flow.run.chapter != null else &""


## 218 补充一：教程目标的全局包围盒（[constant COACH_TARGETS]）；没有 / 不在屏上 = 空矩形
func control_rect(id: StringName) -> Rect2:
	if panel == null or not is_inside_tree():
		return Rect2()
	if id == &"board":
		return panel.board_view.get_global_rect() if panel.board_view.is_visible_in_tree() else Rect2()
	var kind := StringName(String(id).trim_prefix("strip_"))
	var strip: StatsStrip = panel.strip
	if not COACH_TARGETS.has(id) or strip == null or not strip.is_visible_in_tree() or not strip.shown().has(kind):
		return Rect2()
	return strip.get_global_transform() * strip.tag_rect(kind)


## 精修稿的 `bag_window`（缺的键按 [constant DEFAULTS]）
static func spec() -> Dictionary:
	var out := DEFAULTS.duplicate(true)
	if FileAccess.file_exists(LAYOUT):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
		if parsed is Dictionary:
			out.merge((parsed as Dictionary).get("bag_window", {}), true)
	return out


## 窗多大：精修稿是 8×6 棋盘的尺寸，棋盘大了多出的格子数 × 一格
func window_size() -> Vector2:
	var cell := float(_spec["cell"])
	var drawn: Vector2 = _vec(_spec["board"]) * cell
	var cells := Vector2(panel.board_view.inventory.size) * cell if panel != null else drawn
	return _vec(_spec["window_size"]) + (cells - drawn)


## 棋盘格子左上（窗里的设计像素）
func board_cells_at() -> Vector2:
	return _vec(_spec["board_cells_topleft_rel_window"])


func _layout() -> void:
	if panel == null:
		return
	var want := window_size()
	_canvas.custom_minimum_size = want
	_header.position = Vector2.ZERO
	_header.size = Vector2(want.x, float(_spec["header_h"]))
	var cells := board_cells_at()
	var cells_size := Vector2(panel.board_view.inventory.size) * float(_spec["cell"])
	var off := float((_spec["board_frame"] as Dictionary).get("cells_offset", 24))
	frame.position = cells - Vector2(off, off)
	frame.size = cells_size + Vector2(off, off) * 2.0
	panel.position = cells     # 棋盘在面板左上
	var ms: Dictionary = _spec["minimize"]
	close_button.position = _vec(ms.get("topleft_rel_window", [594, 13])) + Vector2(want.x - float((_spec["window_size"] as Array)[0]), 0.0)
	_canvas.queue_redraw()
	reset_size()


## 标题行下那条线：y = 窗上沿 + header_h，左右各缩 gap
func _draw_divider() -> void:
	var y := float(_spec["header_h"])
	var gap := float(_spec["gap"])
	_canvas.draw_line(Vector2(gap, y), Vector2(_canvas.size.x - gap, y), DIVIDER_COLOR, DIVIDER_W)


static func _vec(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and (a as Array).size() >= 2 else Vector2.ZERO
