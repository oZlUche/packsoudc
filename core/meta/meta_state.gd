## 局外（跨 run）的状态（架构文档 8.2、15 节第 4 项；058 第 4 / 6 / 7 条）：仓库、带回来的背包、图鉴、钱、累计分数、几局几撤几败、最近几局的账。
##
## 一局里的东西在 [RunState]，跨局的在这里 —— 两者互不引用：一局结束了由 [RunResult] 算账，本类的 [method absorb] 决定什么留下。
## **保留规则只在那一个方法里**：撤离 = 图鉴每件计一次、非包道具按原位置带回一块「带回来的棋盘」、钱全带出；战败 = 全失。
##
## 三处按作者定的：
## - **仓库是格子**（大小是 [MetaRules] 里的数，随局外成长变），不要求包 —— 所有格子默认可用；
## - **撤离不直接进仓库**：棋盘原样带回来（包统一换成「默认背景」= 不要求包的格子，东西位置照旧），玩家在结算屏 / 局外屏拖或一键置入，
##   放不下就停下来提示；带回来的棋盘没清空之前不能开下一局；
## - **包只计图鉴**：什么能存进局外由 [method keeps] 一处说了算，将来删掉「包」这个媒介就删那一个分支。
##   225 补充一（作者 18:27 定包架）：包不进仓库，但进**包架**（[member rack]，不占格）：撤离时包连同棋盘一起带回，置入时货进仓库、包进包架。
##
## 局外有自己的 uid 空间：每局的 uid 从 1 重来，进来时重新编号。
class_name MetaState
extends RefCounted

## 110：v3 多了局外科技的等级与上交记录（[member tech_levels] / [member tech_deposits]）
const SAVE_VERSION := 3
const WAREHOUSE_ID := 100
const BOARD_ID := 101
## 225：包架的容器 id
const RACK_ID := 102
## 最近几局的账留几条
const HISTORY_MAX := 20

signal changed()

var rules: MetaRules = null
## 仓库：不要求包的格子，163 起分页（[Warehouse]，每页 [method warehouse_size] 大，页数由科技推算）
var warehouse: Warehouse = null
## 撤离带回来的棋盘（东西按原位置；225 起包也带回来、照旧铺着，这时它是要求包的棋盘）；null = 没有
var board: GridInventory = null
## 225：包架 —— 包 id → 几只（[BagRack]，不占格）。开局第二页从这里拿包，置入时包回到这里
var rack: BagRack = null
## 225：已经发过初始包的角色（第一次选这个角色时把 `starting_bags` 发进包架，像 [member MetaRules.first_kit]）
var bag_grants: Array[StringName] = []
## 图鉴：道具 id（字符串）→ 累计带出件数。点亮 = 计数 > 0
var codex: Dictionary = {}
## 175：引发过的元素反应（id）—— 百科的反应页点亮。打完一场由 [method note_reactions] 记
var reactions_seen: Array[StringName] = []
## 激活的局外 buff（id）。谁来改它不写死：现在是局外屏的开关列表占位，将来是任务系统、局外科技
var active_buffs: Array[StringName] = []
## 局外解锁（069）：难度、以后的角色 / 内容按 id 查。谁来解锁不写死：现在是局外屏的占位开关，将来是成长系统
var unlocks: Array[StringName] = []
## 088：拿到过的特殊道具（望远镜……）：不进背包、图鉴里点亮、代表一种能力。跟局外存档
var keepsakes: Array[StringName] = []
## 091：成就 —— id（字符串）→ 完成时刻（unix 秒）。完成给的解锁进 [member unlocks]
var achievements: Dictionary = {}
## 091：成就的条件顺手多记的数：按章节的撤离次数（章节 id 字符串 → 次）、击败核心的次数、打赢的场数
var chapter_extractions: Dictionary = {}
var boss_kills: int = 0
var battles_won: int = 0
## 091：看过「本图规则」卡的章节 id（第一次进图弹，之后不弹）
var seen_rules: Array[StringName] = []
## 166：看过的界面教程（[CoachOverlay] 的步骤 id，序章是 `prologue_map`）—— 每个存档位放一次，调试台里能重放
var coach_seen: Array[String] = []
## 218 补充一（作者定）：看过的出发前交代（[member ChapterDef.departure_event] 的事件 id）—— 每个存档位放一次，几章配同一个就只在先出发的那一章弹
var briefing_seen: Array[StringName] = []
## 091（计划书阶段 3）：剧情 / 事件的**局外旗标**（名字 → 数）。事件的条件 `has_flag` 看它、后果 `set_flag` 立它；跟局外存档。
## 「剧情推进到哪」「见过谁」就记在这里，营地对话、章节开场按它挑话
var flags: Dictionary = {}
## 110：局外科技等级 —— 科技 id（字符串）→ 已到第几级（没有 = 0）。怎么升见 [TechService]
var tech_levels: Dictionary = {}
## 110：上交中的材料 —— 科技 id（字符串）→ {道具 id（字符串）→ 已交件数}。上交即消耗；升级成功后清这一项
var tech_deposits: Dictionary = {}
## 118：科技给的局外 buff（id）—— 和开发开关的 [member active_buffs] 分开记，开局两份一起传给一局。谁加谁删见 [TechRunBuff]
var tech_buffs: Array[StringName] = []
## 118：科技给保险箱加的列 / 行（[TechSafeSize]），开局 `GameFlow.safe_size()` 加上
var safe_bonus: Vector2i = Vector2i.ZERO
## 160 补一：科技每局开局往腰带里发的随身技能（id → 几个，[TechBeltGrant]），开局交给 [BeltModule]。由科技等级推算，不入档
var belt_grants: Dictionary = {}
## 251：基地铺子的级数（铺子 id → 级，[TechFacility]）。由科技等级推算，不入档
var facility_levels: Dictionary = {}
## 251：集市这一轮的货（每格 {"id": 道具 id 字符串, "sold": bool}，[Market]）与上货用过几次种子；跟局外存档
var market_stock: Array[Dictionary] = []
var market_seed: int = 0
## 撤离带出来的钱累计。局外货币怎么花（15 节第 4 项）还没定，先攒着
var funds: int = 0
## 累计背出去的价值（6.4）
var score: int = 0
var runs: int = 0
var extractions: int = 0
var deaths: int = 0
var best_value: int = 0
## 最近几局的 [RunResult.to_dict]，新的在前
var history: Array[Dictionary] = []
var _next_uid: int = 1


