## 容器屏（063；作者：搜索和战利品本质上是同一个界面，只是装载的生成规则不同）。
##
## 左边是渐进揭示的容器（[LootView]），右边是自己的棋盘与地上，同一层拖拽盖着三块 —— 亮出来的直接拖走。
## 装的是**尸体容器 / 待拾取**（payload 带 `container`）时只有「全部拾取」与关闭（原「收起」）—— 收起只是回地图，没拿的留在这个点上，
## 地图上「回到这个点」能再开，走了才没（084）；
## 装的是**搜索会话**（payload 带 `session`）时容器是会话的收获箱：这一屏就是**刚搜的那一次**（084 作者定的循环：事件屏选「搜索」
## 自动搜一次 → 这里亮出来拖走 → 「关闭」回事件屏再搜 / 走）；没亮的只对新来的走时间线；遭遇那一次不开这一屏。
## 在这一屏亮过的（`flow.seen_loot`）再开不重新揭示。
##
## 棋盘美术（UI替换美术，作者 2026-10-19 19:02 定稿）：左边容器按种类换外框（搜索 藤编 / 宝箱 铁角或金角 / 敌人战利品 生皮 /
## BOSS 黑铁金钉 + 纹章），右边背包细皮带框；外框是九宫格（中段平铺），浅灰内垫在图里，格缝由棋盘视图画。
## 标题不写字（标题分隔行还在），右上角两颗圆钮：最小化（原「回到地图」）、关闭（原「关闭」/「收起」）；
## 「全部拾取」是火漆签；快速搜索、状态行、耐力行都去掉了。摆位按 `assets/ui/board/layout.json` 的设计像素，见 [method _layout]
extends GameScreen

const BOARD_DIR := "res://assets/ui/board/"
const BOARD_LAYOUT := BOARD_DIR + "layout.json"
## 外框切图四周多留的透明边（描边与抖动），外框看得见的边 = 节点往里缩这么多
const FRAME_BLEED := 8.0
## 定稿摆位（面板左上角为原点，设计像素）：外框到面板左右边、外框上沿到面板上沿（标题分隔行 52 + 14）、两块外框之间
const EDGE := 26.0
const TOP := 66.0
const MID := 200.0
## 背包外框下沿到面板下沿；容器外框下沿到「全部拾取」看得见的上沿；「全部拾取」切图的左上角离面板左下角
const BELOW_PLAYER := 68.0
const ABOVE_TAKE := 62.0
const TAKE_AT := Vector2(22.0, -102.0)
## 「全部拾取」切图里看得见的那块从切图上沿往下多少、多高（切图 250 × 82）
const TAKE_INSET := 8.0
const TAKE_VISIBLE := 62.0
## 右上角圆钮：中心离面板右上角（关闭在右、最小化在它左边 48）
const CLOSE_AT := Vector2(-46.0, 33.0)
const MINIMIZE_AT := Vector2(-94.0, 33.0)

var _container: GridInventory = null
var _session: SearchSession = null
var _loot: LootView
## 回话（拿不下放在地上、合成了……）：平时空着，不写状态
var _line: Label
var _take_btn: IconButton
var _close_btn: IconButton
var _minimize_btn: IconButton = null
## 090：这是不是 BOSS 的战利品屏（Esc 不收）
var _boss: bool = false
var _inv: InventoryPanelScript = null
## 棋盘美术：左边容器的外框种类（`search` / `chest_iron` / `chest_gold` / `corpse` / `boss`）与摆位用的那几块
var _kind := ""
var _layout_data: Dictionary = {}
var _stage: Control
var _loot_box: Control
var _loot_frame: NinePatchRect
var _player_frame: NinePatchRect
var _extras: Array[TextureRect] = []


