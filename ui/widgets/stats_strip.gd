## 背包与搜索共用的棋盘读数。负重主签按本章规则计算，战前四签使用对称顺序。
class_name StatsStrip
extends Control

const HP := &"hp"
const VIGOR := &"vigor"
const STAMINA := &"stamina"
const DPS := &"dps"
const LOAD := &"load"
const SPECIAL := &"special"
const ORDER: Array[StringName] = [LOAD, STAMINA, DPS]
## 战前准备屏的两排（battle_stats v2 `prebattle_row`）
const ORDER_PLAYER: Array[StringName] = [HP, VIGOR, STAMINA, DPS]
const ORDER_ENEMY: Array[StringName] = [HP, VIGOR, STAMINA, DPS]
const ALL: Array[StringName] = [HP, VIGOR, STAMINA, DPS, LOAD, SPECIAL]
## 切图目录（[method UiTheme.art_cached] 的名字前缀）与排版文件
const ART := "stats_strip/"
const LAYOUT := ART + "layout"
const BATTLE_LAYOUT := ART + "battle_layout"
const BRONZE := "bronze/"
## 没有 `layout.json` 时的排版（设计像素，和精修稿同一份）
const DEFAULTS := {
	"strip": {"width": 480, "height": 58, "tag_top_in_strip": 6, "tag_w": 152, "tag_gap": 12},
	"text": {"main": {"pos_in_tag": [50, 23], "size": 19}, "sub": {"pos_in_tag": [50, 38], "size": 12}},
	"pieces": {"tag": {"origin_in_tag": [16, -6]}, "seal": {"center_in_tag": [20, 23], "size": [56, 56]}},
}
## 签高
const TAG_H := 46.0
const LOAD_WIDTH := 212.0
const COST_WIDTH := 136.0
const DPS_WIDTH := 108.0
## 签里的字离签右沿至少这么远；放不下就收字号，最小到这么大
const TEXT_RIGHT_PAD := 8.0
const MIN_TEXT_SIZE := 10     # 10-27 正文换思源宋体 Medium 后字面变宽：英文「Stamina」11 号多出 1 px，再让一号
## 切图文件里负重那枚叫 load、DPS 那枚叫 dps
const SEAL_ART := {HP: "seal_hp", VIGOR: "seal_vigor", STAMINA: "seal_stamina", DPS: "seal_dps", LOAD: "seal_load", SPECIAL: "seal_special"}
## 221 F1：耐力档（[StaminaEstimate] 给的中文档名，配色按它比对）→ 给人看的字的 [UiText] 键
const RATING_KEYS := {"低": "strip.rating_low", "中": "strip.rating_mid", "高": "strip.rating_high", "极高": "strip.rating_max"}
## 嵌槽签：深槽里看得见的那段从切图上沿往下 8；三段切（窄签）左 20 / 右 12；签图左头藏在火漆下面
const INLAY_TOP := -8.0
const INLAY_LEFT := 20.0
const INLAY_RIGHT := 12.0
const INLAY_TAG_X := 16.0