func _init(p_rules: MetaRules = null) -> void:
	rules = p_rules
	warehouse = Warehouse.new(warehouse_size(), WAREHOUSE_ID)
	warehouse.accept_filter = keeps
	rack = BagRack.new(RACK_ID)


## 251：这间铺子几级（没有 = 0）
func facility_level(id: StringName) -> int:
	return int(facility_levels.get(id, 0))


## 一页仓库多大（163：扩建加页，页的大小不变）
func warehouse_size() -> Vector2i:
	return rules.warehouse_size if rules != null else MetaRules.DEFAULT_SIZE


## 什么能存进局外（仓库、带回来的棋盘）。现在：不是包 —— 作者定的「包只计图鉴」。
## 「包」只是当前的承载媒介，将来可能删掉；那时删这一个分支，别处不要再问 is_bag
static func keeps(def: ItemDef) -> bool:
	return def != null and (not def.is_bag or def.has_faith())     # 093：大地之神的护符是个 1 格的包，也是珍宝 —— 留


## 往仓库里发东西（局外的 uid 空间）：仓库空的第一局发第一套（[MetaRules.first_kit]）、将来的制作 / 教程关都走这里。
## 只收 [method keeps] 认的；放不下的丢掉。返回进了几件
func grant(defs: Array) -> int:
	var n := 0
	warehouse.begin_batch()
	for d in defs:
		var def := d as ItemDef
		if not keeps(def):
			continue
		var inst := ItemInstance.create(def, 0)
		inst.uid = _next_uid
		_next_uid += 1
		if warehouse.try_add(inst, true):
			n += 1
	warehouse.end_batch()
	if n > 0:
		changed.emit()
	return n


## 173（待定 2 A）：因版本更新作废的那一局，捞出来的道具字典（[member SaveReport.salvage]）放回仓库 —— 只收 [method keeps] 认的
## （和撤离一样，包不带回），换局外的 uid，按页序找空位、再不行临时加页；还放不下的按价值折进 funds 并记报告。返回进了几件
func salvage(raws: Array, items: ItemDatabase, report: SaveReport = null) -> int:
	var n := 0
	warehouse.begin_batch()
	for raw in raws:
		var inst := ItemInstance.from_dict(raw as Dictionary, items) if raw is Dictionary and items != null else null
		if inst == null or not keeps(inst.def):
			continue
		inst.uid = allocate_uid()
		if warehouse.rescue(inst) >= 0:
			n += 1
			continue
		var value := ItemValue.of_instance(inst)
		funds += value
		if report != null:
			report.refund(inst.def.id, value, "salvage")
	warehouse.end_batch()
	if n > 0:
		changed.emit()
	return n


## 局外号段里的下一个 uid（开局屏给初始包编号，免得和仓库里的撞号）
func allocate_uid() -> int:
	_next_uid += 1
	return _next_uid - 1


## 把一件东西放回仓库（开局屏取消带入）。保留它的 uid；放不下返回 false
func take_back(inst: ItemInstance) -> bool:
	if inst == null or not keeps(inst.def):
		return false
	_next_uid = maxi(_next_uid, inst.uid + 1)
	return warehouse.try_add(inst, true)

