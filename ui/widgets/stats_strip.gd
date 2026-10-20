## 216（作者 2026-10-20 选定丁 火漆签）：背包窗与战利品 / 搜索屏右棋盘下面那条数值栏 —— 三张羊皮纸签，从左到右
## 耐力 / DPS / 负重；每张 = 签底 + 大字 + 小字 + 左头一枚火漆。这一章不算负重就只排两张，仍居中。
##
## 数据一个入口 [method refresh]（和战前屏同一套算法：`StaminaEstimate.of`、`rough_dps`、`encumbrance_*`）；纯读数，点了没动作。
## 三张签各自停上去开悬浮窗（[member tip]）。
##
## 画法读 `assets/ui/stats_strip/`（`tag` 签底、`seal_<stamina|dps|load>` 火漆、`layout.json` 尺寸与字位，UI替换美术 出）；
## 没图时画浅纸圆角 + 左头实心圆 + 字，尺寸照同一份默认 —— 精修图到了只换资源。浅底墨字（tone light）
class_name StatsStrip
extends Control

const STAMINA := &"stamina"
const DPS := &"dps"
const LOAD := &"load"
const ORDER: Array[StringName] = [STAMINA, DPS, LOAD]
## 切图目录（[method UiTheme.art_cached] 的名字前缀）与排版文件
const ART := "stats_strip/"
const LAYOUT := ART + "layout"
## 没有 `layout.json` 时的排版（设计像素，和精修稿同一份）
const DEFAULTS := {
	"strip": {"width": 480, "height": 58, "tag_top_in_strip": 6, "tag_w": 152, "tag_gap": 12},
	"text": {"main": {"pos_in_tag": [50, 23], "size": 19}, "sub": {"pos_in_tag": [50, 38], "size": 12}},
	"pieces": {"tag": {"origin_in_tag": [16, -6]}, "seal": {"center_in_tag": [20, 23], "size": [56, 56]}},
}
## 签高（没图时的纸）与火漆没图时的颜色（耐力橙、伤害红、负重铁灰）
const TAG_H := 46.0
const SEAL_COLORS := {STAMINA: Color("c8742a"), DPS: Color("a8322a"), LOAD: Color("5d6168")}
## 切图文件里负重那枚叫 load、DPS 那枚叫 dps
const SEAL_ART := {STAMINA: "seal_stamina", DPS: "seal_dps", LOAD: "seal_load"}

## 悬浮窗（宿主给；没有就不开）
var tip: HoverTip = null
## 每张签：{"main", "sub", "main_color", "sub_color", "sub_bold", "tip"}
var _blocks: Dictionary = {}
var _shown: Array[StringName] = []
var _tags: Dictionary = {}
var _layout: Dictionary = {}
var _width := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta(&"tone", UiTheme.TONE_LIGHT)
	_layout = _read_layout()
	_width = float(_strip().get("width", 480))
	for kind in ORDER:
		_blocks[kind] = {"main": "", "sub": "", "main_color": UiTheme.INK, "sub_color": UiTheme.INK_SOFT, "sub_bold": false, "tip": ""}
		var tag := Control.new()
		tag.name = String(kind)
		tag.mouse_filter = Control.MOUSE_FILTER_STOP
		tag.draw.connect(_draw_tag.bind(tag, kind))
		tag.mouse_entered.connect(_hover.bind(tag, kind))
		tag.mouse_exited.connect(func():
			if tip != null:
				tip.release())
		add_child(tag)
		_tags[kind] = tag
	_shown.assign(ORDER)
	_relayout()


## 跟棋盘一样宽（三张签在这宽度里居中；棋盘窄于签就按签宽）
func set_width(px: float) -> void:
	_width = maxf(px, 0.0)
	_relayout()


## 重算三张签的字。[param run] 为 null 时负重那张不显示
func refresh(spec: CombatantSpec, run: RunState) -> void:
	var e := StaminaEstimate.of(spec)
	var rating := String(e["rating"])
	_blocks[STAMINA] = {"main": rating, "sub": "耗 %.1f · 回 %.1f" % [e["cost"], e["regen"]],
		"main_color": _color("stamina", "main_color", rating, _rating_color(rating)), "sub_color": UiTheme.INK_SOFT, "sub_bold": false,
		"tip": StaminaEstimate.describe(spec)}
	var dps := spec.rough_dps()
	_blocks[DPS] = {"main": "%.1f" % dps, "sub": "DPS", "main_color": UiTheme.INK, "sub_color": UiTheme.INK_SOFT, "sub_bold": false,
		"tip": _dps_tip(spec, run)}
	var line := run.encumbrance_line() if run != null else ""
	_shown.assign(ORDER if line != "" else [STAMINA, DPS])
	if line != "":
		var lv := run.encumbrance_level()
		var level_name := run.encumbrance.name_of(lv)
		_blocks[LOAD] = {"main": "%d / %d" % [run.carry_weight(), run.carry_capacity()], "sub": level_name,
			"main_color": UiTheme.INK, "sub_color": _color("load", "sub_color", level_name, _level_color(lv)), "sub_bold": lv > 0,
			"tip": line + ("\n" + run.encumbrance.effect_text(lv) if lv > 0 else "")}
	_relayout()
	for kind in ORDER:
		(_tags[kind] as Control).queue_redraw()


## 测试看：现在显示的几张（按顺序）与某张的大字 / 小字
func shown() -> Array[StringName]:
	return _shown.duplicate()


