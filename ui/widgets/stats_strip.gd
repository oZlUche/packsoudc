## 216（作者 2026-10-20 选定丁 火漆签）：背包窗与战利品 / 搜索屏右棋盘下面那条数值栏 —— 三张羊皮纸签，从左到右
## 耐力 / DPS / 负重；每张 = 签底 + 大字 + 小字 + 左头一枚火漆。三张总在（作者 2026-10-20 16:20：负重签任何章节都显示）。
##
## 数据一个入口 [method refresh]（和战前屏同一套算法：`StaminaEstimate.of`、`rough_dps`、`encumbrance_*`）；纯读数，点了没动作。
## 三张签各自停上去开悬浮窗（[member tip]）。
##
## 画法读 `assets/ui/stats_strip/`（`tag` 签底、`seal_<stamina|dps|load>` 火漆、`layout.json` 尺寸与字位，UI替换美术 出）；
## 没图时画浅纸圆角 + 左头实心圆 + 字，尺寸照同一份默认 —— 精修图到了只换资源。浅底墨字（tone light）
##
## 铜面板三屏（UI替换美术 bronze3的嵌槽签方案，作者 2026-10-21 16:21）：[method use_inlay] 换成凹进铜板的深槽签、浅字（tone dark）——
## 战利品 / 搜索屏是 152 宽的 `tag_inlay_wide`；战前准备屏是窄签 `tag_inlay`（三段切，按签宽拉），敌我两边各五张：
## 生命 / 耐力 / 耗气 / DPS + 敌人「特殊能力」或自己「负重」（battle_stats v2，作者 15:19–15:20）

class_name StatsStrip
extends Control

const HP := &"hp"
const VIGOR := &"vigor"
const STAMINA := &"stamina"
const DPS := &"dps"
const LOAD := &"load"
const SPECIAL := &"special"
const ORDER: Array[StringName] = [STAMINA, DPS, LOAD]
## 战前准备屏的两排（battle_stats v2 `prebattle_row`）
const ORDER_PLAYER: Array[StringName] = [HP, VIGOR, STAMINA, DPS, LOAD]
const ORDER_ENEMY: Array[StringName] = [HP, VIGOR, STAMINA, DPS, SPECIAL]
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
## 签高（没图时的纸）与火漆没图时的颜色（耐力橙、伤害红、负重铁灰）
const TAG_H := 46.0
const SEAL_COLORS := {HP: Color("b0303a"), VIGOR: Color("d49a2a"), STAMINA: Color("c8742a"), DPS: Color("a8322a"), LOAD: Color("5d6168"), SPECIAL: Color("5a3c8c")}
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
## "" = 羊皮纸签（216，背包窗）；"wide" = 铜面板宽嵌槽（战利品 / 搜索）；"narrow" = 铜面板窄嵌槽（战前准备）
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
		tag.draw.connect(_draw_tag.bind(tag, kind))
		tag.mouse_entered.connect(_hover.bind(tag, kind))
		tag.mouse_exited.connect(func():
			if tip != null:
				tip.release())
		add_child(tag)
		_tags[kind] = tag
	_kinds.assign(ORDER)
	_shown.assign(ORDER)
	_relayout()


## 铜面板的嵌槽签（[param narrow]：战前准备屏那排窄签，否则 152 宽）；换完浅字、tone dark。[param kinds] 给了就换这几张
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


## 跟棋盘一样宽（三张签在这宽度里居中；棋盘窄于签就按签宽）。窄嵌槽那排从左沿排起，不居中
func set_width(px: float) -> void:
	_width = maxf(px, 0.0)
	_relayout()