func open(payload: Dictionary) -> void:
	_session = payload.get("session", null)
	if _session != null:
		_container = _session.haul_box
	else:
		_container = payload.get("container", null)
		if _container == null:
			_container = flow.run.pending_loot
	_layout_data = board_layout()
	var panel := _centered_panel(Vector2(0, 0))
	_stage = Control.new()
	_stage.name = "BoardStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(_stage)
	_frame_title("")     # 棋盘美术：标题不写字，分隔行照旧

	_boss = _session == null and flow.run != null and flow.run.boss_cleared
	var chest := _session != null and NodeEvents.effective_type(_session.node) == &"chest"     # 154：宝箱开锁后的那一次搜索
	_kind = frame_kind_of(_session != null, chest, ChestPlacer.rarity_of(_session.node) if chest else 0, _boss)
	_loot_frame = _nine(_kind)
	_stage.add_child(_loot_frame)
	_player_frame = _nine("player")
	_stage.add_child(_player_frame)

	_loot = LootView.new()
	_loot.label_font = font
	_loot.inventory = _container
	_loot.seams = _layout_data.get("cell_seams", {})
	# 每档稀有度搜几秒是节点规则里的数（058 第 5 条）：会话有自己的规则，尸体容器用这一局的
	var search_rules: SearchRules = _session.rules if _session != null else (flow.run.node_rules.search if flow.run != null and flow.run.node_rules != null else null)
	if search_rules != null and not search_rules.reveal_seconds.is_empty():
		_loot.rules = search_rules
	_loot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_loot_box = ScrollBox.wrap(_loot)     # 反馈：容器太高时竖向滚动，不撑出窗口
	_stage.add_child(_loot_box)
	_line = _label("", 13, UiPalette.FG)
	_stage.add_child(_line)
	# 090：长说明在悬浮提示里，按钮上只写动作（棋盘美术：字画在火漆签上）
	_take_btn = IconButton.make_art(BOARD_DIR, "take_all", "全部拾取", "全部拾取\n先进背包，放不下的到地上", take_all)
	_stage.add_child(_take_btn)
	if _session != null:
		_close_btn = _corner("btn_close", "×", "关闭\n回到事件：再搜 / 走", close_search)
		_minimize_btn = _corner("btn_minimize", "－", "回到地图\n不结束：回到这个点接着搜（Esc）", to_map)
	else:
		_close_btn = _corner("btn_close", "×", "收起\n" + ("撤离结算" if _boss else "剩下的留在这里；走了会落到这个点的地上（Esc）"), to_map)

	_inv = _mount_bag(_stage, _loot, func(text: String): _log_line(text), _container)     # 084：棋盘上双击 → 放回容器
	_inv.hide_stamina()
	_inv.board_view.seams = _layout_data.get("cell_seams", {})
	_stage.move_child(_inv, _player_frame.get_index() + 1)
	# 084：容器里双击 → 试着放进背包（没空间就提示并到地上）；没亮的不动。
	# 玩家自己的东西放回容器不会变成「未知」：LootView 把绑定之后才出现的都当亮过
	_loot.item_double_clicked.connect(func(_v: ContainerView, uid: int): quick_take(uid))
	_tip.can_show = func(_v: ContainerView, uid: int) -> bool: return not _loot.is_locked(uid)     # 没亮的不说是什么
	# 没亮的只能在容器里挪位（换「下一个」是谁），拖出去要等亮了 —— 作者定的。
	# 只锁容器里没亮的那几件：自己棋盘上的包与道具随便挪（084 修：原来按 is_revealed 判，把玩家自己的东西也卡住了）
	_drag.drop_filter = func(inst: ItemInstance, target: ItemContainer) -> bool:
		return not _loot.is_locked(inst.uid) or target == _container

	_loot.item_revealed.connect(func(uid: int):
		flow.seen_loot[uid] = true     # 084：收起再开不重新揭示
		_refresh())
	_loot.reveal_finished.connect(_refresh)
	if _session != null:
		_session.searched.connect(_on_searched)
		_session.haul_changed.connect(func(box: GridInventory):
			_container = box
			_loot.inventory = box
			if _inv != null:
				_inv.quick_target = box
			_layout())
		_container.changed.connect(_refresh)
		# 084：这一屏打开时那一次已经搜完了：亮新来的，见过的不重放
		_loot.mark_revealed(flow.seen_loot.keys())
		_loot.start_reveal()
	elif _container != null:
		_loot.mark_revealed(flow.seen_loot.keys())
		_container.changed.connect(_on_container_changed)
		# 084：最后一件拿在手上时容器已经空了，放下（或取消）之后再判一次要不要关
		_drag.drag_finished.connect(func(_uid: int, _dropped: bool): _on_container_changed())
		_loot.start_reveal()
	_stage.item_rect_changed.connect(_layout)
	_loot.resized.connect(_layout)
	_inv.board_view.resized.connect(_layout)
	_layout()
	_refresh()