#region 包架（225）
## 包架上各种包几只：包 id（字符串）→ 只数
func bags() -> Dictionary:
	return rack.counts()


## 往包架里发包（局外的 uid 空间）。只收 [method BagRack.holds] 认的；返回进了几只
func grant_bags(defs: Array) -> int:
	var n := 0
	rack.begin_batch()
	for d in defs:
		var def := d as ItemDef
		if not BagRack.holds(def):
			continue
		var inst := ItemInstance.create(def, 0)
		inst.uid = allocate_uid()
		if rack.insert(inst):
			n += 1
	rack.end_batch()
	if n > 0:
		changed.emit()
	return n


## 第一次选这个角色：把它的 `starting_bags` 发进包架（每个存档位每个角色一次）。返回发了几只
func grant_starting_bags(ch: CharacterDef, items: ItemDatabase) -> int:
	if ch == null or items == null or bag_grants.has(ch.id):
		return 0
	bag_grants.append(ch.id)
	var defs: Array = []
	for id in ch.starting_bags:
		defs.append(items.get_def(id))
	var n := grant_bags(defs)
	changed.emit()
	return n


## 一只包回包架（开局屏拖回、取消带入）。保留它的 uid；不是包架收的返回 false
func put_bag(inst: ItemInstance) -> bool:
	if inst == null or not BagRack.holds(inst.def):
		return false
	_next_uid = maxi(_next_uid, inst.uid + 1)
	return rack.insert(inst)


## 卖包架上的一只（基地出售页双击）：按定价的 [param ratio] 进钱。返回得了多少；没这只 -1
func sell_bag(uid: int, ratio: float = 0.5) -> int:
	var inst := rack.get_item(uid)
	if inst == null or inst.is_locked_by_player():
		return -1
	var price := sell_price_of(inst, ratio)
	rack.remove(uid)
	funds += price
	changed.emit()
	return price
#endregion


#region 一局结束
## 一局结束了进来。返回这次进了什么：{"items": 带回棋盘的件数, "value", "funds", "lit": 新点亮的图鉴条目数}
func absorb(result: RunResult, death_refund_percent: int = 0) -> Dictionary:
	var got := {"items": 0, "value": 0, "funds": 0, "lit": 0, "safe": 0}
	if result == null:
		return got
	runs += 1
	battles_won += result.battles_won
	if result.boss_cleared:
		boss_kills += 1
	if result.is_extracted():
		extractions += 1
		if result.chapter_id != &"":
			chapter_extractions[String(result.chapter_id)] = chapter_extractions_of(result.chapter_id) + 1
		# 图鉴：每件各计一次（包也算），第一次带出算点亮
		for inst in result.carried:
			_record_codex(inst, got)
		# 棋盘原样带回，uid 重新编号。225：包也带回来、照旧铺着（这块棋盘就要求包），置入时包进包架；
		# 没带包回来的照旧是不要求包的格子
		var size := result.board_size if result.board_size.x > 0 and result.board_size.y > 0 else RunState.BOARD_SIZE
		var kept: Array[ItemInstance] = []
		for inst in result.carried:
			if _adopt(inst):
				kept.append(inst)
		var with_bags := kept.any(func(i: ItemInstance) -> bool: return BagRack.holds(i.def))
		kept.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool: return a.def.is_bag and not b.def.is_bag)     # 包先铺
		var back := GridInventory.new(size, BOARD_ID, with_bags)
		back.begin_batch()
		for inst in kept:
			if back.place(inst, inst.origin, inst.rotation) or back.try_add(inst, true):
				got["items"] = int(got["items"]) + 1
			elif BagRack.holds(inst.def) and rack.insert(inst):
				got["items"] = int(got["items"]) + 1
			elif keeps(inst.def) and warehouse.rescue(inst) >= 0:
				got["items"] = int(got["items"]) + 1
			else:
				push_warning("MetaState.absorb: %s 放不回带回来的棋盘，丢弃" % inst.def.id)
		back.end_batch()
		if board != null and board.item_count() > 0:
			# 上一次带回来的还没清（正常流程不会：没清空开不了新局）；并进去，一件不丢
			InventoryService.transfer_all(board, back)
		board = back if back.item_count() > 0 else null
		funds += result.balance
		score += result.value
		best_value = maxi(best_value, result.value)
		got["value"] = result.value
		got["funds"] = result.balance
	else:
		deaths += 1
		# 2026-10-22（作者定）：行囊 —— 战败时保住钱包里**剩的**那几成（撤离走的是上面那条 funds += balance）。
		# 底是「战败那一刻剩下的钱」，不是带进来的原始金额：中途花掉的钱已经花掉了，按原始金额退等于凭空造钱
		var refund := floori(float(maxi(0, result.balance)) * clampf(float(death_refund_percent), 0.0, 100.0) / 100.0)
		if refund > 0:
			funds += refund
			got["funds"] = refund
	# 092（作者定）：保险箱里的视为已带出 —— 战败也带得出。图鉴各计一次，进带回来的棋盘（没有就新开一块），放不下直接进仓库。
	# 224 补充二（作者 17:23）：战败没有置入那一页 —— 反过来，直接进仓库（包进包架），放不下的才进待置入的棋盘（基地「仓库」页清）
	if not result.safe_items.is_empty():
		var extracted := result.is_extracted()
		var size2 := result.board_size if result.board_size.x > 0 and result.board_size.y > 0 else RunState.BOARD_SIZE
		var back2 := board if board != null else GridInventory.new(size2, BOARD_ID, false)
		for inst in result.safe_items:
			_record_codex(inst, got)
			if not _adopt(inst):
				continue
			var kept := (back2.try_add(inst, true) or warehouse.try_add(inst, true)) if extracted \
				else (BagRack.holds(inst.def) and rack.insert(inst) or warehouse.try_add(inst, true) or back2.try_add(inst, true))
			if kept:
				got["items"] = int(got["items"]) + 1
				got["safe"] = int(got["safe"]) + 1
			else:
				push_warning("MetaState.absorb: 保险箱里的 %s 放不下，丢弃" % inst.def.id)
		board = back2 if back2.item_count() > 0 else null
		score += result.safe_value
		got["value"] = int(got["value"]) + result.safe_value
	history.push_front(result.to_dict())
	if history.size() > HISTORY_MAX:
		history.resize(HISTORY_MAX)
	changed.emit()
	return got


