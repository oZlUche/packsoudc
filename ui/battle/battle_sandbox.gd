## 阶段 2 的验收场景：把棋盘上的东西真打一场，并看得见。
##
## 左边摆背包（和 M1 沙盒同一套拖拽），右边是回放。改一件装备的位置就重新编译，
## **预估 DPS 与套装进度实时跟着变** —— 这正是这一品类的核心爽点，
## 它之所以成立，是因为编译是纯函数（4.2）。
##
## 战斗本身在按下「开打」那一瞬就算完了，右边只是回放（4.8）。
extends Control

const BOARD_SIZE := Vector2i(7, 9)
## 地上是个**列表**，不是一块地方：摆不下、或者暂时不想要的东西放这儿，
## 它不参战，摆在第几行也不承载任何信息（见 [ItemStash]）。
## 所以「拿下来」和「扔掉」不再是同一个动作。
const STORAGE_WIDTH := 200

var _db: ItemDatabase
var _board: GridInventory
var _storage: ItemStash
var _tracker: SetTracker
var _drag: DragLayer
var _view: BattleView
var _font: Font

var _dps_label: Label
var _set_label: Label
var _hint: Label
var _seed_spin: SpinBox


func _ready() -> void:
	_font = UiPalette.cjk_font()
	_db = ItemDatabase.new()
	if _db.load_dir() == 0:
		push_error("没有加载到任何物品定义，先跑 tools/import_content.gd 把作者数据导成资产")

	ItemInstance.reset_uid_counter()
	_board = GridInventory.new(BOARD_SIZE, 1, true)
	_storage = ItemStash.new(2)
	_tracker = SetTracker.create(SetDatabase.new())
	_tracker.bind(_board)

	_build_ui()
	_seed_board()
	_board.changed.connect(_refresh_readout)
	_refresh_readout()


#region 界面
func _build_ui() -> void:
	var bg := ColorRect.new()
	UiPalette.apply(GameSettings.load_from())     # 091：底色跟设置走
	UiTheme.install()     # 121：界面主题挂在窗口上
	bg.color = UiPalette.bg()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	margin.add_child(columns)

	# --- 左：棋盘与读数 ---
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	columns.add_child(left)

	left.add_child(_label("作战棋盘　拖动即重新编译", 18, UiPalette.FG))

	var view := InventoryView.new()
	view.label_font = _font
	view.inventory = _board
	view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(view)

	_dps_label = _label("", 16, UiPalette.FG)
	left.add_child(_dps_label)
	_set_label = _label("", 13, UiPalette.DIM)
	left.add_child(_set_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	left.add_child(controls)
	controls.add_child(_button("开打", _on_fight))
	controls.add_child(_label("种子", 13, UiPalette.DIM))
	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 1
	_seed_spin.max_value = 9999
	_seed_spin.value = 1
	controls.add_child(_seed_spin)
	controls.add_child(_button("换一套装备", _on_reseed))

	_hint = _label("同一种子 → 逐条相同的回放。改变棋盘才会改变结果。", 12, UiPalette.DIM)
	left.add_child(_hint)

	left.add_child(_label("地上　放这儿的不参战　放手在哪就落在哪", 13, UiPalette.DIM))
	var storage_view := GroundLayer.new()     # 128：地上
	storage_view.label_font = _font
	storage_view.stash = _storage
	storage_view.custom_minimum_size = Vector2(STORAGE_WIDTH, 240)
	storage_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(storage_view)

	# --- 右：回放 ---
	_view = BattleView.new()
	_view.label_font = _font
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(_view)

	# 拖拽层盖在最上面
	_drag = DragLayer.new()
	_drag.label_font = _font
	_drag.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_drag)
	_drag.register_view(view)
	_drag.register_view(storage_view)
	_drag.stash = _storage
	_drag.items_displaced.connect(_on_displaced)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	UiTheme.label(l, font_size, color)     # 121：字体在主题里，颜色先选变体
	return l


func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(handler)
	return b
#endregion


#region 内容
## 开局摆一套能把各条机制都演出来的东西：
## 枪（自发出手）、弹匣（邻接增益）、匕首（施加流血）、
## 兴奋剂（开场 buff）、医疗包（跌破 40% 回一口）、口粮（耐力）。
##
## [b]位置是指定的，不是 try_add 摆出来的。[/b] 弹匣的增益格朝上，随便一摆就可能
## 落在第一排 —— 标记指向棋盘外，既不点亮也画不出来，开局看到的就是一件
## 「好像没有效果」的配件。演示场景得让机制自己显形，不能指望玩家去试。
const LAYOUT := [
	[&"pistol", Vector2i(0, 0)],
	[&"mag", Vector2i(0, 1)],      # 正在枪的下面：增益格 (0,-1) 刚好指着枪
	[&"knife", Vector2i(1, 1)],
	[&"medkit", Vector2i(2, 0)],
	[&"stim", Vector2i(2, 2)],
	[&"ration", Vector2i(3, 2)],
]


func _seed_board() -> void:
	_board.begin_batch()
	_board.clear()
	# 两个 2x3 的包 = 12 格。医疗包占 2x2，格子不够它就默默不参战 ——
	# 那会表现成「医疗包没救人」，而原因其实是没地方放，界面上看不出来。
	var bag := _db.get_def(&"bag_leather")
	if bag != null:
		_board.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
		_board.place(ItemInstance.create(bag), Vector2i(2, 0), 0)
	for row in LAYOUT:
		var def := _db.get_def(row[0])
		if def == null:
			continue
		var inst := ItemInstance.create(def)
		# 内容随时会改形状，指定的位置未必还放得下。放不下就退回自动装填，
		# 布局难看总好过这件东西干脆不上场
		if not _board.place(inst, row[1], 0):
			_board.try_add(inst)
	_board.end_batch()


