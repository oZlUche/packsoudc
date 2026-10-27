## 223（作者 2026-10-21 16:07 选蜡板、甲 角色卡）：背包窗右栏名牌下面那张角色卡 ——「这个人是谁」，开包时随时可看，没有零行。
##
## 身体三行（生命上限 / 耐力上限 / 耐力恢复/秒）= [method RunState.effective_baseline]（局外加成、信仰、难度、角色被动乘完之后的数），
## 比角色本身的基线多或少就在数后面写 ▲N / ▼N，停上去看是谁给的；下面两条被动（名字 + 现成的一句说明，写全文：英文按词折行，卡跟着长高）。
## 画法读 `assets/ui/stats_panel/`（`card_wax` 九宫底板、`layout.json` 的卡内坐标与字色，美术设计出）；行间刻线由代码画
class_name CharacterCard
extends Control

const ART := "stats_panel/"
const LAYOUT := ART + "layout"
const STYLE := "wax"
const ROWS: Array[StringName] = [BattleStats.MAX_HP, BattleStats.MAX_STAMINA, BattleStats.REGEN_STAMINA]
const ROW_KEYS := {BattleStats.MAX_HP: "card.max_hp", BattleStats.MAX_STAMINA: "card.max_stamina", BattleStats.REGEN_STAMINA: "card.regen"}
## 没有 `layout.json` 时的卡内排版（和美术定稿同一份）
const SIZE := Vector2(272, 228)
const ROW_TOP := 12.0
const ROW_H := 30.0
const LABEL_X := 20.0
const VALUE_RIGHT := 252.0
const RULE_X := Vector2(18, 254)
const DIVIDER_Y: Array[float] = [105.0, 108.0]
const PASSIVE_TOP := 111.0
## 被动一条：名字一行 [constant PASSIVE_HEAD] + 说明 n 行 × [constant SUMMARY_LINE_H] + 下留白 [constant PASSIVE_PAD]
const PASSIVE_HEAD := 26.0
const PASSIVE_PAD := 8.0
const SUMMARY_W := 232.0
const SUMMARY_SIZE := 13
const SUMMARY_LINE_H := 16.0
## 说明最多几行（游戏测试 10-21：两行装不下英文，改成写全文；这只是防一条特别长的撑破窗）
const SUMMARY_LINES := 6
const BOTTOM_PAD := 11.0

## 悬浮窗（宿主给；没有就不开）
var tip: HoverTip = null
## 每行：{"label", "unit", "value", "delta"（带号的整数 / 一位小数，0 = 没变）, "tip"}
var _rows: Array[Dictionary] = []
## 每条被动：{"name", "text", "lines"（折好的说明）, "top", "height"}
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
	_passives.clear()
	if run != null:
		var eff := run.effective_baseline()
		var own := run.player_baseline if run.player_baseline != null else CombatantBaseline.default_baseline()
		for stat in ROWS:
			_rows.append(_row(run, stat, _stat(eff, stat), _stat(own, stat)))
		if run.character != null:
			for e in run.character.skill_entries():
				_passives.append({"name": String(e["name"]), "text": String(e["text"])})
	var top := PASSIVE_TOP
	for p in _passives:
		p["lines"] = wrap_lines(String(p["text"]), UiPalette.cjk_font(), SUMMARY_SIZE, SUMMARY_W, SUMMARY_LINES)
		p["top"] = top
		p["height"] = PASSIVE_HEAD + SUMMARY_LINE_H * (p["lines"] as Array).size() + PASSIVE_PAD
		top += float(p["height"])
	custom_minimum_size = Vector2(SIZE.x, maxf(SIZE.y, top + BOTTOM_PAD))
	size = custom_minimum_size
	queue_redraw()


## 测试看：第 i 行 {"value", "delta", "tip"}、被动名
func row(i: int) -> Dictionary:
	return _rows[i] if i >= 0 and i < _rows.size() else {}


func passive_names() -> Array[String]:
	var out: Array[String] = []
	for p in _passives:
		out.append(String(p["name"]))
	return out


## 测试看：第 i 条被动折好的说明行
func passive_lines(i: int) -> Array:
	return (_passives[i]["lines"] as Array) if i >= 0 and i < _passives.size() else []


## 这一格（卡内坐标）压着哪一行：0..2 身体行，3.. 被动；没有 -1
func row_at(local: Vector2) -> int:
	if local.x < 0.0 or local.x > size.x:
		return -1
	for i in _rows.size():
		var top := ROW_TOP + ROW_H * i
		if local.y >= top and local.y < top + ROW_H:
			return i
	for i in _passives.size():
		var top := float(_passives[i]["top"])
		if local.y >= top and local.y < top + float(_passives[i]["height"]):
			return ROWS.size() + i
	return -1


## 第 i 行的悬浮窗
func tip_text(i: int) -> String:
	if i >= 0 and i < _rows.size():
		return String(_rows[i]["tip"])
	var p := i - ROWS.size()
	if p >= 0 and p < _passives.size():
		return String(_passives[p]["name"]) + "\n" + String(_passives[p]["text"])
	return ""


