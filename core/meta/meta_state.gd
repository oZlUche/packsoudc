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
##
## 局外有自己的 uid 空间：每局的 uid 从 1 重来，进来时重新编号。
class_name MetaState
extends RefCounted

## 110：v3 多了局外科技的等级与上交记录（[member tech_levels] / [member tech_deposits]）
const SAVE_VERSION := 3
const WAREHOUSE_ID := 100
const BOARD_ID := 101
## 最近几局的账留几条
const HISTORY_MAX := 20

signal changed()

var rules: MetaRules = null
## 仓库：不要求包的格子，163 起分页（[Warehouse]，每页 [method warehouse_size] 大，页数由科技推算）
var warehouse: Warehouse = null
## 撤离带回来的棋盘（非包道具按原位置）；null = 没有
var board: GridInventory = null
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

#region 一局结束
## 一局结束了进来。返回这次进了什么：{"items": 带回棋盘的件数, "value", "funds", "lit": 新点亮的图鉴条目数}
func absorb(result: RunResult) -> Dictionary:
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
		# 棋盘原样带回：不要求包的格子，非包道具按原位置；uid 重新编号
		var size := result.board_size if result.board_size.x > 0 and result.board_size.y > 0 else RunState.BOARD_SIZE
		var back := GridInventory.new(size, BOARD_ID, false)
		back.begin_batch()
		for inst in result.carried:
			if not _adopt(inst):
				continue
			if not back.place(inst, inst.origin, inst.rotation) and not back.try_add(inst, true):
				push_warning("MetaState.absorb: %s 放不回带回来的棋盘，丢弃" % inst.def.id)
				continue
			got["items"] = int(got["items"]) + 1
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
	# 092（作者定）：保险箱里的视为已带出 —— 战败也带得出。图鉴各计一次，进带回来的棋盘（没有就新开一块），放不下直接进仓库
	if not result.safe_items.is_empty():
		var size2 := result.board_size if result.board_size.x > 0 and result.board_size.y > 0 else RunState.BOARD_SIZE
		var back2 := board if board != null else GridInventory.new(size2, BOARD_ID, false)
		for inst in result.safe_items:
			_record_codex(inst, got)
			if not _adopt(inst):
				continue
			if back2.try_add(inst, true) or warehouse.try_add(inst, true):
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


## 一件东西要不要留进局外（[method keeps]）；留的换成局外号段的 uid。返回要不要留
func _adopt(inst: ItemInstance) -> bool:
	if not keeps(inst.def):
		return false
	inst.uid = _next_uid
	_next_uid += 1
	return true


## 带回来的棋盘还没清空：清空前不能开下一局（作者：提示玩家清空背包再配置）
func has_pending_board() -> bool:
	return board != null and board.item_count() > 0


## 一键置入：按栏位顺序逐件往仓库里放，放不下就停在那一件（作者：中途停止并提示）。
## 返回 {"moved": 放进几件, "left": 还剩几件, "stuck": 卡住的那件的名字（空 = 没卡）}
func store_all() -> Dictionary:
	var out := {"moved": 0, "left": 0, "stuck": ""}
	if board == null:
		return out
	var order: Array = board.items()
	order.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		return a.origin.y < b.origin.y if a.origin.y != b.origin.y else a.origin.x < b.origin.x)
	for inst in order:
		var item := inst as ItemInstance
		if InventoryService.transfer_auto(board, item.uid, warehouse):
			out["moved"] = int(out["moved"]) + 1
		else:
			out["stuck"] = item.def.display_name
			break
	out["left"] = board.item_count()
	# 作者 2026-10-13（一键置入后左边的棋盘消失、仓库跳到左边）：搬空了棋盘也留着（空的），离开结算屏才丢（[method drop_empty_board]）
	changed.emit()
	return out


## 离开结算屏：带回来的棋盘搬空了就丢掉（还有东西的留着，局外屏照旧提示置入）
func drop_empty_board() -> void:
	if board != null and board.item_count() == 0:
		board = null
		changed.emit()