## 悬浮窗（宿主给；没有就不开）
var tip: HoverTip = null
## 每张签：{"main", "sub", "main_color", "sub_color", "sub_bold", "tip"}
var _blocks: Dictionary = {}
## 这一条有哪几张（按顺序；默认 [constant ORDER]）
var _kinds: Array[StringName] = []
var _shown: Array[StringName] = []
var _tags: Dictionary = {}
var _layout: Dictionary = {}
var _width := 0.0
var _preview_weight := -1
var _baseline_weight := -1
var _focus_ring := UiTheme.focus_ring()
## "" = 背包的皮签和纸签；"wide" = 搜索的宽铜嵌槽；"narrow" = 战前窄铜嵌槽。
var _inlay := ""
var _bronze: Dictionary = {}
var _row: Dictionary = {}
## 上一次 [method refresh] 的参数（换嵌槽后按新字色重算）
var _spec: CombatantSpec = null
var _run: RunState = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta(&"tone", UiTheme.TONE_LIGHT)
	_layout = _read_layout()
	_width = float(_strip().get("width", 480))
	for kind in ALL:
		_blocks[kind] = {"main": "", "sub": "", "main_color": UiTheme.INK, "sub_color": UiTheme.INK_SOFT, "sub_bold": false, "tip": ""}
		var tag := Control.new()
		tag.name = String(kind)
		tag.mouse_filter = Control.MOUSE_FILTER_STOP
		if kind == LOAD:
			tag.focus_mode = Control.FOCUS_ALL
			tag.focus_entered.connect(_hover.bind(tag, kind))
			tag.focus_entered.connect(tag.queue_redraw)
			tag.focus_exited.connect(tag.queue_redraw)
			tag.focus_exited.connect(func():
				if tip != null:
					tip.release())
		tag.draw.connect(_draw_tag.bind(tag, kind))
		tag.mouse_entered.connect(_hover.bind(tag, kind))
		tag.mouse_exited.connect(func():
			if tip != null and not tag.has_focus():
				tip.release())
		add_child(tag)
		_tags[kind] = tag
	_kinds.assign(ORDER)
	_shown.assign(ORDER)
	_relayout()


## 铜面板使用嵌槽和浅字。战前四签按战斗版式排，其余跟随玩家棋盘宽度。
func use_inlay(narrow: bool, kinds: Array[StringName] = []) -> void:
	_inlay = "narrow" if narrow else "wide"
	_bronze = UiTheme.art_meta(BRONZE + "layout")
	_row = (UiTheme.art_meta(BATTLE_LAYOUT).get("prebattle_row", {}) as Dictionary)
	set_meta(&"tone", UiTheme.TONE_DARK)
	if not kinds.is_empty():
		_kinds.assign(kinds)
		_shown.assign(kinds)
	if _spec != null:
		refresh(_spec, _run)
	else:
		_relayout()


## 只摆这几张（羊皮纸签；作者 11-11 配装备页只要耐力那张）
func set_kinds(kinds: Array[StringName]) -> void:
	_kinds.assign(kinds)
	_shown.assign(kinds)
	_relayout()


## 跟棋盘一样宽（三张签在这宽度里居中；棋盘窄于签就按签宽）。窄嵌槽那排从左沿排起，不居中
func set_width(px: float) -> void:
	_width = maxf(px, 0.0)
	_relayout()


## 给定棋盘宽度，返回为整排预留的宽度。
func span_for(px: float) -> float:
	if _inlay == "narrow":
		var widths: Dictionary = _row.get("tag_w", {})
		var total := 0.0
		for kind in _shown:
			total += float(widths.get(String(kind), 88))
		return total + float(_row.get("gap", 6)) * maxi(0, _shown.size() - 1)
	var s := _strip()
	var n := _shown.size()
	return maxf(px, float(s.get("tag_w", 152)) * n + float(s.get("tag_gap", 12)) * maxi(0, n - 1))


