## 223（作者 2026-10-21 16:07 选蜡板、甲 角色卡）：背包窗右栏名牌下面那张角色卡 ——「这个人是谁」，开包时随时可看。
##
## 381（作者 21:27「5~6 先按推荐」）：列全部属性，分生存、攻击、探索三组，每组一个小组名；没有加成的照样列（白字）。
## 数是这一局此刻的有效值（局外加成、信仰、难度、角色被动、这一局的牌都算进去）。基础的写纯白，这一局拿到的（地图 buff、升级的牌）
## 抬过的写金黄。停在一行上：第一行写属性说明，第二行写「基础 + 加算 + 百分比」，基础白字、加成黄字。
## 两条被动缩成卡底的小签，停上去看说明。画法读 `assets/ui/stats_panel/`（`card_wax` 九宫底板）。
## 385（作者定局内石刻）：底换深石板（`stone/slate`），被动小签换浅石小格（顶端栏那种凹槽）墨字
class_name CharacterCard
extends Control

const ART := "stats_panel/"
const LAYOUT := ART + "layout"
const STYLE := "wax"
## 三组：组名的键、这一组的属性（顺序就是排的顺序）
const GROUPS := [
	["card.group_survive", [&"max_hp", &"regen_hp", &"max_stamina", &"regen_stamina"]],
	["card.group_attack", [&"weapon_damage", &"weapon_haste", &"weapon_cost", &"crit_chance", &"crit_damage"]],
	["card.group_explore", [&"carry", &"vitality"]],
]
## 武器三行：按「武器」标签的那几条乘算（局外科技、升级的牌）
const WEAPON_STATS := {&"weapon_damage": BattleStats.DAMAGE, &"weapon_haste": BattleStats.HASTE, &"weapon_cost": BattleStats.STAMINA_COST}
const WEAPON_TAG := &"weapon"
## 一位小数的（每秒回复）与按百分数写的（暴击）
const DECIMAL: Array[StringName] = [&"regen_hp", &"regen_stamina"]
const PERCENT: Array[StringName] = [&"crit_chance", &"crit_damage"]
const BASE_COLOR := Color("ffffff")
const BOOST_COLOR := Color("ffc928")
const SIZE := Vector2(272, 228)
const PAD_TOP := 10.0
const GROUP_H := 24.0
const ROW_H := 20.0
const LABEL_X := 16.0
const VALUE_RIGHT := 256.0
const RULE_X := Vector2(14, 258)
const FONT_PX := 14
const GROUP_PX := 13
## 卡底的被动小签
const CHIP_H := 22.0
const CHIP_GAP := 8.0
const CHIP_PAD := 8.0
const CHIP_TOP_GAP := 8.0
const BOTTOM_PAD := 10.0

## 悬浮窗（宿主给；没有就不开）
var tip: HoverTip = null
## 每行：{"key", "label", "value"（写出来的数）, "boosted"（这一局抬过）, "tip"（富文本）, "top"}
var _rows: Array[Dictionary] = []
## 组名：{"label", "top"}
var _groups: Array[Dictionary] = []
## 被动小签：{"name", "text", "rect"}
var _passives: Array[Dictionary] = []
var _style: Dictionary = {}
var _hover := -1


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style = (((UiTheme.art_meta(LAYOUT).get("styles", {}) as Dictionary).get(STYLE, {})) as Dictionary)
	UiTheme.set_tone(self, StringName(String(_style.get("tone", "dark"))))
	mouse_exited.connect(_unhover)


