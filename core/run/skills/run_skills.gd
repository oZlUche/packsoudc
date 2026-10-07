## 一局里技能的账（作者定，报告 082）：每个技能还能用几次、还要走几步才能再用、哪些立了旗等下一场战斗、躲避还剩几步。
##
## 定义在角色上（[CharacterDef.skills]），这里只记状态，跟着存档走（`skills` 一节）。[RunState] 每走一步调一次 [method on_step]，
## 开打前调 [method prepare_battle] 让立了旗的技能改双方的战斗单位。本类不认识具体的技能。
class_name RunSkills
extends RefCounted

signal changed()

var run: RunState = null
var defs: Array[RunSkill] = []
## id → 还能用几次（-1 = 不限）
var uses_left: Dictionary = {}
## id → 还要走几步
var cooldowns: Dictionary = {}
## 立了旗等下一场战斗的技能 id，按用的顺序
var armed: Array[String] = []
## 躲避还剩几步（[EvadeSkill]）
var evade_left: int = 0


func setup(p_run: RunState, p_defs: Array[RunSkill]) -> void:
	run = p_run
	defs = p_defs
	for d in defs:
		if d == null or d.id == &"":
			continue
		if not uses_left.has(String(d.id)):
			uses_left[String(d.id)] = d.uses
		if not cooldowns.has(String(d.id)):
			cooldowns[String(d.id)] = 0


func skill(id: StringName) -> RunSkill:
	for d in defs:
		if d != null and d.id == id:
			return d
	return null


## 有主动一击的技能，按角色文件的顺序
func active_skills() -> Array[RunSkill]:
	var out: Array[RunSkill] = []
	for d in defs:
		if d != null and d.is_active():
			out.append(d)
	return out


func uses_of(id: StringName) -> int:
	return int(uses_left.get(String(id), 0))


func cooldown_of(id: StringName) -> int:
	return int(cooldowns.get(String(id), 0))


func is_armed(id: StringName) -> bool:
	return armed.has(String(id))


func evading() -> bool:
	return evade_left > 0


## 现在能不能用：空串 = 能；否则是原因
func can_use(id: StringName) -> String:
	var d := skill(id)
	if d == null:
		return "没有这个技能"
	if not d.is_active():
		return "「%s」是被动技能" % d.display_name
	if run != null and run.phase != RunState.Phase.ON_MAP:
		return "不在图上"
	if is_armed(id):
		return "「%s」已经准备好了，等下一场战斗" % d.display_name
	if uses_of(id) == 0:
		return "「%s」的次数用完了" % d.display_name
	if cooldown_of(id) > 0:
		return "「%s」还要走 %d 步" % [d.display_name, cooldown_of(id)]
	return ""


## 用一次。返回空串 = 用了；否则是原因。次数与冷却在这里记账，技能自己只做自己的事
func use(id: StringName) -> String:
	var why := can_use(id)
	if why != "":
		return why
	var d := skill(id)
	why = d.activate(run)
	if why != "":
		return why
	if uses_of(id) > 0:
		uses_left[String(id)] = uses_of(id) - 1
	cooldowns[String(id)] = maxi(0, d.cooldown_steps)
	if d.arms_battle():
		armed.append(String(id))
	changed.emit()
	return ""


## 走了一步：冷却少一步、躲避少一步
func on_step() -> void:
	var dirty := false
	for key in cooldowns.keys():
		var left := int(cooldowns[key])
		if left > 0:
			cooldowns[key] = left - 1
			dirty = true
	if evade_left > 0:
		evade_left -= 1
		dirty = true
	if dirty:
		changed.emit()


## 开打前：立了旗的技能依次改双方的战斗单位，旗子撤掉
func prepare_battle(me: CombatantSpec, enemy: CombatantSpec) -> void:
	if armed.is_empty():
		return
	for id in armed:
		var d := skill(StringName(id))
		if d != null:
			d.prepare_battle(me, enemy)
	armed.clear()
	changed.emit()


func to_dict() -> Dictionary:
	return {"uses": uses_left.duplicate(), "cooldowns": cooldowns.duplicate(), "armed": armed.duplicate(), "evade_left": evade_left}


func restore(d: Dictionary) -> void:
	for key in d.get("uses", {}):
		uses_left[String(key)] = int((d["uses"] as Dictionary)[key])
	for key in d.get("cooldowns", {}):
		cooldowns[String(key)] = int((d["cooldowns"] as Dictionary)[key])
	armed.clear()
	for id in d.get("armed", []):
		armed.append(String(id))
	evade_left = int(d.get("evade_left", 0))