## 从同一份战斗与章节数据重算。没有 run 的读数排只显示战斗属性。
func refresh(spec: CombatantSpec, run: RunState) -> void:
	_spec = spec
	_run = run
	var e := StaminaEstimate.of(spec)
	var rating := String(e["rating"])
	var soft := _sub_color()
	_blocks[STAMINA] = {"main": UiText.t(RATING_KEYS[rating]) if RATING_KEYS.has(rating) else rating, "sub": UiText.t("strip.stamina_sub") % [e["cost"], e["regen"]],
		"main_color": _rating_ink(rating), "sub_color": soft, "sub_bold": false,
		"tip": StaminaEstimate.describe(spec, CombatantSpec.item_names(spec, run.items) if run != null else {})}     # 289：两段来源用棋盘上的名字
	if _inlay == "narrow":
		_blocks[STAMINA]["main"] = "%.1f/s" % e["cost"]
		_blocks[STAMINA]["sub"] = UiText.t("strip.drain")
	elif _kinds.has(LOAD):
		_blocks[STAMINA]["main"] = UiText.t("strip.drain_rating") % _blocks[STAMINA]["main"]
	var dps := spec.rough_dps()
	_blocks[DPS] = {"main": "%.1f" % dps, "sub": UiText.t("strip.dps_est"), "main_color": _main_color(), "sub_color": soft, "sub_bold": false,
		"tip": _dps_tip(spec, run)}
	var hp := spec.max_hp_int()
	_blocks[HP] = {"main": str(hp), "sub": UiText.t("strip.hp"), "main_color": _main_color(), "sub_color": soft, "sub_bold": false,
		"tip": UiText.t("strip.hp_tip") % hp}
	var vigor := vigor_of(spec)
	_blocks[VIGOR] = {"main": str(vigor), "sub": UiText.t("strip.vigor"), "main_color": _main_color(), "sub_color": soft, "sub_bold": false,
		"tip": UiText.t("strip.vigor_tip") % vigor}
	var specials := specials_of(spec)
	_blocks[SPECIAL] = {"main": str(specials.size()) if not specials.is_empty() else UiText.t("strip.special_none"), "sub": UiText.t("strip.special"),
		"main_color": _main_color(), "sub_color": soft, "sub_bold": false,
		"tip": (UiText.t("strip.special") + "\n" + "\n".join(specials)) if not specials.is_empty() else UiText.t("strip.special_empty")}
	var shown_: Array[StringName] = []
	for k in _kinds:
		if k != LOAD or run != null:
			shown_.append(k)
	_shown = shown_
	if run != null:
		_blocks[LOAD] = _load_block(run)
	_relayout()
	for kind in ALL:
		(_tags[kind] as Control).queue_redraw()


## 耐力上限（开场那一池，和回放里耐力条的上限同一个数）
static func vigor_of(spec: CombatantSpec) -> int:
	return StatMath.to_int(CombatantRuntime.from_spec(spec, 0).stat(BattleStats.MAX_STAMINA)) if spec != null else 0


## 特殊能力（battle_stats v2）：免疫的状态各算一条（「免疫流血」），再加编译进来的常驻加成（[member CombatantSpec.passives]）；每条一行「名字：效果」
static func specials_of(spec: CombatantSpec) -> Array[String]:
	var out: Array[String] = []
	if spec == null:
		return out
	var lib := ContentLibrary.buffs()
	for id in spec.immune_buffs:
		var b: BuffDef = lib.get(id, null)
		out.append(UiText.t("strip.special_immune") % (Names.of(b) if b != null and b.display_name != "" else String(id)))
	for p in spec.passives:
		var n := p as PassiveNote
		var line := n.name
		var detail := Glossary.mods_text(n.mods) if not n.mods.is_empty() else n.note
		if detail != "":
			line += UiText.t("strip.special_sep") + detail.replace("\n", UiText.t("strip.special_sep"))
		out.append(line)
	return out


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


## 嵌槽签（测试看）
func inlay() -> String:
	return _inlay


func load_tag() -> Control:
	return _tags[LOAD]


## 持物期间以拿起前的重量为准；外部容器移入或移出只在落点越档时预告。
func set_preview_weight(weight: int = -1, baseline: int = -1) -> void:
	if _preview_weight == weight and _baseline_weight == baseline:
		return
	_preview_weight = weight
	_baseline_weight = baseline
	if _run != null and _shown.has(LOAD):
		_blocks[LOAD] = _load_block(_run)
		load_tag().queue_redraw()
		if load_tag().has_focus():
			_hover(load_tag(), LOAD)