## 重算各张签的字。负重那张：算负重的章「当前 / 上限」+ 档名；不算负重的章有上限照样写「当前 / 上限」、小字空着，
## 没有上限（没角色、角色没配）只写当前重量。[param run] 为 null 时负重那张不显示
func refresh(spec: CombatantSpec, run: RunState) -> void:
	_spec = spec
	_run = run
	var e := StaminaEstimate.of(spec)
	var rating := String(e["rating"])
	var soft := _sub_color()
	_blocks[STAMINA] = {"main": UiText.t(RATING_KEYS[rating]) if RATING_KEYS.has(rating) else rating, "sub": UiText.t("strip.stamina_sub") % [e["cost"], e["regen"]],
		"main_color": _rating_ink(rating), "sub_color": soft, "sub_bold": false,
		"tip": StaminaEstimate.describe(spec)}
	var dps := spec.rough_dps()
	_blocks[DPS] = {"main": "%.1f" % dps, "sub": "DPS", "main_color": _main_color(), "sub_color": soft, "sub_bold": false,
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
	var shown: Array[StringName] = []
	for k in _kinds:
		if k != LOAD or run != null:
			shown.append(k)
	_shown = shown
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


func _relayout() -> void:
	var s := _strip()
	var top := float(s.get("tag_top_in_strip", 6))
	if _inlay == "narrow":
		var widths: Dictionary = _row.get("tag_w", {})
		var gap := float(_row.get("gap", 6))
		var x := 0.0
		for kind in ALL:
			var tag := _tags[kind] as Control
			tag.visible = _shown.has(kind)
		for kind in _shown:
			var tag := _tags[kind] as Control
			var w := float(widths.get(String(kind), 88))
			tag.position = Vector2(x, top)
			tag.size = Vector2(w, float(_row.get("tag_h", TAG_H)))
			x += w + gap
		custom_minimum_size = Vector2(maxf(0.0, x - gap), strip_height())
		size = custom_minimum_size
		return
	var w := float(s.get("tag_w", 152))
	var gap := float(s.get("tag_gap", 12))
	var total := w * _shown.size() + gap * maxi(0, _shown.size() - 1)
	var span := maxf(_width, total)     # 签宽固定（图不拉伸）：棋盘比三张签窄时整条撑到签那么宽
	var x := floorf((span - total) * 0.5)
	for kind in ALL:
		(_tags[kind] as Control).visible = false
	for kind in _shown:
		var tag := _tags[kind] as Control
		tag.visible = true
		tag.position = Vector2(x, top)
		tag.size = Vector2(w, TAG_H)
		x += w + gap
	custom_minimum_size = Vector2(span, strip_height())
	size = custom_minimum_size


func _draw_tag(tag: Control, kind: StringName) -> void:
	var b: Dictionary = _blocks[kind]
	var pieces: Dictionary = _layout.get("pieces", {})
	var main_pos := Vector2(50, 23)
	var sub_pos := Vector2(50, 38)
	var main_size := 19
	var sub_size := 12
	var seal_scale := 1.0
	var center := Vector2(20, 23)
	var text: Dictionary = _layout.get("text", {})
	if _inlay == "narrow":
		var rt: Dictionary = _row.get("text", {})
		main_pos = _vec((rt.get("main", {}) as Dictionary).get("pos_in_tag", [36, 22]))
		sub_pos = _vec((rt.get("sub", {}) as Dictionary).get("pos_in_tag", [36, 37]))
		main_size = int((rt.get("main", {}) as Dictionary).get("size", 17))
		sub_size = int((rt.get("sub", {}) as Dictionary).get("size", 11))
		seal_scale = 0.8
		center = Vector2(16, 23)
		_draw_inlay(tag, UiTheme.art_cached(BRONZE + "tag_inlay"), true)
	elif _inlay == "wide":
		main_pos = _vec((text.get("main", {}) as Dictionary).get("pos_in_tag", [50, 23]))
		sub_pos = _vec((text.get("sub", {}) as Dictionary).get("pos_in_tag", [50, 38]))
		main_size = int((text.get("main", {}) as Dictionary).get("size", 19))
		sub_size = int((text.get("sub", {}) as Dictionary).get("size", 12))
		_draw_inlay(tag, UiTheme.art_cached(BRONZE + "tag_inlay_wide"), false)
	else:
		var main: Dictionary = text.get("main", {})
		var sub: Dictionary = text.get("sub", {})
		main_pos = _vec(main.get("pos_in_tag", [50, 23]))
		sub_pos = _vec(sub.get("pos_in_tag", [50, 38]))
		main_size = int(main.get("size", 19))
		sub_size = int(sub.get("size", 12))
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
		var seal_piece: Dictionary = pieces.get(SEAL_ART[kind], pieces.get("seal", {}))
		center = _vec(seal_piece.get("center_in_tag", [20, 23]))
	tag.draw_string(UiPalette.cjk_font_bold(), main_pos, String(b["main"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, main_size, b["main_color"])
	tag.draw_string(UiPalette.cjk_font_bold() if bool(b["sub_bold"]) else UiPalette.cjk_font(), sub_pos, String(b["sub"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, b["sub_color"])
	var seal := UiTheme.art_cached(ART + String(SEAL_ART[kind]))
	if seal != null:
		var side := seal.get_size() * seal_scale
		tag.draw_texture_rect(seal, Rect2((center - side * 0.5).floor(), side), false)
	else:
		tag.draw_circle(center, 15.0 * seal_scale, SEAL_COLORS[kind])
		tag.draw_arc(center, 15.0 * seal_scale, 0.0, TAU, 32, Color(SEAL_COLORS[kind]).darkened(0.35), 2.0, true)


## 嵌槽签底：从火漆下面（x = [constant INLAY_TAG_X]）铺到签右沿；[param sliced] 三段切拉到签宽，否则原大
func _draw_inlay(tag: Control, tex: Texture2D, sliced: bool) -> void:
	var at := Vector2(INLAY_TAG_X, INLAY_TOP)
	if tex == null:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("2a1c0e", 0.85)
		box.set_corner_radius_all(4)
		tag.draw_style_box(box, Rect2(Vector2(INLAY_TAG_X, 0), Vector2(tag.size.x - INLAY_TAG_X, tag.size.y)))
		return
	if not sliced:
		tag.draw_texture(tex, at)
		return
	var ts := tex.get_size()
	var w := maxf(tag.size.x - INLAY_TAG_X, INLAY_LEFT + INLAY_RIGHT)
	tag.draw_texture_rect_region(tex, Rect2(at, Vector2(INLAY_LEFT, ts.y)), Rect2(0, 0, INLAY_LEFT, ts.y))
	tag.draw_texture_rect_region(tex, Rect2(at + Vector2(INLAY_LEFT, 0), Vector2(w - INLAY_LEFT - INLAY_RIGHT, ts.y)),
		Rect2(INLAY_LEFT, 0, ts.x - INLAY_LEFT - INLAY_RIGHT, ts.y))
	tag.draw_texture_rect_region(tex, Rect2(at + Vector2(w - INLAY_RIGHT, 0), Vector2(INLAY_RIGHT, ts.y)), Rect2(ts.x - INLAY_RIGHT, 0, INLAY_RIGHT, ts.y))


func _hover(tag: Control, kind: StringName) -> void:
	if tip != null and tip_text(kind) != "":
		tip.show_text(tip_text(kind), tag.global_position + Vector2(0, tag.size.y))


func _load_block(run: RunState) -> Dictionary:
	var weight := run.carry_weight()
	var cap := run.carry_capacity()
	var main := "%d / %d" % [weight, cap] if cap > 0 else str(weight)
	var line := run.encumbrance_line()
	if line == "":     # 这一章不算负重：没有档（战前准备屏那排窄签副行写「负重」）
		return {"main": main, "sub": UiText.t("strip.load") if _inlay == "narrow" else "", "main_color": _main_color(), "sub_color": _sub_color(), "sub_bold": false,
			"tip": UiText.t("strip.load_off") % main}
	var lv := run.encumbrance_level()
	var level_name := run.encumbrance.name_of(lv)
	return {"main": main, "sub": level_name,
		"main_color": _main_color(), "sub_color": _load_ink(level_name, lv), "sub_bold": lv > 0,
		"tip": line + ("\n" + run.encumbrance.effect_text(lv) if lv > 0 else "")}


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