## 图鉴登记一件：计数加一，第一次带出算点亮（记进 got["lit"]）
func _record_codex(inst: ItemInstance, got: Dictionary) -> void:
	if inst.def.is_token():
		return     # 175：铸牌不是常规道具，不进图鉴
	var key := String(inst.def.id)
	if int(codex.get(key, 0)) == 0:
		got["lit"] = int(got["lit"]) + 1
	codex[key] = int(codex.get(key, 0)) + 1


## 251：铁匠铺打出来的一件也点亮图鉴（和带出来同一套计数）
func light_codex(def: ItemDef) -> void:
	if def == null or def.is_token():
		return
	codex[String(def.id)] = int(codex.get(String(def.id), 0)) + 1


## 一件东西要不要留进局外（[method keeps]；225：包架收的包也留）；留的换成局外号段的 uid。返回要不要留
func _adopt(inst: ItemInstance) -> bool:
	if not keeps(inst.def) and not BagRack.holds(inst.def):
		return false
	GrowthProfile.on_leave(inst)     # 207：带回基地 = 离开了作战棋盘，长到哪一阶都清零（reset_on_leave）
	inst.set_benched(false)     # 244：「不参战」是这一局的事，回了基地就摘掉
	inst.uid = _next_uid
	_next_uid += 1
	return true


## 带回来的棋盘还没清空：清空前不能开下一局（作者：提示玩家清空背包再配置）
func has_pending_board() -> bool:
	return board != null and board.item_count() > 0


## 一键置入：按栏位顺序逐件往仓库里放。177 补 1.1（作者 2026-10-16「当某个道具卡住时跳到下一个」）：放不下的跳过，后面的照放。
## 返回 {"moved": 放进几件, "left": 还剩几件, "stuck": 第一件放不下的名字（空 = 没卡）, "stuck_names": 全部放不下的名字（按栏位顺序、不重复）}
func store_all() -> Dictionary:
	var out := {"moved": 0, "left": 0, "stuck": "", "stuck_names": [] as Array[String]}
	if board == null:
		return out
	var order: Array = board.items()
	order.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		if a.def.is_bag != b.def.is_bag:
			return b.def.is_bag     # 225：货先走、包最后（包上的货搬空了包才收得起来）
		return a.origin.y < b.origin.y if a.origin.y != b.origin.y else a.origin.x < b.origin.x)
	for inst in order:
		var item := inst as ItemInstance
		if BagRack.holds(item.def):
			if board.is_bag_with_contents(item.uid):
				continue     # 上面的货没搬走（仓库满了），包留着垫它
			board.remove(item.uid)
			rack.insert(item)     # 225：包进包架
			out["moved"] = int(out["moved"]) + 1
		elif InventoryService.transfer_auto(board, item.uid, warehouse):
			out["moved"] = int(out["moved"]) + 1
		else:
			var name := Names.of_item(item)
			if String(out["stuck"]) == "":
				out["stuck"] = name
			if not (out["stuck_names"] as Array).has(name):
				(out["stuck_names"] as Array).append(name)
	out["left"] = board.item_count()
	# 作者 2026-10-13（一键置入后左边的棋盘消失、仓库跳到左边）：搬空了棋盘也留着（空的），离开结算屏才丢（[method drop_empty_board]）
	changed.emit()
	return out