func _relayout() -> void:
	var s := _strip()
	var top := float(s.get("tag_top_in_strip", 6))
	if _inlay == "narrow":
		var widths: Dictionary = _row.get("tag_w", {})
		var gap_ := float(_row.get("gap", 6))
		var x_ := 0.0
		for kind in ALL:
			var tag := _tags[kind] as Control
			tag.visible = _shown.has(kind)
		for kind in _shown:
			var tag := _tags[kind] as Control
			var w_ := float(widths.get(String(kind), 88))
			tag.position = Vector2(x_, top)
			tag.size = Vector2(w_, float(_row.get("tag_h", TAG_H)))
			x_ += w_ + gap_
		custom_minimum_size = Vector2(maxf(0.0, x_ - gap_), strip_height())
		size = custom_minimum_size
		return
	var w := float(s.get("tag_w", 152))
	var gap := float(s.get("tag_gap", 12))
	var widths := {}
	if _shown == ORDER:
		var extra := clampf(_width - (LOAD_WIDTH + COST_WIDTH + DPS_WIDTH + 2 * gap), 0.0, 96.0)
		widths = {LOAD: LOAD_WIDTH + extra * 0.55, STAMINA: COST_WIDTH + extra * 0.30, DPS: DPS_WIDTH + extra * 0.15}
	var total := gap * maxi(0, _shown.size() - 1)
	for kind in _shown:
		total += float(widths.get(kind, w))
	var span := maxf(_width, total)     # 棋盘比签组窄时由宿主为整排预留位置
	var x := floorf((span - total) * 0.5)
	for kind in ALL:
		(_tags[kind] as Control).visible = _shown.has(kind)
	for kind in _shown:
		var tag := _tags[kind] as Control
		tag.position = Vector2(x, top)
		tag.size = Vector2(float(widths.get(kind, w)), TAG_H)
		x += tag.size.x + gap
	custom_minimum_size = Vector2(span, strip_height())
	size = custom_minimum_size


func _draw_tag(tag: Control, kind: StringName) -> void:
	var b: Dictionary = _blocks[kind]
	var pieces: Dictionary = _layout.get("pieces", {})
	# 字的位置与字号：窄嵌槽读这一行的版式（[member _row]），宽嵌槽与纸签读整套版式
	var narrow := _inlay == "narrow"
	var text: Dictionary = (_row if narrow else _layout).get("text", {})
	var main: Dictionary = text.get("main", {})
	var sub: Dictionary = text.get("sub", {})
	var main_pos := _vec(main.get("pos_in_tag", [36, 22] if narrow else [50, 23]))
	var sub_pos := _vec(sub.get("pos_in_tag", [36, 37] if narrow else [50, 38]))
	var main_size := UiTheme.sz(int(main.get("size", 17 if narrow else 19)))
	var sub_size := UiTheme.sz(int(sub.get("size", 11 if narrow else 12)))
	var seal_scale := 0.8 if narrow else 1.0
	var center := Vector2(16, 23) if narrow else Vector2(20, 23)
	if narrow:
		_draw_sliced(tag, UiTheme.art_cached(BRONZE + "tag_inlay"), Vector2(INLAY_TAG_X, INLAY_TOP))
	elif _inlay == "wide":
		_draw_sliced(tag, UiTheme.art_cached(BRONZE + "tag_inlay_wide"), Vector2(INLAY_TAG_X, INLAY_TOP))
	elif kind == LOAD:
		_draw_leather(tag)
	else:
		var bg := UiTheme.art_cached(ART + "tag")
		if bg != null:
			var offset := _vec((pieces.get("tag", {}) as Dictionary).get("origin_in_tag", [16, -6]))
			_draw_sliced(tag, bg, offset)
		var seal_piece: Dictionary = pieces.get(SEAL_ART[kind], pieces.get("seal", {}))
		center = _vec(seal_piece.get("center_in_tag", [20, 23]))
	if not narrow and _shown == ORDER:
		main_pos.x = 44.0
		sub_pos.x = main_pos.x
	var right_pad := 17.0 if kind == LOAD and _inlay == "" else TEXT_RIGHT_PAD
	var room := tag.size.x - main_pos.x - right_pad     # 复测 v3.79：「37 / 40」「Very high」比签宽时收字号，不顶签的右沿
	var sub_font := UiPalette.cjk_font_bold() if bool(b["sub_bold"]) else UiPalette.cjk_font()
	_draw_fit(tag, UiPalette.numeral_font() if kind in [HP, VIGOR, DPS] else UiPalette.cjk_font_bold(), main_pos, String(b["main"]), main_size, room, b["main_color"])
	_draw_fit(tag, sub_font, sub_pos, String(b["sub"]), sub_size, tag.size.x - sub_pos.x - right_pad, b["sub_color"])
	var seal := UiTheme.art_cached(ART + String(SEAL_ART[kind]))
	if seal != null:
		var side := seal.get_size() * seal_scale
		tag.draw_texture_rect(seal, Rect2((center - side * 0.5).floor(), side), false)
	if tag.has_focus():
		tag.draw_style_box(_focus_ring, Rect2(Vector2.ZERO, tag.size).grow(-1))


