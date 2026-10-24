## 一局的结算（架构文档 8 节 / 6.4 / 15 节第 4 项，M6）：撤离了背出去什么、值多少；战败了什么都没有。
##
## 只读：从结束了的 [RunState] 里算一份账，不动它。谁保留、谁进仓库是 [MetaState.absorb] 的事（保留规则在那一处）。
##
## **只算棋盘上的。** 地上的道具 = 不存在（3.4）：它是关卡内的临时摆放区，撤离时连同里面的东西一起消失。
## 224：撤离时地上的就没了 —— 不卖、不提示、不记账（092 的「一键出售」撤销）。
class_name RunResult
extends RefCounted

var outcome: StringName = &""       # &"extracted" / &"defeated"
var reason: StringName = &""        # RunState.end_reason：extract / vitality_depleted / boss_lost
var run_seed: int = 0
var chapter_id: StringName = &""
var chapter_name: String = ""
## 行动点总数、踩过的点数、打赢 / 打输几场
var steps: int = 0
var visited: int = 0
var battles_won: int = 0
var battles_lost: int = 0
## 224：其中精英 / 首领、翻过的搜索点（同一个点只算一次）、合成几次
var elite_won: int = 0
var boss_won: int = 0
var searches: int = 0
var crafts: int = 0
## 撤离时剩多少钱（战败为 0：钱也没了）
var balance: int = 0
## 背出去的：撤离时棋盘上的全部（含包）。战败为空
var carried: Array[ItemInstance] = []
## 棋盘多大（带回局外时原样重建）
var board_size: Vector2i = Vector2i.ZERO
## carried 的价值之和（6.4）
var value: int = 0
## 091：这一局击败了核心（BOSS）没有 —— 成就的条件看它
var boss_cleared: bool = false
## 092（作者定）：保险箱里的 —— **不管撤离还是战败都带出**；结算屏单独一格画它们（layout 记每件的定义 / 位置 / 朝向）
var safe_items: Array[ItemInstance] = []
var safe_size: Vector2i = Vector2i(3, 3)
var safe_value: int = 0
var safe_layout: Array[Dictionary] = []
## 104 信力节奏的量尺：这一局每次加点的记录（[member FaithPower.history]）；结算屏一行、开发模式导 CSV
var faith_history: Array = []
## 结算屏那一行（「信力节奏：日神 第 3 步到 1 阶……」）；没攒过信力为空
var faith_pace: String = ""


## 结束了的一局才算得出账；没结束返回 null
static func settle(state: RunState) -> RunResult:
	if state == null or not state.is_over():
		return null
	var r := RunResult.new()
	r.outcome = &"extracted" if state.phase == RunState.Phase.EXTRACTED else &"defeated"
	r.reason = state.end_reason
	r.run_seed = state.run_seed
	r.chapter_id = state.chapter.id if state.chapter != null else &""
	r.chapter_name = Names.of(state.chapter) if state.chapter != null else ""
	r.steps = state.travel.clock.total if state.travel != null and state.travel.clock != null else 0
	for id in state.map.node_ids():
		if state.map.get_node(id).is_visited():
			r.visited += 1
	r.battles_won = int(state.tally.get("battles_won", 0))
	r.battles_lost = int(state.tally.get("battles_lost", 0))
	r.elite_won = int(state.tally.get("elite_won", 0))
	r.boss_won = int(state.tally.get("boss_won", 0))
	r.searches = int(state.tally.get("searches", 0))
	r.crafts = int(state.tally.get("crafts", 0))
	r.board_size = state.board.size if state.board != null else Vector2i.ZERO
	r.boss_cleared = state.boss_cleared
	if state.faith_power != null:
		r.faith_history = state.faith_power.history_to_array()
		r.faith_pace = FaithPower.pace_line(r.faith_history, state.faith_defs)
	if r.outcome == &"extracted":
		r.balance = state.wallet.balance if state.wallet != null else 0
		for inst in state.board.items():
			var item := inst as ItemInstance
			r.carried.append(item)
			if not item.def.is_bullion():     # 244：金银是花钱买的，不算搜刮成绩（钱照样回仓库）
				r.value += ItemValue.of_in(item, state.board)     # 209：百宝囊里的按倍率
	var safe := SafeModule.of(state)     # 101：保险箱的状态在模块里
	if safe != null and safe.inventory != null:
		r.safe_size = safe.inventory.size
		for inst in safe.inventory.items():
			var item := inst as ItemInstance
			r.safe_items.append(item)
			if not item.def.is_bullion():     # 244：同上
				r.safe_value += ItemValue.of(item.def)
			r.safe_layout.append({"def": item.def, "origin": item.origin, "rotation": item.rotation})
	return r


## 104：开发模式把信力记录导成 CSV（`user://faith_history_<seed>.csv`）。返回写到的路径；没记录或写不了返回空
func export_faith_csv(dir: String = "user://") -> String:
	if faith_history.is_empty():
		return ""
	var path := dir.path_join("faith_history_%d.csv" % run_seed)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(FaithPower.history_csv(faith_history))
	f.close()
	return path


func is_extracted() -> bool:
	return outcome == &"extracted"


## 给局外历史记的一行：只写 id（3.1），不写实例
func to_dict() -> Dictionary:
	var ids: Array = []
	for inst in carried:
		ids.append(String(inst.def.id))
	return {
		"outcome": String(outcome), "reason": String(reason), "seed": run_seed, "chapter": String(chapter_id),
		"steps": steps, "visited": visited, "battles_won": battles_won, "battles_lost": battles_lost,
		"balance": balance, "value": value, "items": ids,
		"safe": safe_items.size(), "safe_value": safe_value,
	}
