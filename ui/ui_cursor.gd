## 光标（157）：美术给的四张光标图（铠甲手套，热点都在指尖 (2, 2)），三套材质放在 [member UiTheme.asset_root] 下的
## `cursors/<材质>/cursor_<名>.png`，设置里选哪套（[member GameSettings.cursor_skin]，默认秘银）。
## 游戏启动时（[method GameDirector._ready]）装上，设置里换了材质再装一次；哪张没图就那一种用系统光标。
##
## 拖着道具时 [DragLayer] 按「这里能不能放」切可放 / 不可放，松手还原 —— 这一条没图也有（系统的那两种光标）。
## 浮窗标题栏的「移动」光标（[FloatingWindow]）不归这里。
class_name UiCursor
extends RefCounted

const HOTSPOT := Vector2(2, 2)
## 三套材质：id → 设置屏上的名字。第一个是默认
const SKINS := {"mithril": {"zh": "秘银", "en": "Mithril"}, "iron": {"zh": "铁", "en": "Iron"}, "leather": {"zh": "皮革", "en": "Leather"}}
const DEFAULT_SKIN := "mithril"
## 图名 → 光标形状
const SHAPES := {
	"arrow": Input.CURSOR_ARROW,
	"drag": Input.CURSOR_DRAG,
	"can_drop": Input.CURSOR_CAN_DROP,
	"forbidden": Input.CURSOR_FORBIDDEN,
}

## 现在的默认形状（拖拽层切的那个；测试看 —— 无头跑时系统那头读不回来）
static var shape: int = Input.CURSOR_ARROW


## 按材质换上那一套（认不出的材质按默认）；没图的那几种还原成系统光标。返回换了几种
static func apply(skin: String = DEFAULT_SKIN) -> int:
	var dir := "cursors/%s/" % (skin if SKINS.has(skin) else DEFAULT_SKIN)
	var n := 0
	for name in SHAPES:
		var tex := UiTheme.art(dir + "cursor_" + String(name))
		Input.set_custom_mouse_cursor(tex, SHAPES[name], HOTSPOT)     # null = 还原成系统的
		if tex != null:
			n += 1
	return n


## 拖拽层用：拿起来（[param dragging] 真、还没对准哪儿）是「拖动」，对准了按 [param ok] 是「可放 / 不可放」；放下还原成箭头
static func set_drag(dragging: bool, ok: Variant = null) -> void:
	var want: int = Input.CURSOR_ARROW
	if dragging:
		want = Input.CURSOR_DRAG if ok == null else (Input.CURSOR_CAN_DROP if bool(ok) else Input.CURSOR_FORBIDDEN)
	if want == shape:
		return
	shape = want
	Input.set_default_cursor_shape(want)