## 按这一局重算（开窗、包变了、局外加成变了都叫它；便宜）
func refresh(run: RunState) -> void:
	_rows.clear()
	_groups.clear()
	_passives.clear()
	var y := PAD_TOP
	if run != null:
		for g in GROUPS:
			_groups.append({"label": UiText.t(String(g[0])), "top": y})
			y += GROUP_H
			for key in g[1]:
				var r := stat_row(run, key)
				if r.is_empty():
					continue
				r["top"] = y
				_rows.append(r)
				y += ROW_H
		if run.character != null:
			var f := UiPalette.cjk_font_bold()
			var x := LABEL_X
			y += CHIP_TOP_GAP
			for e in run.character.skill_entries():
				var w := f.get_string_size(String(e["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, GROUP_PX).x + CHIP_PAD * 2.0
				if x + w > VALUE_RIGHT and x > LABEL_X:
					x = LABEL_X
					y += CHIP_H + 4.0
				_passives.append({"name": String(e["name"]), "text": String(e["text"]), "rect": Rect2(x, y, w, CHIP_H)})
				x += w + CHIP_GAP
			if not _passives.is_empty():
				y += CHIP_H
	custom_minimum_size = Vector2(SIZE.x, maxf(SIZE.y, y + BOTTOM_PAD))
	size = custom_minimum_size
	queue_redraw()


## 一项属性的一行（这一章没有这项 —— 比如不算负重 —— 返回空）。
## 数 = 基础 ×（1 + Σ百分比）+ Σ加算；「这一局抬过」= 这一局拿到的 buff / 牌单独算也动了这一项
static func stat_row(run: RunState, key: StringName) -> Dictionary:
	var parts := _parts(run, key, run.buff_context(), true)
	if parts.is_empty():
		return {}
	var in_run := _parts(run, key, RunBuffs.context(_in_run_defs(run)), false)
	var boosted := not in_run.is_empty() and (not is_zero_approx(float(in_run["flat"])) or not is_zero_approx(float(in_run["pct"])))
	var base := float(parts["base"])
	var flat := float(parts["flat"])
	var pct := float(parts["pct"])
	var value := float(parts["value"]) if parts.has("value") else base * (1.0 + pct / 100.0) + flat
	var label := UiText.t("card.stat_" + String(key))
	var lines: Array[String] = [UiText.t("card.desc_" + String(key))]
	var sum := "[color=#%s]%s[/color]" % [BASE_COLOR.to_html(false), _fmt(key, base, false)]
	if not is_zero_approx(flat):
		sum += " [color=#%s]%s[/color]" % [BOOST_COLOR.to_html(false), _with_sign(_fmt(key, flat, true))]
	if not is_zero_approx(pct):
		sum += " [color=#%s]%s[/color]" % [BOOST_COLOR.to_html(false), _with_sign(_pct(pct))]
	lines.append(sum)
	return {"key": key, "label": label, "value": _fmt(key, value, false), "raw": value, "base": base, "flat": flat, "pct": pct,
		"boosted": boosted, "tip": "\n".join(lines)}


## {"base", "flat", "pct"}（有的还带 "value"：直接读这一局的数）；这一项这一章没有返回空
static func _parts(run: RunState, key: StringName, ctx: RunContext, with_altar: bool) -> Dictionary:
	if WEAPON_STATS.has(key):
		var stat: StringName = WEAPON_STATS[key]
		var pct := 0.0
		var flat := 0.0
		for sm in ctx.scoped:
			if not (sm as ScopedMod).tags.has(WEAPON_TAG):
				continue
			for m in (sm as ScopedMod).mods:
				if (m as StatModifier).stat == stat:
					if (m as StatModifier).mode == StatModifier.Mode.MULT:
						pct += (m as StatModifier).amount
		return {"base": 0.0, "flat": flat, "pct": pct, "value": pct}
	match key:
		&"carry":
			if run.character == null or run.character.weight_capacity <= 0:
				return {}
			var b := float(run.character.weight_capacity)
			return {"base": b, "flat": float(ctx.carry_capacity_bonus), "pct": float(ctx.carry_capacity_mult),
				"value": float(ctx.carry_capacity_of(int(b)))}
		&"vitality":
			var vb := float(run.character.vitality_max) if run.character != null else float(Vitality.PLACEHOLDER_MAX)
			if not with_altar:
				return {"base": vb, "flat": float(ctx.vitality_max_bonus), "pct": float(ctx.vitality_max_mult)}
			var now := float(run.vitality.maximum) if run.vitality != null else float(ctx.vitality_max_of(int(vb)))
			var vp := float(ctx.vitality_max_mult)
			return {"base": vb, "flat": now - roundf(vb * (1.0 + vp / 100.0)), "pct": vp, "value": now}
	var own := run.player_baseline if run.player_baseline != null else CombatantBaseline.default_baseline()
	var base := float(own.base_stats.get(key, BattleStats.default_value(key)))
	var flat2 := 0.0
	var pct2 := 0.0
	for k in ctx.stat_mult:
		if String(k) == String(key):
			pct2 += float(ctx.stat_mult[k])
	for k in ctx.stat_bonus:
		if String(k) == String(key):
			flat2 += float(ctx.stat_bonus[k])
	if with_altar:
		var altar := AltarModule.of(run)
		if altar != null:
			for k in altar.stat_bonus:
				if String(k) == String(key):
					flat2 += float(altar.stat_bonus[k])
	return {"base": base, "flat": flat2, "pct": pct2}


## 这一局拿到的（地图 buff、升级的牌）
static func _in_run_defs(run: RunState) -> Array:
	return run.active_buff_defs().filter(func(d) -> bool: return d is RunBuffDef and (d as RunBuffDef).is_map())


## 一个数怎么写：每秒回复一位小数；暴击按百分数；武器三行是带号的百分数；其余取整
static func _fmt(key: StringName, v: float, delta: bool) -> String:
	if WEAPON_STATS.has(key):
		return _with_sign(_pct(v)) if not delta else _pct(v)
	if PERCENT.has(key):
		return _pct(v * 100.0)
	if DECIMAL.has(key):
		return "%.1f" % v
	return str(roundi(v))


static func _pct(v: float) -> String:
	return ("%d%%" % roundi(v)) if is_equal_approx(v, roundf(v)) else ("%.1f%%" % v)


static func _with_sign(s: String) -> String:
	return s if s.begins_with("-") or s.begins_with("+") else "+" + s


## 测试看：第 i 行（只数属性行，不数组名）
func row(i: int) -> Dictionary:
	return _rows[i] if i >= 0 and i < _rows.size() else {}


## 测试看：按键找一行
func row_of(key: StringName) -> Dictionary:
	for r in _rows:
		if r["key"] == key:
			return r
	return {}


func row_count() -> int:
	return _rows.size()


func group_labels() -> Array[String]:
	var out: Array[String] = []
	for g in _groups:
		out.append(String(g["label"]))
	return out


func passive_names() -> Array[String]:
	var out: Array[String] = []
	for p in _passives:
		out.append(String(p["name"]))
	return out


## 这一格（卡内坐标）压着哪一行：0.. 属性行，之后是被动小签；没有 -1
func row_at(local: Vector2) -> int:
	if local.x < 0.0 or local.x > size.x:
		return -1
	for i in _rows.size():
		var top := float(_rows[i]["top"])
		if local.y >= top and local.y < top + ROW_H:
			return i
	for i in _passives.size():
		if (_passives[i]["rect"] as Rect2).has_point(local):
			return _rows.size() + i
	return -1


## 第 i 行的悬浮窗（富文本）
func tip_text(i: int) -> String:
	if i >= 0 and i < _rows.size():
		return String(_rows[i]["tip"])
	var p := i - _rows.size()
	if p >= 0 and p < _passives.size():
		return String(_passives[p]["name"]) + "\n" + String(_passives[p]["text"])
	return ""


## 小签在卡里的位置（测试、教程）
func passive_rect(i: int) -> Rect2:
	return _passives[i]["rect"] if i >= 0 and i < _passives.size() else Rect2()


func _color(key: String, fallback: Color) -> Color:
	return Color(String(_style[key])) if _style.has(key) else fallback


func _draw() -> void:
	var slate := UiTheme.art_box(UiTheme.ART_STONE_SLATE)     # 385：深石板；没图退回蜡板
	var bg := UiTheme.art_cached(ART + "card_" + STYLE)
	if slate != null:
		draw_style_box(slate, Rect2(Vector2.ZERO, size))
	elif bg != null:
		draw_style_box(UiTheme.nine_box(bg, [16, 16, 16, 16]), Rect2(Vector2.ZERO, size))
	var well := UiTheme.art_box(UiTheme.ART_HUD_WELL)
	var regular := UiPalette.cjk_font()
	var bold := UiPalette.cjk_font_bold()
	var label := _color("label", UiTheme.INK)
	var dim := _color("dim", UiTheme.INK_SOFT)
	for g in _groups:
		var top := float(g["top"])
		draw_string(bold, Vector2(LABEL_X, top + 16.0), String(g["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, GROUP_PX, dim)
		_rule(top + GROUP_H - 3.0)
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var top := float(r["top"])
		if i == _hover:
			draw_rect(Rect2(RULE_X.x, top, RULE_X.y - RULE_X.x, ROW_H), Color(1, 1, 1, 0.08))
		var base_y := top + 15.0
		draw_string(regular, Vector2(LABEL_X, base_y), String(r["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, label)
		var vs := String(r["value"])
		var x := VALUE_RIGHT - bold.get_string_size(vs, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x
		draw_string(bold, Vector2(x, base_y), vs, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, BOOST_COLOR if bool(r["boosted"]) else BASE_COLOR)
	for i in _passives.size():
		var p: Dictionary = _passives[i]
		var rect: Rect2 = p["rect"]
		var hot := i + _rows.size() == _hover
		if well != null:     # 385：浅石小格、墨字；停上去提亮一点
			draw_style_box(well, rect)
			if hot:
				draw_rect(rect.grow(-2.0), Color(1, 1, 1, 0.18))
			draw_string(bold, rect.position + Vector2(CHIP_PAD, 16.0), String(p["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, GROUP_PX, UiTheme.STONE_INK)
			continue
		draw_rect(rect, Color(1, 1, 1, 0.12 if hot else 0.06))
		draw_rect(rect, Color(BASE_COLOR, 0.55), false, 1.0)
		draw_string(bold, rect.position + Vector2(CHIP_PAD, 16.0), String(p["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, GROUP_PX, BASE_COLOR)


## 行间刻线：`styles.<材质>.rule` 的几条 1 px 横线叠出来
func _rule(y: float) -> void:
	for r in (_style.get("rule", [{"color": "#0e0a08", "alpha": 0.7, "dy": 0}]) as Array):
		var c := Color(String(r.get("color", "#000000")), float(r.get("alpha", 1.0)))
		var yy := y + float(r.get("dy", 0)) + 0.5
		draw_line(Vector2(RULE_X.x, yy), Vector2(RULE_X.y, yy), c, 1.0)


## 不能落在行首的标点（避头）
const NO_LINE_START := "，。、；：？！）」』”’…·%,.;:?!)"


## 按宽度折成最多 [param max_lines] 行：汉字逐字可断，拉丁字母成词不拆（游戏测试 10-21：英文被拆成「Er/osion」），
## 一个词比整行还宽才逐字断；超出的最后一行截断加「…」
static func wrap_lines(text: String, f: Font, px: int, width: float, max_lines: int) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for tok in _tokens(text):
		if tok == "\n":
			out.append(line)
			line = ""
		elif tok == " " and line == "":
			continue     # 行首不留空格
		elif f.get_string_size(line + tok, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width:
			line += tok
		elif tok == " ":
			out.append(line)
			line = ""
		elif NO_LINE_START.contains(tok) and line.length() > 1:     # 避头：标点不落行首，把上一行最后一个字一起带下来（复测 10-27「偷袭」第二行以「，」开头）
			out.append(line.left(line.length() - 1))
			line = line.right(1) + tok
		else:
			if line != "":
				out.append(line.strip_edges(false, true))
				line = ""
			for ch in tok:     # 只有一个词比整行还宽时才会在这里逐字断
				if line != "" and f.get_string_size(line + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
					out.append(line)
					line = ""
				line += ch
	if line.strip_edges() != "":
		out.append(line.strip_edges(false, true))
	if out.size() > max_lines:
		out.resize(max_lines)
		var last := out[max_lines - 1]
		while last != "" and f.get_string_size(last + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
			last = last.left(last.length() - 1)
		out[max_lines - 1] = last.strip_edges(false, true) + "…"
	return out


## 折行的最小单位：一串连着的非空白非汉字（一个英文词连标点）、一个汉字 / 全角符号、一个空格、一个换行
static func _tokens(text: String) -> Array[String]:
	var out: Array[String] = []
	var word := ""
	for ch in text:
		var wide := ch.unicode_at(0) >= 0x2E80
		if ch == " " or ch == "\n" or wide:
			if word != "":
				out.append(word)
				word = ""
			out.append(ch)
		else:
			word += ch
	if word != "":
		out.append(word)
	return out


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm == null:
		return
	var at := row_at(mm.position)
	if at == _hover:
		return
	_hover = at
	queue_redraw()
	if tip == null:
		return
	if at < 0 or tip_text(at) == "":
		tip.release()
	else:
		tip.show_text(tip_text(at), global_position + Vector2(size.x + 8.0, mm.position.y))


func _unhover() -> void:
	_hover = -1
	queue_redraw()
	if tip != null:
		tip.release()