## 离开结算屏：带回来的棋盘搬空了就丢掉（还有东西的留着，局外屏照旧提示置入）
func drop_empty_board() -> void:
	if board != null and board.item_count() == 0:
		board = null
		changed.emit()


## 带回来的棋盘上剩下的不要了。225：包不白丢 —— 棋盘上的包收进包架，货才没了
func discard_board() -> void:
	if board != null:
		for inst in board.items():
			if BagRack.holds((inst as ItemInstance).def):
				rack.insert(inst)
	board = null
	changed.emit()


func has_unlock(id: StringName) -> bool:
	return unlocks.has(id)


## 给一个局外解锁（序章通关解锁下一张 / 自由模式，083 / 114）。已经有的不重复；返回是不是新给的
func grant_unlock(id: StringName) -> bool:
	if id == &"" or unlocks.has(id):
		return false
	unlocks.append(id)
	changed.emit()
	return true


## 解锁 / 收回一个局外解锁（占位开关）。返回现在解没解锁
func toggle_unlock(id: StringName) -> bool:
	return _toggle(unlocks, id)


## 开 / 关一个局外 buff。返回现在开没开
func toggle_buff(id: StringName) -> bool:
	return _toggle(active_buffs, id)


## 有就去掉、没有就加上，发 changed；返回现在有没有
func _toggle(list: Array[StringName], id: StringName) -> bool:
	if list.has(id):
		list.erase(id)
	else:
		list.append(id)
	changed.emit()
	return list.has(id)


## 088：拿到一件特殊道具。已经有了返回 false
func grant_keepsake(id: StringName) -> bool:
	if id == &"" or keepsakes.has(id):
		return false
	keepsakes.append(id)
	changed.emit()
	return true


func has_keepsake(id: StringName) -> bool:
	return keepsakes.has(id)


## 175：记下这一场引发过的反应，返回新记下几种
func note_reactions(ids: Array) -> int:
	var n := 0
	for id in ids:
		var key := StringName(String(id))
		if key != &"" and not reactions_seen.has(key):
			reactions_seen.append(key)
			n += 1
	return n


func reaction_seen(id: StringName) -> bool:
	return reactions_seen.has(id)


func codex_lit(id: StringName) -> bool:
	return int(codex.get(String(id), 0)) > 0


func codex_count(id: StringName) -> int:
	return int(codex.get(String(id), 0))


#region 成就与规则卡（091）
func chapter_extractions_of(chapter_id: StringName) -> int:
	var n := int(chapter_extractions.get(String(chapter_id), 0))
	for old in IdAliases.old_names(IdAliases.CHAPTERS, chapter_id):     # 114：改名前记的账也算
		n += int(chapter_extractions.get(String(old), 0))
	return n


func has_achievement(id: StringName) -> bool:
	return achievements.has(String(id))


## 记一枚成就完成（时刻 = 现在）。已经有了返回 false
func complete_achievement(id: StringName) -> bool:
	if id == &"" or achievements.has(String(id)):
		return false
	achievements[String(id)] = int(Time.get_unix_time_from_system())
	changed.emit()
	return true


## 完成时刻（unix 秒）；没完成 0
func achievement_time(id: StringName) -> int:
	return int(achievements.get(String(id), 0))


func has_seen_rules(chapter_id: StringName) -> bool:
	if seen_rules.has(chapter_id):
		return true
	for old in IdAliases.old_names(IdAliases.CHAPTERS, chapter_id):     # 114：改名前看过的也算
		if seen_rules.has(old):
			return true
	return false


func mark_rules_seen(chapter_id: StringName) -> void:
	if chapter_id != &"" and not seen_rules.has(chapter_id):
		seen_rules.append(chapter_id)


## 091（作者定）：基地商店 —— 卖掉仓库里的一件，按定价的 [param ratio] 进钱（钱现在还没处花，先攒着）。返回得了多少；没这件 -1
func sell_item(uid: int, ratio: float = 0.5) -> int:
	var inst := warehouse.get_item(uid)
	if inst == null or inst.is_locked_by_player():     # 230：锁住的不卖
		return -1
	var price := sell_price_of(inst, ratio)
	warehouse.remove(uid)
	funds += price
	changed.emit()
	return price


## 244：金银按面值全额收（[param ratio] 对它不生效）；补充一：凡贵重品都是
static func sell_price(def: ItemDef, ratio: float = 0.5) -> int:
	if def != null and (def.is_valuable() or def.is_bullion()):
		return ItemValue.of(def)
	return maxi(0, floori(float(ItemValue.of(def)) * ratio)) if def != null else 0


