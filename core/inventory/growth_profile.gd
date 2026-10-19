## 207（作者定）：自然系专属的【生长】—— 种子 → 茎叶 → 绽放（也可以是树苗 → 小树 → 大树，阶数不限）。
##
## 定义只写「几阶、每阶走几步、每阶叫什么 / 加什么 / 锁什么」；**走了几步、到了第几阶、抽中了哪条额外效果记在实例上**
## （[member ItemInstance.state] 的 `growth_ticks` / `growth_stage` / `growth_bonus`，和魔晶石耐久同一条路，存档原样带走）。
## 什么时候长由 [GrowthModule] 管（全局倒计时每走一步长一步）；加成由编译器并进来（[BattleCompiler] 第 4b 步旁）；
## 锁由棋盘兑现（[method GridInventory.is_locked]）。只有带 `faith:nature` 的道具能长（导入器拦），自然之神不是当前信仰就休眠：不长、加成不算、锁保留
class_name GrowthProfile
extends Resource

const TICKS_KEY := "growth_ticks"
const STAGE_KEY := "growth_stage"
const BONUS_KEY := "growth_bonus"
## 只有这一位神的道具能长（导入器拦）
const FAITH_TAG := &"faith:nature"

## 种子之后的各阶，按序
@export var stages: Array[GrowthStage] = []
## 第 0 阶（还没长）在悬浮窗里叫什么
@export var stage0_name: String = "种子"
@export var stage0_names: Dictionary = {}
## 离开作战棋盘（进地上 / 容器 / 仓库）计数清零、阶段归零；假 = 带着阶段走（树苗挪盆）
@export var reset_on_leave: bool = true


#region 读实例
## 现在第几阶（0 = 还是种子）
static func stage_of(inst: ItemInstance) -> int:
	if inst == null or inst.def == null or inst.def.growth == null:
		return 0
	return clampi(int(inst.state.get(STAGE_KEY, 0)), 0, inst.def.growth.stages.size())


## 这一阶里已经走了几步
static func ticks_of(inst: ItemInstance) -> int:
	if inst == null or inst.def == null or inst.def.growth == null:
		return 0
	return maxi(0, int(inst.state.get(TICKS_KEY, 0)))


## 现在这一阶的定义；还是种子返回 null
static func current(inst: ItemInstance) -> GrowthStage:
	var s := stage_of(inst)
	return inst.def.growth.stages[s - 1] if s > 0 else null


## 下一阶；长满了返回 null
static func next_stage(inst: ItemInstance) -> GrowthStage:
	if inst == null or inst.def == null or inst.def.growth == null:
		return null
	var s := stage_of(inst)
	return inst.def.growth.stages[s] if s < inst.def.growth.stages.size() else null


## 这件扎根了（拖不动、挪不走）
static func locks_item(inst: ItemInstance) -> bool:
	var st := current(inst)
	return st != null and st.locks_item()


## 这件连它所在的包一起扎根了
static func locks_bag(inst: ItemInstance) -> bool:
	var st := current(inst)
	return st != null and st.locks_bag()


## 抽中的额外效果（当前阶的池子里，按记下的下标）
static func bonuses_of(inst: ItemInstance) -> Array[GrowthBonus]:
	var out: Array[GrowthBonus] = []
	var st := current(inst)
	if st == null:
		return out
	for i in inst.state.get(BONUS_KEY, []):
		var k := int(i)
		if k >= 0 and k < st.bonus_pool.size() and st.bonus_pool[k] != null:
			out.append(st.bonus_pool[k])
	return out


## 名字前缀（还是种子 = 空）
static func prefix_of(inst: ItemInstance, lang: String = "") -> String:
	var st := current(inst)
	return st.prefix_in(lang) if st != null else ""


## 这一阶叫什么
static func stage_name(inst: ItemInstance, lang: String = "") -> String:
	var st := current(inst)
	if st != null:
		return st.name_in(lang)
	return Names.pick(inst.def.growth.stage0_names, inst.def.growth.stage0_name, lang) if inst != null and inst.def != null and inst.def.growth != null else ""
#endregion


#region 改实例
## 长 [param delta] 步。一次最多升一阶，剩下的不结转。升了阶返回 true（抽额外效果用 [param seed]）
static func grow(inst: ItemInstance, delta: int, seed: int = 0) -> bool:
	var nxt := next_stage(inst)
	if nxt == null or delta <= 0:
		return false
	var ticks := ticks_of(inst) + delta
	if ticks < nxt.after:
		inst.state[TICKS_KEY] = ticks
		return false
	var s := stage_of(inst) + 1
	inst.state[STAGE_KEY] = s
	inst.state[TICKS_KEY] = 0
	inst.state.erase(BONUS_KEY)
	var picks: Array = []
	picks.append_array(pick_bonuses(nxt, seed, inst.uid, s))
	if not picks.is_empty():
		inst.state[BONUS_KEY] = picks
	return true


## 清零（离开棋盘）。有记录才动，返回动了没有
static func reset(inst: ItemInstance) -> bool:
	if inst == null:
		return false
	var had := inst.state.has(TICKS_KEY) or inst.state.has(STAGE_KEY) or inst.state.has(BONUS_KEY)
	inst.state.erase(TICKS_KEY)
	inst.state.erase(STAGE_KEY)
	inst.state.erase(BONUS_KEY)
	return had


## 离开这一局（带回基地、进仓库）：`reset_on_leave` 的清零
static func on_leave(inst: ItemInstance) -> bool:
	if inst == null or inst.def == null or inst.def.growth == null or not inst.def.growth.reset_on_leave:
		return false
	return reset(inst)


## 到阶时抽哪几条（下标升序）：只看种子、uid、阶 —— 同一颗种子同一局重开抽到的一样
static func pick_bonuses(st: GrowthStage, seed: int, uid: int, stage: int) -> Array[int]:
	var out: Array[int] = []
	var n := mini(st.bonus_count, st.bonus_pool.size())
	if n <= 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, uid, "growth", stage])
	var pool: Array[int] = []
	for i in st.bonus_pool.size():
		pool.append(i)
	for _k in n:
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	out.sort()
	return out
#endregion


## 存档读回来是浮点（3.0）：存回去得还是整数（存档逐字节往返，同 148 的 charges）
static func normalize_state(state: Dictionary) -> void:
	for k in [TICKS_KEY, STAGE_KEY]:
		if state.has(k):
			state[k] = int(state[k])
	if state.has(BONUS_KEY):
		var ints: Array = []
		for v in state[BONUS_KEY]:
			ints.append(int(v))
		state[BONUS_KEY] = ints