## 顶掉别人之后给一句交代。不说的话，东西就是「不见了」——
## 玩家不会去地上找一件自己都不知道被挤走的物品。
func _on_displaced(instances: Array, grabbed: bool) -> void:
	var names: Array[String] = []
	for inst in instances:
		var item := inst as ItemInstance
		names.append(item.def.display_name if item.def != null else "?")
	if grabbed:
		_hint.text = "顶出了「%s」，已经拿在手上。" % names[0]
	else:
		_hint.text = "顶出了 %d 件（%s），都放到地上了。" % [names.size(), "、".join(names)]


func _on_reseed() -> void:
	var pool: Array = []
	for id in _db.ids():
		var def := _db.get_def(id)
		if def != null and not def.is_bag:
			pool.append(id)
	pool.shuffle()

	_board.begin_batch()
	_board.clear()
	var bag := _db.get_def(&"bag_leather")
	if bag != null:
		_board.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
	for i in mini(6, pool.size()):
		_board.try_add(ItemInstance.create(_db.get_def(pool[i])))
	_board.end_batch()


## 拖一下就重编译一次。编译是纯函数，所以这条读数永远和真打出来的一致。
func _refresh_readout() -> void:
	var spec := _compile()
	var active := spec.active_items().size()
	_dps_label.text = "生命 %d　预估 DPS %.1f　参战 %d 件（%d 件会出手）" % [
		spec.max_hp_int(), spec.rough_dps(), spec.items.size(), active
	]

	var lines: Array[String] = []
	for set_id in _tracker.tracked_ids():
		var p := _tracker.progress_of(set_id)
		lines.append("%s %d/%s%s" % [
			set_id, p["count"], "—" if p["next"] < 0 else str(p["next"]),
			"　已激活" if p["active"] else "",
		])
	_set_label.text = "套装：" + ("、".join(lines) if not lines.is_empty() else "无")


## uid -> 显示名，供回放把「uid 2 出手」写成「手枪 出手」
func _board_names() -> Dictionary:
	var out := {}
	for inst in _board.items():
		var item := inst as ItemInstance
		if item.def != null:
			out[item.uid] = item.def.display_name
	return out


func _compile() -> CombatantSpec:
	return BattleCompiler.compile_board(
		_board, null, _tracker.combat_mods(), _tracker.combat_rules()
	)


## 陪练：血厚、有点甲、会慢慢还手的靶子。
##
## 用固定靶而不是随机敌人，是为了让「换一件装备 → 打得快多少」看得清楚。
## 它会还手，是因为不挨打就看不到血条下降、医疗包触发、流血跳伤害 ——
## 一个只挨打的木桩演示不了一半的机制。真正的敌人配置属于 M4。
func _dummy() -> CombatantSpec:
	var spec := CombatantSpec.new()
	spec.baseline = StatSet.new()
	spec.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(120.0))
	spec.baseline.set_base(BattleStats.ARMOR, StatMath.from_float(2.0))
	spec.max_hp = spec.baseline.total_of(BattleStats.MAX_HP)

	var swing := DealDamage.new()
	swing.damage_stat = &""
	swing.amount = 4.0
	var cd := CooldownCadence.new()
	cd.seconds = 1.5
	var rule := AbilityRule.new()
	rule.trigger = OnSchedule.new()
	rule.cadence = cd
	rule.effects = [swing] as Array[CombatEffect]

	var fists := CompiledItem.new()
	fists.source_uid = 1
	fists.def_id = &"dummy_fists"
	fists.stats = StatSet.new()
	fists.rules = [rule] as Array[AbilityRule]
	spec.add(fists)
	return spec


func _on_fight() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_seed_spin.value)
	var me := _compile()
	var dummy := _dummy()
	# 117：沙盒也写战斗日志（设置开着时），章节记成 sandbox
	var trace: BattleTrace = BattleTrace.new() if BattleArchive.enabled and GameSettings.load_from().battle_trace else null
	var result := BattleSim.run(me, dummy, rng, BattleSim.DEFAULT_TIME_LIMIT, null, trace)     # 103：和真打一样带加时与衰竭
	if trace != null:
		BattleTraceWriter.write(trace, result, {"run_seed": int(_seed_spin.value), "chapter": "sandbox", "node": 0, "enemy": "dummy",
			"rng_seed": int(_seed_spin.value), "time_limit": BattleSim.DEFAULT_TIME_LIMIT, "names": [_board_names(), {1: "重拳"}],
			"boards": [me.board.to_dict() if me.board != null else {}, {}]})
	_view.play(result, ["我方", "训练假人"])
	_view.set_item_names(0, _board_names())
	_view.set_item_names(1, {1: "重拳"})
	_hint.text = "本场 %d 条事件，%.2f 秒。同一种子重放逐条相同。" % [
		result.log.size(), result.duration_sec()
	]
#endregion


## 截图工具的钩子：真打一场并停在中段，好让截图里有血条、飘字与事件条可看。
func demo_fill() -> void:
	_on_fight()
	_view.seek(9.0)