## 246 补充二：一件实例的回收价 —— 和 [method sell_price] 同一套，价值按实例算（[method ItemValue.of_instance]：碎了的魔晶石按低两档）
static func sell_price_of(inst: ItemInstance, ratio: float = 0.5) -> int:
	if inst == null or inst.def == null:
		return 0
	var v := ItemValue.of_instance(inst)
	if inst.def.is_valuable() or inst.def.is_bullion():
		return v
	return maxi(0, floori(float(v) * ratio))


## 2026-10-22（作者定）：花掉一笔钱（带钱入局就这一个入口）。不够就一分不动、返回 false ——
## 和局内 [method Wallet.spend] 同一套语义，没有「透支一部分」这回事
func spend_funds(amount: int) -> bool:
	if amount <= 0:
		return true
	if amount > funds:
		return false
	funds -= amount
	changed.emit()
	return true


## 一键出售：稀有度 ≤ [param max_rarity] 的全卖（-1 = 全部）。返回 {"count", "funds"}
func sell_where(max_rarity: int, ratio: float = 0.5, tag: StringName = &"") -> Dictionary:
	var out := {"count": 0, "funds": 0}
	for it in _sellable(max_rarity, tag):
		var got := sell_item(it.uid, ratio)
		if got >= 0:
			out["count"] = int(out["count"]) + 1
			out["funds"] = int(out["funds"]) + got
	return out


## 230：一键出售这一档里锁着、被跳过的有几件
func locked_matching(max_rarity: int, tag: StringName = &"") -> int:
	var n := 0
	for inst in warehouse.items():
		var it := inst as ItemInstance
		if it.is_locked_by_player() and (max_rarity < 0 or it.rarity() <= max_rarity) and (tag == &"" or it.def.tags.has(tag)):
			n += 1
	return n


## 一键出售会卖几件、得多少（不动仓库）
func sell_preview(max_rarity: int, ratio: float = 0.5, tag: StringName = &"") -> Dictionary:
	var out := {"count": 0, "funds": 0}
	for it in _sellable(max_rarity, tag):
		out["count"] = int(out["count"]) + 1
		out["funds"] = int(out["funds"]) + sell_price_of(it, ratio)
	return out


## 一键出售会碰的那些：仓库里稀有度 ≤ [param max_rarity] 的（-1 = 全部），按仓库的顺序。
## 177 补 1.2：[param tag] 非空时还得带这个标签（和稀有度取交集）
func _sellable(max_rarity: int, tag: StringName = &"") -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	for inst in warehouse.items():
		var it := inst as ItemInstance
		if max_rarity >= 0 and it.rarity() > max_rarity:
			continue
		if tag != &"" and not it.def.tags.has(tag):
			continue
		if it.is_locked_by_player():
			continue     # 230：一键出售跳过锁住的
		out.append(it)
	return out


## 177 补 1.2（待定补 2 选 A）：一键出售的标签下拉列哪些 —— 仓库里现有道具带的、给玩家看的标签（内部标签不列），
## 按大类排（[constant TagRegistry.CATEGORY_ORDER]），类内按登记顺序
func sell_tags() -> Array:
	var seen := {}
	for inst in warehouse.items():
		for t in (inst as ItemInstance).def.tags:
			seen[t] = true
	var tags: Array = TagRegistry.shown(seen.keys())
	tags.sort_custom(func(a, b) -> bool:
		var ra := TagRegistry.category_rank(a)
		var rb := TagRegistry.category_rank(b)
		return ra < rb if ra != rb else TagRegistry.order_of(a) < TagRegistry.order_of(b))
	return tags


## 090（101 第 4 刀从开局屏搬来）：上一局带回来、还没置入的东西从带回来的棋盘挪进暂存那一栏，
## 记住各自原位（回主菜单时 [method return_stash] 原样放回）。返回 `uid → {"origin", "rot"}`。
## 225（补充二 §11.2）：包不倒地、直接进包架（`"rack": true`）—— 包不会白丢；回主菜单照样铺回原位
func take_board_to_stash(stash: ItemStash) -> Dictionary:
	var pending := {}
	if stash == null or board == null:
		return pending
	var order: Array = board.items()
	order.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool: return not a.def.is_bag and b.def.is_bag)     # 先拿货、再收包
	for inst in order:
		var it := inst as ItemInstance
		var origin := it.origin
		var rot := it.rotation
		if BagRack.holds(it.def):
			if board.remove(it.uid) != null and rack.insert(it):
				pending[it.uid] = {"origin": origin, "rot": rot, "rack": true}
		elif board.remove(it.uid) != null and stash.insert(it):
			pending[it.uid] = {"origin": origin, "rot": rot}
	return pending