## 带回来的棋盘上剩下的不要了
func discard_board() -> void:
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
	if inst == null:
		return -1
	var price := sell_price(inst.def, ratio)
	warehouse.remove(uid)
	funds += price
	changed.emit()
	return price


static func sell_price(def: ItemDef, ratio: float = 0.5) -> int:
	return maxi(0, floori(float(ItemValue.of(def)) * ratio)) if def != null else 0


## 一键出售：稀有度 ≤ [param max_rarity] 的全卖（-1 = 全部）。返回 {"count", "funds"}
func sell_where(max_rarity: int, ratio: float = 0.5) -> Dictionary:
	var out := {"count": 0, "funds": 0}
	for it in _sellable(max_rarity):
		var got := sell_item(it.uid, ratio)
		if got >= 0:
			out["count"] = int(out["count"]) + 1
			out["funds"] = int(out["funds"]) + got
	return out


## 一键出售会卖几件、得多少（不动仓库）
func sell_preview(max_rarity: int, ratio: float = 0.5) -> Dictionary:
	var out := {"count": 0, "funds": 0}
	for it in _sellable(max_rarity):
		out["count"] = int(out["count"]) + 1
		out["funds"] = int(out["funds"]) + sell_price(it.def, ratio)
	return out


## 一键出售会碰的那些：仓库里稀有度 ≤ [param max_rarity] 的（-1 = 全部），按仓库的顺序
func _sellable(max_rarity: int) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	for inst in warehouse.items():
		var it := inst as ItemInstance
		if max_rarity >= 0 and it.def.rarity > max_rarity:
			continue
		out.append(it)
	return out


## 092（作者定；101 第 4 刀从 [GameFlow] 搬来）：离开结算屏时地上没背出来的一键出售。这里只算不卖
static func left_behind_preview(result: RunResult, ratio: float = 0.5) -> Dictionary:
	var out := {"count": 0, "funds": 0}
	if result == null or not result.is_extracted():
		return out
	for inst in result.left_items:
		out["count"] = int(out["count"]) + 1
		out["funds"] = int(out["funds"]) + sell_price((inst as ItemInstance).def, ratio)
	return out


## 真卖：钱进局外、清单清掉（**只卖一次**）。返回卖了几件、得多少
func sell_left_behind(result: RunResult, ratio: float = 0.5) -> Dictionary:
	var got := left_behind_preview(result, ratio)
	if int(got["count"]) > 0:
		funds += int(got["funds"])
		result.left_items.clear()
		changed.emit()
	return got


## 090（101 第 4 刀从开局屏搬来）：上一局带回来、还没置入的东西从带回来的棋盘挪进暂存那一栏，
## 记住各自原位（回主菜单时 [method return_stash] 原样放回）。返回 `uid → {"origin", "rot"}`
func take_board_to_stash(stash: ItemStash) -> Dictionary:
	var pending := {}
	if stash == null or board == null:
		return pending
	for inst in board.items():
		var it := inst as ItemInstance
		var origin := it.origin
		var rot := it.rotation
		if board.remove(it.uid) != null and stash.insert(it):
			pending[it.uid] = {"origin": origin, "rot": rot}
	return pending


## 090：回主菜单 —— 暂存那一栏里剩的按原位放回带回来的棋盘；原位放不下（不该发生）就找位置，再不行进仓库。
## 返回放不下也收不进仓库、只能丢掉的那几件的 id（正常是空）
func return_stash(stash: ItemStash, pending: Dictionary) -> Array[StringName]:
	var lost: Array[StringName] = []
	if stash == null:
		return lost
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
		"flags": flags.duplicate(),
		"tech_levels": tech_levels.duplicate(),
		"tech_deposits": tech_deposits.duplicate(true),
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
	for id in d.get("reactions_seen", []):
		m.reactions_seen.append(StringName(String(id)))
	for key in d.get("flags", {}):
		m.flags[String(key)] = int((d["flags"] as Dictionary)[key])
	for row in d.get("history", []):
		if row is Dictionary:
			m.history.append(MapGraph.normalize(row))
	return m
#endregion
