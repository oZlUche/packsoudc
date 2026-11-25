## 355：这一局吃的那一锅（灰灯食堂，[Canteen]）。出征那一刻 [GameFlow] 把锅的汇总（[method Canteen.meal_of]）当运行时输入带进来，
## 锅里的食材在局外吃掉；没吃饭的局什么也不做。
##
## - 饱腹度：每走到一个**新节点**减 1（[signal MapTravel.moved] 的 first_visit；回头走到过的点不减，出生点不算）。
## - 剩 [member CanteenRules.warn_at] 时提醒一次（[signal warned]）；到 0 这锅的加成全部失效，直到这一局结束。
##   负重上限的那份在归零那一步走完之后才失效（下一回走到新节点时卸掉），免得半路突然超载。
## - 负重上限、耐力上限、耐力回复并进 [RunContext]（[method modify]，和科技同一条算式）；战斗中每秒回血是独立的一项
##   （[method regen_hp]，[method RunState.compile_player] 写进 [member CombatantSpec.meal_regen_hp]）。
## 进度跟这一局的存档走（`modules.meal`），读档不重算、不重扣。取它用 [method of]
class_name MealModule
extends RunModule

const ID := &"meal"

## 饱腹度变了（剩几点）
signal satiety_changed(satiety: int)
## 快饿了（剩 [member CanteenRules.warn_at] 点）
signal warned(satiety: int)
## 这锅吃完了（加成失效）
signal ended()

## 出征时这一锅的汇总：{"flat", "pct", "satiety", "count", "ids"}（[method Canteen.meal_of]）；空 = 没吃饭
var meal: Dictionary = {}
## 还剩几点饱腹
var satiety: int = 0
## 归零那一步：负重上限的加成留到走出这一步
var carry_grace: bool = false
var warned_once: bool = false
## 提醒的门槛（出征时从规矩里抄进来，读档照旧）
var warn_at: int = 1
var _wired: RunState = null


static func of(run: RunState) -> MealModule:
	return run.module(ID) as MealModule if run != null else null


func id() -> StringName:
	return ID


func install(run: RunState) -> void:
	if run == null:
		return
	_run = run
	if meal.is_empty():
		var input := run.module_input(ID)
		var m: Variant = input.get("meal", null)
		if m is Dictionary and int((m as Dictionary).get("count", 0)) > 0:
			meal = (m as Dictionary).duplicate(true)
			satiety = maxi(0, int(meal.get("satiety", 0)))
			warn_at = int(input.get("warn_at", 1))
	if _wired != run:
		_wired = run
		if run.travel != null:
			run.travel.moved.connect(func(_i: MoveIntent, first: bool):
				if first:
					step())


## 吃了饭没有
func has_meal() -> bool:
	return not meal.is_empty()


## 加成还在不在（饱腹 > 0）
func is_fed() -> bool:
	return has_meal() and satiety > 0


## 走到一个新节点：饱腹减 1。返回这一步之后还剩几点
func step() -> int:
	if not has_meal():
		return 0
	if satiety <= 0:
		if carry_grace:
			carry_grace = false
			_refresh()
		return 0
	satiety -= 1
	if satiety == 0:
		carry_grace = true
		satiety_changed.emit(satiety)
		ended.emit()
	else:
		satiety_changed.emit(satiety)
		if satiety <= warn_at and not warned_once:
			warned_once = true
			warned.emit(satiety)
	_refresh()
	return satiety


func _refresh() -> void:
	if _run != null:
		_run.refresh_encumbrance()     # 负重上限跟着变


## 395：这顿饭里器官的特性合计 {键: 数} —— 整局有效，不随饱腹失效（[OrganTraits]）
func traits() -> Dictionary:
	return (meal.get("traits", {}) as Dictionary) if has_meal() and meal.get("traits", {}) is Dictionary else {}


func _flat(stat: StringName) -> float:
	return float((meal.get("flat", {}) as Dictionary).get(String(stat), 0.0))


func _pct(stat: StringName) -> float:
	return float((meal.get("pct", {}) as Dictionary).get(String(stat), 0.0))


## 并进这一局的规则：负重上限（整数）、耐力上限与耐力回复（基线的加算 / 乘算）
func modify(ctx: RunContext) -> void:
	if not has_meal():
		return
	if is_fed() or carry_grace:
		ctx.carry_capacity_bonus += roundi(_flat(Canteen.CARRY))
		ctx.carry_capacity_mult += roundi(_pct(Canteen.CARRY))
	if not is_fed():
		return
	for stat in [BattleStats.MAX_STAMINA, BattleStats.REGEN_STAMINA]:
		if _flat(stat) != 0.0:
			ctx.stat_bonus[stat] = float(ctx.stat_bonus.get(stat, 0.0)) + _flat(stat)
		if _pct(stat) != 0.0:
			ctx.stat_mult[stat] = float(ctx.stat_mult.get(stat, 0.0)) + _pct(stat)


## 战斗中每秒回血：[固定值（每秒几点）, 百分数（每秒回生命上限的百分之几）]。饿了 = 都是 0
func regen_hp() -> Vector2:
	if not is_fed():
		return Vector2.ZERO
	return Vector2(_flat(BattleStats.REGEN_HP), _pct(BattleStats.REGEN_HP))


func to_dict() -> Dictionary:
	if not has_meal():
		return {}
	return {"meal": meal.duplicate(true), "satiety": satiety, "carry_grace": carry_grace, "warned": warned_once, "warn_at": warn_at}


func restore(d: Dictionary) -> void:
	var m: Variant = d.get("meal", null)
	if m is Dictionary:
		meal = (m as Dictionary).duplicate(true)
		satiety = maxi(0, int(d.get("satiety", 0)))
		carry_grace = bool(d.get("carry_grace", false))
		warned_once = bool(d.get("warned", false))
		warn_at = int(d.get("warn_at", 1))