## 090：回主菜单 —— 暂存那一栏里剩的按原位放回带回来的棋盘；原位放不下（不该发生）就找位置，再不行进仓库。
## 返回放不下也收不进仓库、只能丢掉的那几件的 id（正常是空）
func return_stash(stash: ItemStash, pending: Dictionary) -> Array[StringName]:
	var lost: Array[StringName] = []
	if stash == null:
		return lost
	for uid in pending:     # 225：先把收进包架的包铺回原位（还在包架上的才铺 —— 玩家拖上棋盘带走的就不管了）
		var rec: Dictionary = pending[uid]
		var bag := rack.get_item(int(uid)) if bool(rec.get("rack", false)) else null
		if bag == null:
			continue
		if board == null:
			board = GridInventory.new(RunState.BOARD_SIZE, BOARD_ID, true)
		rack.remove(bag.uid)
		if not board.place(bag, rec["origin"], int(rec.get("rot", 0))):
			rack.insert(bag)
	for inst in stash.items():
		var it := inst as ItemInstance
		stash.remove(it.uid)
		if board == null:
			board = GridInventory.new(RunState.BOARD_SIZE, BOARD_ID, false)
		var rec: Dictionary = pending.get(it.uid, {})
		var placed := rec.has("origin") and board.place(it, rec["origin"], int(rec.get("rot", 0)))
		if not placed and not board.try_add(it, true) and not take_back(it):
			lost.append(it.def.id)
	if board != null and board.item_count() == 0:
		board = null
	return lost


## 旗标现在的数；没立过 0
func flag(id: StringName) -> int:
	return int(flags.get(String(id), 0))


## 立 / 改一面旗；0 = 拔掉
func set_flag(id: StringName, value: int = 1) -> void:
	if id == &"":
		return
	if value == 0:
		flags.erase(String(id))
	else:
		flags[String(id)] = value
	changed.emit()


## 旗标加减；返回现在的数
func add_flag(id: StringName, delta: int) -> int:
	set_flag(id, flag(id) + delta)
	return flag(id)
#endregion
#endregion


#region 存档
func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"warehouse": warehouse.to_dict(),
		"board": board.to_dict() if has_pending_board() else null,     # 搬空了留着显示的空棋盘不存（读回来也是没有）
		"codex": codex.duplicate(),
		"active_buffs": _names_of(active_buffs),
		"unlocks": _names_of(unlocks),
		"keepsakes": _names_of(keepsakes),
		"bags": rack.to_save(),     # 225：包架只记包 id 与 uid
		"bag_grants": _names_of(bag_grants),
		"next_uid": _next_uid,
		"funds": funds, "score": score, "runs": runs, "extractions": extractions, "deaths": deaths,
		"best_value": best_value,
		"history": history.duplicate(true),
		"achievements": achievements.duplicate(),
		"chapter_extractions": chapter_extractions.duplicate(),
		"boss_kills": boss_kills, "battles_won": battles_won,
		"seen_rules": _names_of(seen_rules),
		"reactions_seen": _names_of(reactions_seen),     # 175
		"coach_seen": coach_seen.duplicate(),
		"briefing_seen": _names_of(briefing_seen),     # 218 补充一
		"flags": flags.duplicate(),
		"tech_levels": tech_levels.duplicate(),
		"tech_deposits": tech_deposits.duplicate(true),
		"market_stock": market_stock.duplicate(true),     # 251
		"market_seed": market_seed,
		# 120：tech_buffs、safe_bonus 和仓库页数（163）都由 tech_levels 推算，不入档（字段去掉、不升版本，098）
	}


static func _names_of(ids: Array[StringName]) -> Array:
	var out: Array = []
	for id in ids:
		out.append(String(id))
	return out