## 一项身体数值是谁改的：[{"name", "delta"}]（局外 / 一局里拿的 buff 各一条、难度、角色被动、信仰）；没人改是空的
static func sources(run: RunState, stat: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var own := run.player_baseline if run.player_baseline != null else CombatantBaseline.default_baseline()
	var base := _stat(own, stat)
	for d in run.active_buff_defs():
		_add_source(out, Names.of(d), _delta(base, RunBuffs.context([d]), stat))
	if run.difficulty != null:
		var ctx := RunContext.new()
		for e in run.difficulty.run_effects():
			e.modify(ctx)
		_add_source(out, Names.of(run.difficulty), _delta(base, ctx, stat))
	if run.character != null:
		var ctx2 := RunContext.new()
		for e in run.character.run_effects():
			e.modify(ctx2)
		_add_source(out, Names.of(run.character), _delta(base, ctx2, stat))
	var altar := AltarModule.of(run)
	if altar != null:
		for key in altar.stat_bonus:
			if String(key) == String(stat):
				_add_source(out, UiText.t("card.src_faith"), float(altar.stat_bonus[key]))
	return out


static func _add_source(out: Array[Dictionary], name: String, delta: float) -> void:
	if not is_zero_approx(delta):
		out.append({"name": name, "delta": delta})


## 一份 [RunContext] 给这项加了多少（倍率按角色基线算，再加平加）
static func _delta(base: float, ctx: RunContext, stat: StringName) -> float:
	var d := 0.0
	for key in ctx.stat_mult:
		if String(key) == String(stat):
			d += base * float(ctx.stat_mult[key]) / 100.0
	for key in ctx.stat_bonus:
		if String(key) == String(stat):
			d += float(ctx.stat_bonus[key])
	return d


static func _stat(b: CombatantBaseline, stat: StringName) -> float:
	return float(b.base_stats.get(stat, BattleStats.default_value(stat))) if b != null else BattleStats.default_value(stat)


func _row(run: RunState, stat: StringName, value: float, own: float) -> Dictionary:
	var regen := stat == BattleStats.REGEN_STAMINA
	var shown := snappedf(value, 0.1) if regen else float(roundi(value))
	var delta := snappedf(value - own, 0.1) if regen else float(roundi(value) - roundi(own))
	var lines: Array[String] = [UiText.t("card.tip_line") % [UiText.t(ROW_KEYS[stat]), _num(shown, regen)],
		UiText.t("card.tip_base") % _num(snappedf(own, 0.1) if regen else float(roundi(own)), regen)]
	for s in sources(run, stat):
		lines.append(UiText.t("card.tip_source") % [String(s["name"]), _signed(snappedf(float(s["delta"]), 0.1) if regen else float(roundi(float(s["delta"]))), regen)])
	return {"label": UiText.t(ROW_KEYS[stat]), "unit": "", "value": _num(shown, regen),
		"delta": delta, "regen": regen, "tip": "\n".join(lines)}


static func _num(v: float, decimal: bool) -> String:
	return ("%.1f" % v) if decimal else str(roundi(v))


static func _signed(v: float, decimal: bool) -> String:
	return ("+" if v > 0.0 else "") + _num(v, decimal)


func _color(key: String, fallback: Color) -> Color:
	return Color(String(_style[key])) if _style.has(key) else fallback


func _draw() -> void:
	var bg := UiTheme.art_cached(ART + "card_" + STYLE)
	if bg != null:
		var sb := StyleBoxTexture.new()
		sb.texture = bg
		sb.set_texture_margin_all(16)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("3a2a1c"))
	var regular := UiPalette.cjk_font()
	var bold := UiPalette.cjk_font_bold()
	var label := _color("label", UiTheme.INK)
	var value := _color("value", UiTheme.INK)
	var dim := _color("dim", UiTheme.INK_SOFT)
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var base_y := ROW_TOP + ROW_H * i + 20.0
		draw_string(regular, Vector2(LABEL_X, base_y), String(r["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, label)
		if String(r["unit"]) != "":
			var lw := regular.get_string_size(String(r["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(regular, Vector2(LABEL_X + lw + 5.0, base_y), String(r["unit"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)
		var x := VALUE_RIGHT
		var d := float(r["delta"])
		if not is_zero_approx(d):
			var mark := (UiText.t("card.up") if d > 0.0 else UiText.t("card.down")) % _num(absf(d), bool(r["regen"]))
			x -= regular.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(regular, Vector2(x, base_y), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, _color("good" if d > 0.0 else "bad", value))
			x -= 4.0
		var vs := String(r["value"])
		x -= bold.get_string_size(vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(bold, Vector2(x, base_y), vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, value)
	for y in DIVIDER_Y:
		_rule(y)
	for i in _passives.size():
		var p: Dictionary = _passives[i]
		var top := float(p["top"])
		if i > 0:
			_rule(top)
		draw_string(bold, Vector2(LABEL_X, top + 18.0), String(p["name"]), HORIZONTAL_ALIGNMENT_LEFT, SUMMARY_W, 15, value)
		var lines: Array = p["lines"]
		for j in lines.size():
			draw_string(regular, Vector2(LABEL_X, top + PASSIVE_HEAD + 9.0 + SUMMARY_LINE_H * j), String(lines[j]), HORIZONTAL_ALIGNMENT_LEFT, -1, SUMMARY_SIZE, dim)


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
	if tip == null:
		return
	if at < 0 or tip_text(at) == "":
		tip.release()
	else:
		tip.show_text(tip_text(at), global_position + mm.position + Vector2(12, 12))


func _unhover() -> void:
	_hover = -1
	if tip != null:
		tip.release()
