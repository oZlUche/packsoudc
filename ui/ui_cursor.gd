## 光标（157）：美术给的四张光标图（铠甲手套，热点都在指尖 (2, 2)），三套材质放在 [member UiTheme.asset_root] 下的
## `cursors/<材质>/cursor_<名>.png`，设置里选哪套（[member GameSettings.cursor_skin]，默认秘银）。
## 游戏启动时（[method GameDirector._ready]）装上，设置里换了材质再装一次；哪张没图就那一种用系统光标。
##
## 拖着道具时 [DragLayer] 按「这里能不能放」切可放 / 不可放，松手还原 —— 这一条没图也有（系统的那两种光标）。
## 浮窗标题栏的「移动」光标（[FloatingWindow]）不归这里。
##
## 271（作者 2026-11-03 11:10「鼠标按下时手指会下压」）：按钮上的小手也是同一只手套（`pointing_hand` 用 arrow 图）；
## 鼠标任一键按下（[method press]，[GameDirector] 接）时箭头 / 小手换 `cursor_arrow_pressed`（热点不动），松开、失焦、鼠标离窗还原；拖拽三种不换。
class_name UiCursor
extends RefCounted

const HOTSPOT := Vector2(2, 2)
## 三套材质：id → 设置屏上的名字。第一个是默认
const SKINS := {"mithril": {"zh": "秘银", "en": "Mithril"}, "iron": {"zh": "铁", "en": "Iron"}, "leather": {"zh": "皮革", "en": "Leather"}}
const DEFAULT_SKIN := "mithril"
## 图名 → 光标形状
const SHAPES := {
	"arrow": Input.CURSOR_ARROW,
	"pointing_hand": Input.CURSOR_POINTING_HAND,
	"drag": Input.CURSOR_DRAG,
	"can_drop": Input.CURSOR_CAN_DROP,
	"forbidden": Input.CURSOR_FORBIDDEN,
}

## 图名不同于形状名的：按钮上的小手用箭头那张
const FILE_OF := {"pointing_hand": "arrow"}
## 按下时换图的形状（拖拽三种本来就是按着的图）
const PRESS_SHAPES := ["arrow", "pointing_hand"]

## 鼠标键按着没有（测试看）
static var pressed := false
## 这套材质的箭头 / 按下帧（按下、松开时来回换；缺图 null）
static var _arrow: Texture2D = null
static var _arrow_pressed: Texture2D = null

## 现在的默认形状（拖拽层切的那个；测试看 —— 无头跑时系统那头读不回来）
static var shape: int = Input.CURSOR_ARROW
## 314：手上拿着东西（拖拽层设）。悬浮窗看它，拿着东西停在道具上不弹道具窗
static var holding := false


## 按材质换上那一套（认不出的材质按默认）；没图的那几种还原成系统光标。返回换了几种
static func apply(skin: String = DEFAULT_SKIN) -> int:
	var dir := "cursors/%s/" % (skin if SKINS.has(skin) else DEFAULT_SKIN)
	var n := 0
	pressed = false
	_arrow = UiTheme.art(dir + "cursor_arrow")
	_arrow_pressed = UiTheme.art(dir + "cursor_arrow_pressed")
	for name in SHAPES:
		var tex := UiTheme.art(dir + "cursor_" + String(FILE_OF.get(name, name)))
		Input.set_custom_mouse_cursor(tex, SHAPES[name], HOTSPOT)     # null = 还原成系统的
		if tex != null:
			n += 1
	return n


## 271：鼠标键按下 / 松开（失焦、离窗也当松开）—— 箭头和按钮上的小手换按下帧 / 换回来；没有按下帧只记状态
static func press(down: bool) -> void:
	if down == pressed:
		return
	pressed = down
	if _arrow == null or _arrow_pressed == null:
		return
	var tex := _arrow_pressed if down else _arrow
	for name in PRESS_SHAPES:
		Input.set_custom_mouse_cursor(tex, SHAPES[name], HOTSPOT)


## 拖拽层用：拿起来（[param dragging] 真、还没对准哪儿）是「拖动」，对准了按 [param ok] 是「可放 / 不可放」；放下还原成箭头
static func set_drag(dragging: bool, ok: Variant = null) -> void:
	holding = dragging
	var want: int = Input.CURSOR_ARROW
	if dragging:
		want = Input.CURSOR_DRAG if ok == null else (Input.CURSOR_CAN_DROP if bool(ok) else Input.CURSOR_FORBIDDEN)
	if want == shape:
		return
	shape = want
	Input.set_default_cursor_shape(want)
