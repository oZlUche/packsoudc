## 261（作者 14:13）：书架上「对局记录」那一格点开的窗 —— 最近 20 局，从新到旧一行一局，星 = 收藏（收藏的不删，最多 19）；
## 点一行看详情（同一个窗里换页，左上「← 记录」回列表）。调试模式下详情多一行地图种子，旁边「复制」
class_name RunRecordsWindow
extends VBoxContainer

const ROW_H := 44.0
const STAR_W := 52.0
const FONT_SIZE := 15
const WIN := UiPalette.HEAL
const LOSS := UiPalette.HP

var flow: GameFlow = null
var font: Font = null
var _head: HeaderTag = null
var _body: VBoxContainer = null
var _list: VBoxContainer = null
var _stars: Array[Button] = []
var _rows: Array[Button] = []
## 正在看的那一局（-1 = 列表）
var _detail := -1
var _detail_text: Array[String] = []
var _copy_btn: Button = null
var _back_btn: Button = null


func setup(p_flow: GameFlow, p_font: Font) -> void:
	flow = p_flow
	font = p_font
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	show_list()


func history() -> Array[Dictionary]:
	return flow.meta.history


#region 列表
func show_list() -> void:
	_detail = -1
	_clear()
	var m := flow.meta
	_head = HeaderTag.new(UiText.t("records.count") % [m.history.size(), MetaState.HISTORY_MAX, m.pinned_count(), MetaState.PIN_MAX])
	add_child(_head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = UiTheme.vbox(4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	for i in m.history.size():
		var line := UiTheme.hbox(6)
		_list.add_child(line)
		var star := UiTheme.make_home_button("", toggle_pin.bind(i), false, Vector2(STAR_W, ROW_H), FONT_SIZE)
		star.toggle_mode = true
		star.tooltip_text = UiText.t("records.pin_tip")
		line.add_child(star)
		_stars.append(star)
		var row := RecordRow.new()
		row.setup(_columns(m.history[i]), _outcome_color(m.history[i]))
		row.custom_minimum_size.y = ROW_H
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(show_detail.bind(i))
		line.add_child(row)
		_rows.append(row)
	_sync_stars()


func _sync_stars() -> void:
	for i in _stars.size():
		var on := bool(flow.meta.history[i].get("pinned", false))
		_stars[i].set_pressed_no_signal(on)
		_stars[i].text = "★" if on else ""


## 点星：收藏 / 取消；收藏满了说一声，星不亮
func toggle_pin(i: int) -> bool:
	var on := not bool(flow.meta.history[i].get("pinned", false))
	var ok := flow.meta.pin_run(i, on)
	if not ok and on:
		_head.text = UiText.t("records.pinned_full") % MetaState.PIN_MAX
	else:
		_head.text = UiText.t("records.count") % [flow.meta.history.size(), MetaState.HISTORY_MAX, flow.meta.pinned_count(), MetaState.PIN_MAX]
	_sync_stars()
	return ok


func head_text() -> String:
	return _head.text if _head != null else ""


func row_count() -> int:
	return _rows.size()


func row_columns(i: int) -> Array:
	return (_rows[i] as RecordRow).columns


## 一行的几栏：第几局 · 时间 · 章节 · 规模 · 难度 · 角色 · 结局 · 分（269；老记录「—」）· 值 / 带出 · 步数
func _columns(h: Dictionary) -> Array:
	return [UiText.t("records.run_no") % int(h.get("run_no", 0)), _when(h), _where(h), _who(h), _outcome(h),
		UiText.t("records.col_score") % str(int(h["score"])) if h.has("score") else UiText.t("records.no_score"),     # 游戏测试 v4.86：老行只写「—」
		UiText.t("records.col_value") % [int(h.get("value", 0)), int(h.get("balance", 0))], UiText.count(int(h.get("steps", 0)), "records.col_steps")]


## 269：详情「总分 N（战利 N · 战绩 N · 探索 N）」；269 前的局没记分写「—」
func _score(h: Dictionary) -> String:
	if not h.has("score"):
		return UiText.t("records.no_score")
	var p: Dictionary = h.get("score_parts", {}) if h.get("score_parts", {}) is Dictionary else {}
	return UiText.t("records.detail_score_v") % [int(h["score"]), int(p.get("loot", 0)), int(p.get("battle", 0)), int(p.get("explore", 0))]


func _outcome_color(h: Dictionary) -> Color:
	return WIN if String(h.get("outcome", "")) == "extracted" else LOSS
#endregion


#region 详情
func show_detail(i: int) -> void:
	_clear()
	_detail = i
	var h: Dictionary = flow.meta.history[i]
	var top := UiTheme.hbox(12)
	add_child(top)
	_back_btn = UiTheme.make_home_button(UiText.t("records.back"), show_list, false, Vector2.ZERO, FONT_SIZE)
	top.add_child(_back_btn)
	top.add_child(HeaderTag.new("%s · %s · %s" % [UiText.t("records.run_no") % int(h.get("run_no", 0)), _when(h), _outcome(h)]))
	var cols := UiTheme.hbox(24)
	add_child(cols)
	var left := LedgerRows.new()
	var right := LedgerRows.new()
	cols.add_child(left)
	cols.add_child(right)
	_detail_text.clear()
	_add(left, "records.detail_where", _where(h))
	_add(left, "records.detail_who", _who(h))
	_add(left, "records.detail_walk", UiText.t("records.detail_walk_v") % [int(h.get("steps", 0)), int(h.get("visited", 0))])
	_add(left, "records.detail_work", UiText.t("records.detail_work_v") % [int(h.get("searches", 0)), int(h.get("crafts", 0))])
	var items: Array = h.get("items", [])
	_add(right, "records.detail_out", UiText.t("records.detail_out_v") % [items.size(), int(h.get("value", 0)), int(h.get("balance", 0))])
	_add(right, "records.detail_safe", UiText.t("records.detail_safe_v") % [int(h.get("safe", 0)), int(h.get("safe_value", 0))])
	_add(right, "records.detail_fights", UiText.t("records.detail_fights_v") % [int(h.get("battles_won", 0)), int(h.get("battles_lost", 0)), int(h.get("elite_won", 0)), int(h.get("boss_won", 0))])
	_add(right, "records.detail_faith", _faith(h))
	_add(right, "records.detail_score", _score(h))
	if not items.is_empty():
		var strip := UiTheme.hflow(6)
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)
		strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(strip)
		for raw in items:
			var def := flow.items.get_def(StringName(String(raw))) if flow.items != null else null
			if def != null:
				strip.add_child(CodexTile.new(def, true, 0, font))
	if debug_shown():
		var dev := UiTheme.hbox(12)
		add_child(dev)
		var seed_rows := LedgerRows.new()
		dev.add_child(seed_rows)
		_add(seed_rows, "records.seed", UiText.t("records.seed_v") % [int(h.get("seed", 0)), " / ".join([String(h.get("chapter", "")), String(h.get("scale", ""))].filter(func(s: String) -> bool: return s != ""))])     # 261 前的局没记规模：不留半截「/」
		_copy_btn = UiTheme.make_home_button(UiText.t("records.copy_seed"), func(): DisplayServer.clipboard_set(str(int(h.get("seed", 0)))), false, Vector2.ZERO, FONT_SIZE)
		dev.add_child(_copy_btn)


## 调试模式（导出包里永远关）才写种子
func debug_shown() -> bool:
	return flow.settings != null and flow.settings.debug_on()


func detail_index() -> int:
	return _detail


## 详情页写了些什么（测试看「种子」有没有）
func detail_text() -> String:
	return "\n".join(_detail_text)


func _add(rows: LedgerRows, key: String, value: String) -> void:
	rows.add_row(UiText.t(key), value)
	_detail_text.append(UiText.t(key) + " " + value)


func _faith(h: Dictionary) -> String:
	var top: Dictionary = h.get("faith", {})
	if top.is_empty():
		return UiText.t("records.none")
	var fid := StringName(String(top.get("id", "")))
	var fd: FaithDef = flow.faith_defs.get(fid, null) if flow.faith_defs != null else null
	return UiText.t("records.detail_faith_v") % [Names.of(fd) if fd != null else String(fid), int(top.get("power", 0))]
#endregion


func _when(h: Dictionary) -> String:
	var t := int(h.get("ended_at", 0))
	if t <= 0:
		return "——"
	var d := Time.get_datetime_dict_from_unix_time(t + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	return "%02d-%02d %02d:%02d" % [int(d["month"]), int(d["day"]), int(d["hour"]), int(d["minute"])]


func _where(h: Dictionary) -> String:
	var parts: Array[String] = []
	var ch := flow.chapter_of(StringName(String(h.get("chapter", ""))))
	parts.append(Names.of(ch) if ch != null else String(h.get("chapter", "")))
	var scale := String(h.get("scale", ""))
	if scale != "":
		parts.append(UiText.t("records.scale_" + scale) if UiText.TEXT.has("records.scale_" + scale) else scale)
	var diff := flow.difficulty_of(StringName(String(h.get("difficulty", ""))))
	if diff != null:
		parts.append(Names.of(diff))
	return " · ".join(parts)


func _who(h: Dictionary) -> String:
	var who := flow.character_of(StringName(String(h.get("character", ""))))
	return Names.of(who) if who != null else "——"


func _outcome(h: Dictionary) -> String:
	if String(h.get("outcome", "")) == "extracted":
		return UiText.t("records.outcome_extracted")
	var why := String(h.get("reason", ""))
	return UiText.t("records.outcome_defeated") + ((" · " + UiText.t("records.reason_" + why)) if UiText.TEXT.has("records.reason_" + why) else "")


func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_stars.clear()
	_rows.clear()
	_head = null
	_copy_btn = null
	_back_btn = null