#region 棋盘美术
## 定稿的摆位与切图参数（`layout.json`）；读不出给空字典（外框退回不画，摆位照常）
static func board_layout() -> Dictionary:
	if not FileAccess.file_exists(BOARD_LAYOUT):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BOARD_LAYOUT))
	return parsed if parsed is Dictionary else {}


## 左边容器用哪种外框：搜索 藤编；宝箱开锁后那一次 稀有及以上金角、以下铁角；战利品 BOSS 黑铁，其余 生皮
static func frame_kind_of(is_search: bool, chest: bool, chest_rarity: int, boss: bool) -> String:
	if is_search:
		if chest:
			return "chest_gold" if chest_rarity >= 2 else "chest_iron"
		return "search"
	return "boss" if boss else "corpse"


## 这种外框的看得见的边比格子宽多少（切图的 cells_offset 减去四周的透明边）
func frame_pad(kind: String) -> float:
	var piece: Dictionary = (_layout_data.get("pieces", {}) as Dictionary).get(kind, {})
	return float(piece.get("cells_offset", FRAME_BLEED + 32.0)) - FRAME_BLEED


func frame_kind() -> String:
	return _kind


func _nine(kind: String) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.name = "Frame_" + kind
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var piece: Dictionary = (_layout_data.get("pieces", {}) as Dictionary).get(kind, {})
	n.texture = EventImage.load_texture(BOARD_DIR + String(piece.get("file", "frame_%s.png" % kind)))
	var m := int(piece.get("margin", 70))
	n.patch_margin_left = m
	n.patch_margin_top = m
	n.patch_margin_right = m
	n.patch_margin_bottom = m
	n.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	n.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	return n


## 右上角圆钮（56 的切图按 0.72 画）；缺图写字
func _corner(art: String, fallback: String, tip: String, on_press: Callable) -> IconButton:
	var b := IconButton.make_art(BOARD_DIR, art, fallback, tip, on_press)
	var side := 56.0 * float((_layout_data.get("corner_buttons", {}) as Dictionary).get("scale", 0.72))
	b.custom_minimum_size = Vector2(side, side)
	b.size = b.custom_minimum_size
	_stage.add_child(b)
	return b


## 这一屏的面板该多大：左右各 [constant EDGE]，中间 [constant MID]；高取两边要的较大的那个（8 列背包 + 6 列容器 = 1188 × 526）
func panel_size() -> Vector2:
	var lp := frame_pad(_kind)
	var pp := frame_pad("player")
	var loot := _loot_cells_size() + Vector2(lp, lp) * 2.0
	var player := Vector2(_inv.board_view.inventory.size) * _inv.board_view.cell_px + Vector2(pp, pp) * 2.0 if _inv != null else Vector2.ZERO
	var w := EDGE + loot.x + MID + player.x + EDGE
	var h := maxf(TOP + loot.y + ABOVE_TAKE + TAKE_VISIBLE + EDGE + 6.0, TOP + player.y + BELOW_PLAYER)
	return Vector2(w, h)