## 读回来。版本不对返回 null（局外存档还只有开发期的，旧的作废）；定义被删的道具由容器的 from_dict 告警后丢弃。
## 120（作者定）：**先读进度表、再算容量、最后装东西** —— 给了 [param tech_defs] 时先读 `tech_levels`，
## 在还空着的仓库上 [method TechService.derive] 出仓库页数（163）、保险箱、局外 buff，再按算出的页数把仓库物品放回去
## （原位放不下的按页序找空位，再不行临时加页，不丢；163 之前的单块老档按页切）。没给（测试直接读档）时按存档里的页数建，派生值留给调用方 derive
## 173：原位放不回的（形状 / 尺寸改了）—— 仓库里按页序找空位、再临时加页；带回的背包先在背包里找空位、再进仓库；
## 都不行按价值折进 funds。挪过的、折了的都记进 [param report]
static func from_dict(d: Dictionary, items: ItemDatabase, p_rules: MetaRules = null, tech_defs: Array = [],
		report: SaveReport = null) -> MetaState:
	if int(d.get("version", -1)) != SAVE_VERSION:
		return null
	var m := MetaState.new(p_rules)
	# 1. 进度表
	for key in d.get("tech_levels", {}):
		m.tech_levels[String(key)] = int((d["tech_levels"] as Dictionary)[key])
	for key in d.get("tech_deposits", {}):
		var got := {}
		var src = (d["tech_deposits"] as Dictionary)[key]
		if src is Dictionary:
			for item_id in src:
				got[String(item_id)] = int(src[item_id])
		m.tech_deposits[String(key)] = got
	# 2. 派生值（仓库还空着，长缩都不用顾忌）
	if not tech_defs.is_empty():
		TechService.derive(m, tech_defs)
	# 3. 装东西
	var lost: Array = []     # 173：哪儿都放不下的，最后折钱
	var w = d.get("warehouse", null)
	if w is Dictionary:
		m.warehouse = Warehouse.from_dict(w, items, m.warehouse_size(), m.warehouse.page_count() if not tech_defs.is_empty() else 0,
			report, lost)
		m.warehouse.accept_filter = keeps
	var b = d.get("board", null)
	if b is Dictionary:
		var lost_board: Array = []
		m.board = GridInventory.from_dict(b, items, Vector2i.ZERO, lost_board)
		m.board.id = BOARD_ID
		for inst in lost_board:
			if m.board.try_add(inst):
				if report != null:
					report.rehome(inst.def.id, "board", "board")
			elif keeps(inst.def) and m.warehouse.rescue(inst) >= 0:
				if report != null:
					report.rehome(inst.def.id, "board", "warehouse")
			else:
				lost.append(inst)
		if m.board.item_count() == 0:
			m.board = null
	for key in d.get("codex", {}):
		m.codex[String(key)] = int((d["codex"] as Dictionary)[key])
	for id in d.get("active_buffs", []):
		m.active_buffs.append(StringName(String(id)))
	for id in d.get("unlocks", []):
		m.unlocks.append(StringName(String(id)))
	for id in d.get("keepsakes", []):
		m.keepsakes.append(StringName(String(id)))
	m._next_uid = int(d.get("next_uid", 1))
	for inst in m.warehouse.items():
		m._next_uid = maxi(m._next_uid, (inst as ItemInstance).uid + 1)
	if m.board != null:
		for inst in m.board.items():
			m._next_uid = maxi(m._next_uid, (inst as ItemInstance).uid + 1)
	var rack_lost: Array = []
	m.rack = BagRack.from_save(d.get("bags", {}) as Dictionary if d.get("bags", {}) is Dictionary else {}, items, m.allocate_uid, RACK_ID, rack_lost)
	for inst in m.rack.items():
		m._next_uid = maxi(m._next_uid, (inst as ItemInstance).uid + 1)
	for id in rack_lost:
		push_warning("MetaState.from_dict: 包架上的 %s 内容里已经没有，丢弃" % id)
	for id in d.get("bag_grants", []):
		m.bag_grants.append(StringName(String(id)))
	m.funds = int(d.get("funds", 0))
	for inst in lost:
		var value := ItemValue.of_instance(inst as ItemInstance)
		m.funds += value
		if report != null:
			report.refund((inst as ItemInstance).def.id, value, "warehouse")
	m.score = int(d.get("score", 0))
	m.runs = int(d.get("runs", 0))
	m.extractions = int(d.get("extractions", 0))
	m.deaths = int(d.get("deaths", 0))
	m.best_value = int(d.get("best_value", 0))
	for key in d.get("achievements", {}):
		m.achievements[String(key)] = int((d["achievements"] as Dictionary)[key])
	for key in d.get("chapter_extractions", {}):
		m.chapter_extractions[String(key)] = int((d["chapter_extractions"] as Dictionary)[key])
	m.boss_kills = int(d.get("boss_kills", 0))
	m.battles_won = int(d.get("battles_won", 0))
	for id in d.get("seen_rules", []):
		m.seen_rules.append(StringName(String(id)))
	for id in d.get("coach_seen", []):
		m.coach_seen.append(String(id))
	for id in d.get("briefing_seen", []):
		m.briefing_seen.append(StringName(String(id)))
	for id in d.get("reactions_seen", []):
		m.reactions_seen.append(StringName(String(id)))
	for key in d.get("flags", {}):
		m.flags[String(key)] = int((d["flags"] as Dictionary)[key])
	for row in d.get("history", []):
		if row is Dictionary:
			m.history.append(MapGraph.normalize(row))
	# 251：集市的货 —— 173：改了名的按新名，退役的（道具库里没有了）那一格去掉
	for row in d.get("market_stock", []):
		if not (row is Dictionary):
			continue
		var id := IdAliases.item(StringName(String((row as Dictionary).get("id", ""))))
		if items != null and items.get_def(id) == null:
			continue
		m.market_stock.append({"id": String(id), "sold": bool((row as Dictionary).get("sold", false))})
	m.market_seed = int(d.get("market_seed", 0))
	return m
#endregion