## 收到最小字号还放不下的（英文「Overloaded」之类），横向压扁到正好 [param room] 宽 —— 不伸出签的右沿（游戏测试 10-27）
static func squeeze(font: Font, text: String, p_size: int, room: float) -> float:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, p_size).x
	return 1.0 if w <= room or w <= 0.0 else room / w


func _draw_fit(tag: Control, font: Font, pos: Vector2, text: String, p_size: int, room: float, color: Color) -> void:
	var n := TextFit.size_for(font, text, p_size, room, MIN_TEXT_SIZE)
	var k := squeeze(font, text, n, room)
	if k < 1.0:
		tag.draw_set_transform(Vector2(pos.x * (1.0 - k), 0.0), 0.0, Vector2(k, 1.0))
	tag.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, n, color)
	if k < 1.0:
		tag.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 背包秤签：铜铆钉把皮革固定在火漆背后，双色缝边留在字行之外。
func _draw_leather(tag: Control) -> void:
	var w := tag.size.x
	var h := tag.size.y
	var outline := PackedVector2Array([
		Vector2(13, 2), Vector2(w - 9, 2), Vector2(w - 1, 10), Vector2(w - 1, h - 8),
		Vector2(w - 8, h - 2), Vector2(14, h - 2), Vector2(7, h - 9), Vector2(7, 10)
	])
	var colors := PackedColorArray([
		Color("#985631"), Color("#995834"), Color("#8d4c2b"), Color("#723d29"),
		Color("#623725"), Color("#71442c"), Color("#784327"), Color("#955430")
	])
	tag.draw_polygon(outline, colors)
	outline.append(outline[0])
	tag.draw_polyline(outline, Color("#593526"), 2.0, true)
	tag.draw_line(Vector2(18, 3), Vector2(w - 10, 3), Color("#d0925d"), 1.5, true)
	for y in [6.0, h - 6.0]:
		tag.draw_dashed_line(Vector2(24, y), Vector2(w - 11, y), Color("#dfad79"), 1.0, 4.0, true)
	var rivet := Vector2(w - 8, h * 0.5)
	tag.draw_circle(rivet, 2.8, Color("#583526"), true, -1.0, true)
	tag.draw_circle(rivet - Vector2(0, 0.6), 1.8, Color("#e1b779"), true, -1.0, true)


## 中段拉伸，两端的签角保持原宽。
func _draw_sliced(tag: Control, tex: Texture2D, at: Vector2) -> void:
	if tex == null:
		return
	var ts := tex.get_size()
	var w := maxf(tag.size.x - at.x, INLAY_LEFT + INLAY_RIGHT)
	tag.draw_texture_rect_region(tex, Rect2(at, Vector2(INLAY_LEFT, ts.y)), Rect2(0, 0, INLAY_LEFT, ts.y))
	tag.draw_texture_rect_region(tex, Rect2(at + Vector2(INLAY_LEFT, 0), Vector2(w - INLAY_LEFT - INLAY_RIGHT, ts.y)),
		Rect2(INLAY_LEFT, 0, ts.x - INLAY_LEFT - INLAY_RIGHT, ts.y))
	tag.draw_texture_rect_region(tex, Rect2(at + Vector2(w - INLAY_RIGHT, 0), Vector2(INLAY_RIGHT, ts.y)), Rect2(ts.x - INLAY_RIGHT, 0, INLAY_RIGHT, ts.y))


