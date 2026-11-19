## 150：信仰 + 信力 + 阶（087 / 082）；停上去开悬浮窗（具体效果、信力怎么涨），用所在屏的那个悬浮窗。
## 166（作者定）：有信仰时画这个信仰的徽记（`assets/ui/faith/<id>.png`，32 px）+ 阶与信力的小字；**没信仰时留一个空槽**（固定宽、不写字）。
## 缺图时退回原来那行字（「信仰：暴力之神　…」）
## 信仰重构 A：三态 —— 不奉神（空槽）/ 联系正常（徽记 + 阶 + 信力）/ 联系中断（选的那位神的徽记压暗 + 「联系中断」，悬浮窗写原因）
extends HudWidget

const ICON := 32.0
const ART_DIR := "res://assets/ui/faith/"

var icon: HudIcon


func _init() -> void:
	super()
	icon = HudIcon.make(ICON)
	_prepend_icon(icon)


func title() -> String:
	return "信仰"


func watch() -> Array[Signal]:
	var out: Array[Signal] = [run.faith_changed]
	if run.faith_power != null:
		out.append(run.faith_power.changed)
	return out


## 选了神但联系中断
func _broken() -> bool:
	return run != null and run.selected_faith != &"" and run.active_faith_id() == &""


## 这个信仰的徽记；没有图 null
static func art_of(faith_id: StringName) -> Texture2D:
	return HudIcon.load_art(ART_DIR + String(faith_id) + ".png") if faith_id != &"" else null


func text_of() -> String:
	if _broken():
		return UiText.t("faith.broken")
	var id_ := run.active_faith_id()
	if id_ == &"":
		return ""     # 没信仰：空槽
	var line := run.faith_power.line() if run.faith_power != null else ""
	if art_of(id_) == null:
		return run.faith_line() + (UiText.t("tip.gap") + line if line != "" else "")
	var def := run.active_faith()
	if def == null or run.faith_power == null:
		return ""
	return text_at(run.faith_power.points_of(id_))


## 231 补充二：信力滚数（有徽记那种写法才滚）
func roll_value() -> int:
	var id_ := run.active_faith_id()
	if id_ == &"" or art_of(id_) == null or run.active_faith() == null or run.faith_power == null:
		return -1
	return run.faith_power.points_of(id_)


func text_at(p: int) -> String:
	var def := run.active_faith()
	if def == null:
		return text_of()
	var next := def.next_threshold(p)
	return UiText.t("hud.faith_level") % [def.tier_of(p), p, (" / %d" % next) if next >= 0 else ""]


func _paint() -> void:
	icon.texture = art_of(run.selected_faith) if run != null else null
	icon.visible = icon.texture != null or run == null or run.selected_faith == &""     # 缺图退回文字时不占那一格
	icon.modulate = Color(1, 1, 1, 0.4) if _broken() else Color.WHITE
	_sync_empty()


## 没信仰：位置留着，底也不画（真的空着；摆读数时照常画出来好拖）
func _sync_empty() -> void:
	self_modulate.a = 0.0 if not editing and run != null and run.selected_faith == &"" else 1.0


## 没信仰也占着位置（一个空槽），不藏
func _sync_visible() -> void:
	visible = editing or (shown and run != null)


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_filter = _idle_mouse_filter()
	mouse_entered.connect(func():
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		if tip != null and run != null and not editing:
			tip.show_faith(FaithTooltip.describe_full(run.selected_faith_def(), run.faith_power, run.board, run.items, run.faith_connection()), global_position + Vector2(0, size.y)))     # 188
	mouse_exited.connect(func():
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		if tip != null:
			tip.release())     # 作者 2026-10-17：钉住了就留着
