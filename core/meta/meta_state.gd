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

const SAVE_VERSION := 2
const WAREHOUSE_ID := 100
const BOARD_ID := 101
## 最近几局的账留几条
const HISTORY_MAX := 20

signal changed()

var rules: MetaRules = null
## 仓库：一块不要求包的格子
var warehouse: GridInventory = null
## 撤离带回来的棋盘（非包道具按原位置）；null = 没有
var board: GridInventory = null
## 图鉴：道具 id（字符串）→ 累计带出件数。点亮 = 计数 > 0
var codex: Dictionary = {}
## 激活的局外 buff（id）。谁来改它不写死：现在是局外屏的开关列表占位，将来是任务系统、局外科技
var active_buffs: Array[StringName] = []
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
	warehouse = GridInventory.new(warehouse_size(), WAREHOUSE_ID, false)
	warehouse.accept_filter = keeps


func warehouse_size() -> Vector2i:
	return rules.warehouse_size if rules != null else MetaRules.DEFAULT_SIZE


## 什么能存进局外（仓库、带回来的棋盘）。现在：不是包 —— 作者定的「包只计图鉴」。
## 「包」只是当前的承载媒介，将来可能删掉；那时删这一个分支，别处不要再问 is_bag
static func keeps(def: ItemDef) -> bool:
	return def != null and not def.is_bag


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
	var got := {"items": 0, "value": 0, "funds": 0, "lit": 0}
	if result == null:
		return got
	runs += 1
	if result.is_extracted():
		extractions += 1
		# 图鉴：每件各计一次（包也算），第一次带出算点亮
		for inst in result.carried:
			var key := String(inst.def.id)
			if int(codex.get(key, 0)) == 0:
				got["lit"] = int(got["lit"]) + 1
			codex[key] = int(codex.get(key, 0)) + 1
		# 棋盘原样带回：不要求包的格子，非包道具按原位置；uid 重新编号
		var size := result.board_size if result.board_size.x > 0 and result.board_size.y > 0 else RunState.BOARD_SIZE
		var back := GridInventory.new(size, BOARD_ID, false)
		back.begin_batch()
		for inst in result.carried:
			if not keeps(inst.def):
				continue
			inst.uid = _next_uid
			_next_uid += 1
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
	history.push_front(result.to_dict())
	if history.size() > HISTORY_MAX:
		history.resize(HISTORY_MAX)
	changed.emit()
	return got


func _buff_ids() -> Array:
	var out: Array = []
	for id in active_buffs:
		out.append(String(id))
	return out


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
	if board.item_count() == 0:
		board = null
	changed.emit()
	return out


## 带回来的棋盘上剩下的不要了
func discard_board() -> void:
	board = null
	changed.emit()


## 开 / 关一个局外 buff。返回现在开没开
func toggle_buff(id: StringName) -> bool:
	if active_buffs.has(id):
		active_buffs.erase(id)
	else:
		active_buffs.append(id)
	changed.emit()
	return active_buffs.has(id)


func codex_lit(id: StringName) -> bool:
	return int(codex.get(String(id), 0)) > 0


func codex_count(id: StringName) -> int:
	return int(codex.get(String(id), 0))
#endregion


#region 存档
func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"warehouse": warehouse.to_dict(),
		"board": board.to_dict() if board != null else null,
		"codex": codex.duplicate(),
		"active_buffs": _buff_ids(),
		"next_uid": _next_uid,
		"funds": funds, "score": score, "runs": runs, "extractions": extractions, "deaths": deaths,
		"best_value": best_value,
		"history": history.duplicate(true),
	}


## 读回来。版本不对返回 null（局外存档还只有开发期的，旧的作废）；定义被删的道具由容器的 from_dict 告警后丢弃。
## 仓库大小以存档里的为准（成长过的仓库不该被规则缩回去）；没有存档时才用规则的
static func from_dict(d: Dictionary, items: ItemDatabase, p_rules: MetaRules = null) -> MetaState:
	if int(d.get("version", -1)) != SAVE_VERSION:
		return null
	var m := MetaState.new(p_rules)
	var w = d.get("warehouse", null)
	if w is Dictionary:
		m.warehouse = GridInventory.from_dict(w, items)
		m.warehouse.id = WAREHOUSE_ID
		m.warehouse.accept_filter = keeps
	var b = d.get("board", null)
	if b is Dictionary:
		m.board = GridInventory.from_dict(b, items)
		m.board.id = BOARD_ID
		if m.board.item_count() == 0:
			m.board = null
	for key in d.get("codex", {}):
		m.codex[String(key)] = int((d["codex"] as Dictionary)[key])
	for id in d.get("active_buffs", []):
		m.active_buffs.append(StringName(String(id)))
	m._next_uid = int(d.get("next_uid", 1))
	for inst in m.warehouse.items():
		m._next_uid = maxi(m._next_uid, (inst as ItemInstance).uid + 1)
	if m.board != null:
		for inst in m.board.items():
			m._next_uid = maxi(m._next_uid, (inst as ItemInstance).uid + 1)
	m.funds = int(d.get("funds", 0))
	m.score = int(d.get("score", 0))
	m.runs = int(d.get("runs", 0))
	m.extractions = int(d.get("extractions", 0))
	m.deaths = int(d.get("deaths", 0))
	m.best_value = int(d.get("best_value", 0))
	for row in d.get("history", []):
		if row is Dictionary:
			m.history.append(MapGraph.normalize(row))
	return m
#endregion