func _hover(tag: Control, kind: StringName) -> void:
	if tip != null and tip_text(kind) != "":
		tip.show_text(tip_text(kind), tag.global_position + Vector2(0, tag.size.y))


func _load_block(run: RunState) -> Dictionary:
	var weight := _baseline_weight if _baseline_weight >= 0 else run.carry_weight()
	var cap := run.carry_capacity()
	var main := "%s %d" % [UiText.t("strip.load"), weight]
	var rules := run.encumbrance
	var details := PackedStringArray([main])
	if cap > 0:
		details.append(UiText.t("strip.load_capacity") % cap)
	var sub := UiText.t("strip.load_not_counted")
	var color := _sub_color()
	var warning := false
	if rules == null or cap <= 0:
		details.append(UiText.t("strip.load_chapter_off") if rules == null else UiText.t("strip.load_character_off"))
	else:
		var level := rules.level_of(weight, cap)
		var name_ := rules.name_of(level)
		main += " · " + name_
		details[0] = main
		var next := rules.row(level + 1)
		if next != null:
			sub = UiText.t("strip.load_next") % [_threshold(cap, next), rules.name_of(level + 1)]
		else:
			sub = UiText.t("strip.load_last")
		for i in rules.levels.size():
			var start := _threshold(cap, rules.levels[i])
			var effect := rules.effect_text(i + 1)
			details.append("%d · %s%s" % [start, rules.name_of(i + 1), (" — " + effect) if effect != "" else ""])
		var projected := rules.level_of(_preview_weight, cap) if _preview_weight >= 0 else level
		warning = projected > 0
		color = _load_ink(rules.name_of(projected), projected)
		if projected != level:
			sub = "→ %d · %s" % [_preview_weight, rules.name_of(projected)]
			details.append(sub)
	var ink := _main_color()
	if _inlay == "":
		ink = Color("#fff5d9")
		color = Color("#ffe2a0") if warning else Color("#f5ddbc")
	return {"main": main, "sub": sub, "main_color": ink, "sub_color": color, "sub_bold": warning, "tip": "\n".join(details)}


## 规则使用严格“大于”；刚好等于分界值时仍在原档。
static func _threshold(cap: int, row: EncumbranceLevel) -> int:
	return floori(float(cap) * row.over) + 1


## 出手的几件各自约多少 DPS（3.1 待定：列）
func _dps_tip(spec: CombatantSpec, run: RunState) -> String:
	var lines: Array[String] = [UiText.t("strip.dps_total") % spec.rough_dps()]
	var names := CombatantSpec.item_names(spec, run.items) if run != null else {}
	for it in spec.active_items():
		var d := spec.estimated_dps_of(it)
		if d > 0.0:
			lines.append(UiText.t("strip.dps_row") % [names.get(it.source_uid, String(it.def_id)), d])
	return "\n".join(lines)


## 嵌槽签上的浅字（铜面板 `tags_on_bronze.text`）
func _bronze_text() -> Dictionary:
	return ((_bronze.get("tags_on_bronze", {}) as Dictionary).get("text", {}) as Dictionary)


func _main_color() -> Color:
	return Color(String(_bronze_text().get("main", "#f3e6c8"))) if _inlay != "" else UiTheme.INK


func _sub_color() -> Color:
	return Color(String(_bronze_text().get("sub", "#c8b890"))) if _inlay != "" else UiTheme.INK_SOFT


func _rating_ink(rating: String) -> Color:
	if _inlay != "":
		var m: Dictionary = _bronze_text().get("rating", {})
		return Color(String(m[rating])) if m.has(rating) else _main_color()
	return _color("stamina", "main_color", rating, _rating_color(rating))


func _load_ink(level_name: String, lv: int) -> Color:
	if _inlay != "":
		var m: Dictionary = _bronze_text().get("load", {})
		return Color(String(m[level_name])) if m.has(level_name) else _sub_color()
	return _color("load", "sub_color", level_name, _level_color(lv))


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