## 容器那块看得见的格子区（太高时是滚动窗口那么高）
func _loot_cells_size() -> Vector2:
	if _loot == null or _loot.inventory == null:
		return Vector2.ZERO
	var rows := mini(_loot.inventory.size.y, int(_loot_box.get_meta("max_rows", 10)) if _loot_box != null else 10)
	return Vector2(_loot.inventory.size.x, rows) * _loot.cell_px


## 按面板左上角的设计像素摆：内容区在面板里的偏移是排版之后才知道的，摆的时候减掉
func _layout() -> void:
	if _stage == null or _overlay_frame == null or _inv == null:
		return
	var want := panel_size()
	if _overlay_frame.custom_minimum_size != want:
		_overlay_frame.custom_minimum_size = want
	var off := _stage.global_position - _overlay_frame.global_position
	var lp := frame_pad(_kind)
	var pp := frame_pad("player")
	var loot_cells := Vector2(EDGE + lp, TOP + lp) - off
	var loot_size := _loot_cells_size()
	_loot_box.position = loot_cells
	_place_frame(_loot_frame, loot_cells, loot_size, lp)
	var player_size := Vector2(_inv.board_view.inventory.size) * _inv.board_view.cell_px
	var player_cells := Vector2(want.x - EDGE - pp - player_size.x, TOP + pp) - off
	_inv.position = player_cells - _inv.board_view.position
	_place_frame(_player_frame, player_cells, player_size, pp)
	_place_extras(loot_cells - Vector2(lp, lp), loot_size + Vector2(lp, lp) * 2.0)
	_take_btn.position = Vector2(TAKE_AT.x, want.y + TAKE_AT.y) - off
	_line.position = _take_btn.position + Vector2(_take_btn.custom_minimum_size.x + 12.0, TAKE_INSET + TAKE_VISIBLE * 0.5 - 10.0)
	var side := _close_btn.custom_minimum_size
	_close_btn.position = Vector2(want.x, 0.0) + CLOSE_AT - side * 0.5 - off
	if _minimize_btn != null:
		_minimize_btn.position = Vector2(want.x, 0.0) + MINIMIZE_AT - side * 0.5 - off


func _place_frame(n: NinePatchRect, cells: Vector2, cells_size: Vector2, pad: float) -> void:
	var bleed := pad + FRAME_BLEED
	n.position = cells - Vector2(bleed, bleed)
	n.size = cells_size + Vector2(bleed, bleed) * 2.0


## 宝箱上下边各两条铁条（中心在外框宽的 1/3、2/3，贴上沿 / 下沿）；BOSS 上沿正中一枚纹章（底边 = 上沿往下 28）
func _place_extras(outer: Vector2, outer_size: Vector2) -> void:
	for e in _extras:
		e.queue_free()
	_extras.clear()
	if _kind.begins_with("chest_"):
		var band := EventImage.load_texture(BOARD_DIR + "chest_band_%s.png" % _kind.trim_prefix("chest_"))
		if band != null:
			for fx in [1.0 / 3.0, 2.0 / 3.0]:
				var cx: float = outer.x + outer_size.x * fx
				_extra(band, Vector2(cx - band.get_width() * 0.5, outer.y - 4.0))
				_extra(band, Vector2(cx - band.get_width() * 0.5, outer.y + outer_size.y - band.get_height() + 4.0))
	elif _kind == "boss":
		var crest := EventImage.load_texture(BOARD_DIR + "boss_crest.png")
		if crest != null:
			_extra(crest, Vector2(outer.x + (outer_size.x - crest.get_width()) * 0.5, outer.y + 28.0 - crest.get_height()))


func _extra(tex: Texture2D, at: Vector2) -> void:
	var r := TextureRect.new()
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = at
	r.size = tex.get_size()
	_stage.add_child(r)
	_stage.move_child(r, _loot_frame.get_index() + 1)
	_extras.append(r)
