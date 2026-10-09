## 战斗回放（117，作者定）：开发工具里翻 `user://battle_logs/*.replay.json`。左边列场次（新的在上：时间、章节、点、对手、胜负、时长），
## 点一场右边用 [BattleView] 照真打时一样重演（倍速 / 拖动 / 跳过、双方棋盘与冷却遮罩）。底下「打开日志文件夹」「打开这场的 .txt」。
##
## **游戏里没有入口**（作者定：不给玩家看），只从启动选择器进来。存档与列目录是 [BattleArchive] 的事，这里只画
extends Control

## 看哪个目录（测试指到自己的临时目录）
var dir: String = BattleArchive.DIR

var view: BattleView
var _font: Font
var _db: ItemDatabase
var _buff_defs: Dictionary = {}
var _entries: Array[Dictionary] = []
var _list: VBoxContainer
var _title: Label
var _hint: Label
var _current: Dictionary = {}


func _ready() -> void:
	_font = UiPalette.cjk_font()
	_db = ItemDatabase.new()
	_db.load_dir()
	_buff_defs = _known_buffs(_db)
	_build()
	refresh()


## 回放存档只记 buff id：定义从道具里能施加的 buff + 系统的衰竭查回来（查不到的不画图标）
static func _known_buffs(db: ItemDatabase) -> Dictionary:
	var out := {}
	for id in db.ids():
		var found := Glossary.buffs_in_item(db.get_def(id))
		for bid in found:
			out[StringName(String(bid))] = found[bid]
	var decay := OvertimeRules.or_default(null).decay_buff()
	if decay != null:
		out[decay.id] = decay
	return out


func _build() -> void:
	UiTheme.prepare_root(self)     # 091 / 121：底色跟设置走、装上界面主题

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	margin.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 340
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	left.add_child(_label("战斗回放", 22, UiPalette.FG))
	left.add_child(_label("最近 %d 场（新的在上）" % BattleArchive.KEEP, 12, UiPalette.DIM))
	left.add_child(UiTheme.make_button("刷新", refresh, UiTheme.TIER_PLAIN, 13))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)
	left.add_child(UiTheme.make_button("打开日志文件夹", open_folder, UiTheme.TIER_PLAIN, 13))
	left.add_child(UiTheme.make_button("打开这场的 .txt", open_text, UiTheme.TIER_PLAIN, 13))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	_title = _label("左边挑一场", 16, UiPalette.FG)
	right.add_child(_title)
	view = BattleView.new()
	view.label_font = _font
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(1000, 760)
	right.add_child(view)
	_hint = _label("", 12, UiPalette.DIM)
	right.add_child(_hint)


#region 公开动作（测试也走这里）
## 重新列目录
func refresh() -> void:
	_entries = BattleArchive.list(dir)
	if _list == null:
		return
	UiTheme.clear_children(_list)
	if _entries.is_empty():
		_list.add_child(_label("还没有记录。设置 → 开发 → 战斗日志开着时，每打一场都会存一份。", 12, UiPalette.DIM))
	for i in _entries.size():
		var e := _entries[i]
		var idx := i
		var b := UiTheme.make_button(_row_text(e), func(): open_entry(idx), UiTheme.TIER_PLAIN, 12)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list.add_child(b)


func entries() -> Array[Dictionary]:
	return _entries


## 打开第 [param i] 场：读存档、交给回放从头播。读不了返回 false
func open_entry(i: int) -> bool:
	if i < 0 or i >= _entries.size():
		return false
	var e := _entries[i]
	var replay := BattleArchive.load_replay(String(e["path"]))
	var result := BattleArchive.result_of(replay, _buff_defs)
	if result == null:
		_hint.text = "读不了：%s" % String(e["path"])
		return false
	_current = e
	view.play(result, ["我", String(e.get("enemy", "敌"))])
	var names: Array = replay.get("names", [])
	var boards: Array = replay.get("boards", [])
	for side in 2:
		view.set_item_names(side, names[side] if side < names.size() and names[side] is Dictionary else {})
		var bd = boards[side] if side < boards.size() else null
		if bd is Dictionary and not (bd as Dictionary).is_empty():
			view.set_board(side, GridInventory.from_dict(bd, _db))
	_title.text = _row_text(e)
	_hint.text = "%s　%d 条事件" % [String(e["stem"]), result.log.size()]
	return true


func open_folder() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	OS.shell_open(ProjectSettings.globalize_path(dir))


func open_text() -> void:
	if _current.is_empty():
		return
	OS.shell_open(ProjectSettings.globalize_path(dir.path_join(String(_current["stem"]) + BattleArchive.TEXT_EXT)))
#endregion


static func _row_text(e: Dictionary) -> String:
	var w := int(e.get("winner", -1))
	var verdict := "赢" if w == 0 else ("输" if w == 1 else "平")
	return "%s　%s n%d　%s　%s　%.1f 秒" % [String(e.get("when", "")).replace("T", " "), String(e.get("chapter", "")),
		int(e.get("node", -1)), String(e.get("enemy", "")), verdict, StatMath.to_float(int(e.get("duration", 0)))]


## 这一屏的标签都折行（列表里的一行可能很长）
func _label(text: String, size: int, color: Color) -> Label:
	var l := UiTheme.make_label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
