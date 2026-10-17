## 全局倒计时（092，作者定）与带入预算（094，作者定）：一局总共只有这么多行动点，
## 归零 = 行动失败（当场战败结算，保险箱里的照样带出）。过半时关掉**离出生点最近的免费撤离点**，
## 从仓库带进来的东西超出预算就按「每超多少价值 −1 步」换掉倒计时。
##
## 101 第 1 刀：数（上限、剩多少、关哪个撤离点）、带入价值、存档、接线全在这里，[RunState] 不认识倒计时。
## 取它用 [method of]；开局屏在还没有一局时算给玩家看的那几条走静态方法（[method limit_for] 等）。
class_name CountdownModule
extends RunModule

const ID := &"countdown"

## 只发一次的提醒（撤离点关了）：地图屏听
signal notice(text: String)

## 这一局从仓库带进来的道具总价值（094；超带换倒计时看它）。开局由 `module_inputs[&"countdown"]["carry_value"]` 给
var carry_value: int = 0
var _run: RunState = null


## 这一局的倒计时模块（没装返回 null）
static func of(run: RunState) -> CountdownModule:
	return run.module(ID) as CountdownModule if run != null else null


func id() -> StringName:
	return ID


func describe() -> String:
	return "全局倒计时：一局只能走这么多步，归零就是行动失败"


func install(run: RunState) -> void:
	if run == null:
		return
	_run = run
	if carry_value == 0:
		carry_value = int(run.module_input(ID).get("carry_value", 0))
	# 092：倒计时过半关一个撤离点（按这张图规模、算上超带之后的倒计时）。读档回来图上已经标着，不重标
	if run.chapter != null and run.chapter.closing_extract and closing_extract_id() < 0:
		PaidExtracts.mark_closing(run.map, limit())
	if not run.stepped.is_connected(_on_stepped):
		run.stepped.connect(_on_stepped)


#region 这一局的数
## 这一局的倒计时总数（行动点）；0 = 没有
func limit() -> int:
	return limit_for(_run.chapter, _run.scale_id(), carry_value) if _run != null else 0


func has_countdown() -> bool:
	return limit() > 0


## 还剩几步；没有倒计时 -1。按行动点算：走一步（边的 action_cost，通常 1）减一，原地耗时也减
func left() -> int:
	if not has_countdown():
		return -1
	var spent := _run.travel.clock.total if _run.travel != null and _run.travel.clock != null else 0
	return maxi(0, limit() - spent)


## 094：带入预算（0 = 不限）
func budget() -> int:
	return budget_for(_run.chapter, _run.scale_id()) if _run != null else 0


## 094：超带换掉了几步倒计时
func penalty_steps() -> int:
	return penalty_for(_run.chapter, _run.scale_id(), carry_value) if _run != null else 0


## 094：超带了多少价值（不超 0）
func over_value() -> int:
	return over_for(_run.chapter, _run.scale_id(), carry_value) if _run != null else 0


## 倒计时过半时关掉的那个撤离点的 id；没有 -1
func closing_extract_id() -> int:
	if _run == null or _run.map == null:
		return -1
	for id in _run.map.node_ids():
		if PaidExtracts.closes_at(_run.map.get_node(id)) >= 0:
			return id
	return -1


## 这个撤离点关了没（倒计时剩的 ≤ 它的 closes_at）
func extract_closed(node: MapNode) -> bool:
	var at := PaidExtracts.closes_at(node)
	return has_countdown() and at >= 0 and left() <= at
#endregion


#region 开局之前就能算的（开局屏按章节 / 规模 / 要带的东西算给玩家看）
## 这一章这个规模的规模档（没有 null）
static func scale_profile_of(p_chapter: ChapterDef, sid: StringName) -> Resource:
	if p_chapter == null or p_chapter.map_source == null:
		return null
	var cfg: Resource = p_chapter.map_source.generator_config
	if cfg == null or not cfg.has_method("scale_by_id"):
		return null
	return cfg.call("scale_by_id", sid) if sid != &"" else (cfg.call("scale") if cfg.has_method("scale") else null)


## 不算超带的倒计时（规模档写了用它的，没写用章节的）
static func base_limit_for(p_chapter: ChapterDef, sid: StringName) -> int:
	if p_chapter == null:
		return 0
	var p := scale_profile_of(p_chapter, sid)
	if p != null and "step_limit" in p and int(p.get("step_limit")) > 0:
		return int(p.get("step_limit"))
	return p_chapter.step_limit


## 094（作者定）：带入预算（规模档 > 章节；0 = 不限）
static func budget_for(p_chapter: ChapterDef, sid: StringName) -> int:
	if p_chapter == null:
		return 0
	var p := scale_profile_of(p_chapter, sid)
	if p != null and "carry_budget" in p and int(p.get("carry_budget")) > 0:
		return int(p.get("carry_budget"))
	return p_chapter.carry_budget


## 094：超带多少价值（不超 0）
static func over_for(p_chapter: ChapterDef, sid: StringName, value: int) -> int:
	var b := budget_for(p_chapter, sid)
	return maxi(0, value - b) if b > 0 else 0


## 094：超带换掉几步倒计时：每超 carry_over_cost 价值 −1
static func penalty_for(p_chapter: ChapterDef, sid: StringName, value: int) -> int:
	if p_chapter == null or p_chapter.carry_over_cost <= 0:
		return 0
	@warning_ignore("integer_division")
	return over_for(p_chapter, sid, value) / p_chapter.carry_over_cost


## 094：算上超带的倒计时；有倒计时的至少留 1
static func limit_for(p_chapter: ChapterDef, sid: StringName, value: int) -> int:
	var base := base_limit_for(p_chapter, sid)
	if base <= 0:
		return 0
	return maxi(1, base - penalty_for(p_chapter, sid, value))
#endregion


func to_dict() -> Dictionary:
	return {"carry_value": carry_value}


func restore(d: Dictionary) -> void:
	carry_value = int(d.get("carry_value", 0))


## 走完一步看一眼：归零就是行动失败
func _on_stepped(_node_id: int, _reason: StringName) -> void:
	if _run == null or _run.phase != RunState.Phase.ON_MAP or not has_countdown():
		return
	var rest := left()
	var closing := closing_extract_id()
	if closing >= 0 and rest == PaidExtracts.closes_at(_run.map.get_node(closing)):
		notice.emit("有一个撤离点关闭了")
	if rest <= 0:
		_run.fail(&"time_out")