#endregion


#region 公开动作
## 084：关闭搜索屏回到事件屏（再搜一次 / 走由事件的选项定）
func close_search() -> bool:
	return flow.close_search()


## 084：容器里双击一件：亮了的才动；先试背包（自动找位），放不下提示并到地上。返回去了哪（"board" / "storage" / ""）
func quick_take(uid: int) -> String:
	if _container == null or _loot.is_locked(uid):
		return ""
	var inst := _container.get_item(uid)
	if inst == null:
		return ""
	var where := _take_to_player(_container, uid)
	if where == "board":
		_log_line("「%s」放进了背包" % inst.def.display_name)
	elif where == "storage":
		_log_line("背包里没有空间放「%s」，放在了地上" % inst.def.display_name)
	return where


## 回话写在「全部拾取」旁边那一行（棋盘美术：不再有状态行与搜索记录）
func _log_line(text: String) -> void:
	_line.text = text


func skip_reveal() -> void:
	_loot.skip()


## 全拿走（先全亮）：123 先进背包棋盘，放不下的到地上（162：先包后件，落地从原格起飞）。屏不自动关（084 作者定），设置「拿走最后一件后自动关闭」开了才关（_on_container_changed 管）
func take_all() -> void:
	_loot.reveal_all()
	# 162：放不下落地的那几件从它在这块棋盘上的格子起飞（进了背包的起点搬完清掉，不留给下一次落地）
	var ground: ItemStash = flow.run.storage
	var starts := {}
	for inst in _container.items():
		var it := inst as ItemInstance
		starts[it.uid] = _loot.global_position + _loot.cell_origin_px(it.origin)
	ground.landing_from.merge(starts, true)
	InventoryService.transfer_all_prefer(_container, flow.run.board, ground)
	for uid in starts:
		if not ground.has_item(uid):
			ground.landing_from.erase(uid)
	_refresh()


## 搜索会话：离开这个点的搜索（收获交到待拾取）。待拾取：同「收起」—— 剩下的留在这个点上，走了才没（084）
func leave() -> void:
	if _session != null:
		_session.leave()
	else:
		to_map()


## 084：收起回地图，什么都不结束：会话还开着 / 没拿的还在这个点上，地图上「回到这个点」能再开。
## 待拾取已经空了就不必留：直接丢掉（回地图）
func to_map() -> bool:
	if _session == null and _container != null and _container.item_count() == 0 and flow.run != null and flow.run.pending_loot == _container:
		flow.discard_loot()
		return true
	return flow.hide_overlay()


func loot_view() -> LootView:
	return _loot


## 090：Esc = 收起回地图（最小化）。BOSS 的战利品屏不接：那儿「收起」= 不要剩下的直接撤离，不能一个 Esc 误触
func escape() -> bool:
	if _boss:
		return false
	return to_map()


func is_search() -> bool:
	return _session != null
#endregion


func _on_searched(_found: Array[StringName], met: Dictionary) -> void:
	if met.is_empty():
		_loot.start_reveal()
	_refresh()


## 待拾取空了才关：拿在手上的那一件不算空（拖拽层先记「正在拖」再从容器拿走），放下之后 drag_finished 再来判一次
func _on_container_changed() -> void:
	if _container == null or _session != null:
		return
	_refresh()
	# 084（作者定）：拿完了默认**不**自动关，手动关；设置里「拿走最后一件后自动关闭」开了才关
	if flow.settings != null and flow.settings.loot_auto_close and _container.item_count() == 0 and not _drag.is_dragging() \
			and flow.run != null and flow.run.pending_loot == _container:
		flow.discard_loot()


## 棋盘美术：状态行去掉了，揭示与拿走都画在棋盘上；容器长大了（搜索收获箱换大的）外框跟着摆
func _refresh() -> void:
	if _loot != null and _container != null and _loot.inventory != _container:
		_loot.inventory = _container