func texts(kind: StringName) -> Array[String]:
	var b: Dictionary = _blocks[kind]
	return [String(b["main"]), String(b["sub"])] as Array[String]


func tip_text(kind: StringName) -> String:
	return String((_blocks[kind] as Dictionary)["tip"])


func tag_rect(kind: StringName) -> Rect2:
	var t := _tags[kind] as Control
	return Rect2(t.position, t.size)


func strip_height() -> float:
	return float(_strip().get("height", 58))


func _relayout() -> void:
	var s := _strip()
	var w := float(s.get("tag_w", 152))
	var gap := float(s.get("tag_gap", 12))
	var top := float(s.get("tag_top_in_strip", 6))
	var total := w * _shown.size() + gap * maxi(0, _shown.size() - 1)
	var span := maxf(_width, total)     # 签宽固定（图不拉伸）：棋盘比三张签窄时整条撑到签那么宽
	var x := floorf((span - total) * 0.5)
	for kind in ORDER:
		var tag := _tags[kind] as Control
		tag.visible = _shown.has(kind)
		if not tag.visible:
			continue
		tag.position = Vector2(x, top)
		tag.size = Vector2(w, TAG_H)
		x += w + gap
	custom_minimum_size = Vector2(span, strip_height())
	size = custom_minimum_size


func _draw_tag(tag: Control, kind: StringName) -> void:
	var b: Dictionary = _blocks[kind]
	var pieces: Dictionary = _layout.get("pieces", {})
	var bg := UiTheme.art_cached(ART + "tag")
	if bg != null:
		tag.draw_texture(bg, _vec((pieces.get("tag", {}) as Dictionary).get("origin_in_tag", [16, -6])))
	else:
		var paper := StyleBoxFlat.new()
		paper.bg_color = UiTheme.PAPER
		paper.border_color = Color(UiTheme.INK_SOFT, 0.55)
		paper.set_border_width_all(1)
		paper.set_corner_radius_all(6)
		tag.draw_style_box(paper, Rect2(Vector2(16, 0), Vector2(tag.size.x - 16, tag.size.y)))
	var text: Dictionary = _layout.get("text", {})
	var main: Dictionary = text.get("main", {})
	var sub: Dictionary = text.get("sub", {})
	tag.draw_string(UiPalette.cjk_font_bold(), _vec(main.get("pos_in_tag", [50, 23])), String(b["main"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(main.get("size", 19)), b["main_color"])
	tag.draw_string(UiPalette.cjk_font_bold() if bool(b["sub_bold"]) else UiPalette.cjk_font(), _vec(sub.get("pos_in_tag", [50, 38])), String(b["sub"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(sub.get("size", 12)), b["sub_color"])
	var seal_piece: Dictionary = pieces.get(SEAL_ART[kind], pieces.get("seal", {}))
	var center := _vec(seal_piece.get("center_in_tag", [20, 23]))
	var seal := UiTheme.art_cached(ART + String(SEAL_ART[kind]))
	if seal != null:
		tag.draw_texture(seal, (center - seal.get_size() * 0.5).floor())
	else:
		tag.draw_circle(center, 15.0, SEAL_COLORS[kind])
		tag.draw_arc(center, 15.0, 0.0, TAU, 32, Color(SEAL_COLORS[kind]).darkened(0.35), 2.0, true)


func _hover(tag: Control, kind: StringName) -> void:
	if tip != null and tip_text(kind) != "":
		tip.show_text(tip_text(kind), tag.global_position + Vector2(0, tag.size.y))


## 出手的几件各自约多少 DPS（3.1 待定：列）
func _dps_tip(spec: CombatantSpec, run: RunState) -> String:
	var lines: Array[String] = ["估算总 DPS %.1f（和出战前同一个数）" % spec.rough_dps()]
	var names := CombatantSpec.item_names(spec, run.items) if run != null else {}
	for it in spec.active_items():
		var d := spec.estimated_dps_of(it)
		if d > 0.0:
			lines.append("%s　%.1f" % [names.get(it.source_uid, String(it.def_id)), d])
	return "\n".join(lines)


## 精修稿 json 里给了这档的颜色就用它，没给按调色板压成墨上看得清的版本
func _color(block: String, key: String, value: String, fallback: Color) -> Color:
	var v = ((_layout.get("text", {}) as Dictionary).get(block, {}) as Dictionary).get(key, null)
	if v is Dictionary and (v as Dictionary).has(value):
		return Color(String(v[value]))
	return fallback


static func _rating_color(rating: String) -> Color:
	match rating:
		"低":
			return UiTheme.ink_color(UiPalette.HEAL)
		"高":
			return UiTheme.ink_color(UiPalette.STAMINA)
		"极高":
			return UiTheme.ink_color(UiPalette.HP)
	return UiTheme.INK


static func _level_color(level: int) -> Color:
	if level >= 2:
		return UiTheme.ink_color(UiPalette.HP)
	return UiTheme.ink_color(UiPalette.STAMINA) if level == 1 else UiTheme.INK_SOFT


func _strip() -> Dictionary:
	return _layout.get("strip", {})


static func _read_layout() -> Dictionary:
	var d := UiTheme.art_meta(LAYOUT)
	return d if not d.is_empty() else DEFAULTS


static func _vec(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and (a as Array).size() >= 2 else Vector2.ZERO
