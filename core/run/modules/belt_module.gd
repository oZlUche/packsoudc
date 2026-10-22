## 腰带（147，作者定）：随身技能槽 —— 默认 3 格，`RunContext.belt_slots_bonus` 往上加（科技 / 角色 / buff）。
## 160 补一（作者定）：放的不再是道具，是**可堆叠的一次性技能**（[BeltSkillDef]）：存「id → 几个」，一种占一格、同种叠在一格里（不限个数），
## 格数限的是**种类数**；用一次少一个，数到零那格空出来。不落地、不进仓库、撤离时剩的作废（[RunResult] 不带它）。
##
## 101 的插件模型：状态、存档、接线全在这里，[RunState] 不认识腰带。接两条 hook：`belt_use`（界面用一个）、`belt_grant`（事件发几个）。
## 开局发的（章节 `starting_belt`、角色能力 / 局外 buff 的 `starting_belt` 效果、科技 `tech_belt_grant` 经模块输入 `grants`）在第一次装上时放进来。
## 取它用 [method of]
class_name BeltModule
extends RunModule

const ID := &"belt"

## 用掉了一个（技能 id）。里面变了（多了 / 少了 / 格数变了）发 Resource 自带的 `changed`，界面重画
signal used(skill_id: StringName)

## 默认几格（内容里可改；`RunContext.belt_slots_bonus` 加在上面）
@export var slots: int = 3

## 技能 id → 几个（有序：先来的在前面的格子）
var stacks: Dictionary = {}
var _saved: Dictionary = {}
var _installed := false


## 这一局的腰带模块（没装返回 null）
static func of(run: RunState) -> BeltModule:
	return run.module(ID) as BeltModule if run != null else null


func id() -> StringName:
	return ID


func describe() -> String:
	return UiText.t("log.belt_describe") % slot_count()


func install(run: RunState) -> void:
	if run == null:
		return
	_run = run
	if not _installed:
		_installed = true
		var saved: Variant = _saved.get("stacks", null)
		if saved is Dictionary:
			for k in (saved as Dictionary):
				var n := int((saved as Dictionary)[k])
				if n > 0 and BeltSkillDef.find(StringName(String(k))) != null:
					stacks[StringName(String(k))] = n
		elif not _saved.has("belt"):     # 147 的老档（腰带是格子、里面是道具）读出空腰带；新开局才发开局的
			_grant_start()
	run.hooks.register(&"belt_use", use)
	run.hooks.register(&"belt_grant", add)
	changed.emit()


## 现在该有几格（几种）：默认 + 一局的规则加的
func slot_count() -> int:
	var bonus := _run.hooks.run_context().belt_slots_bonus if _run != null else 0
	return maxi(1, slots + bonus)


## 格数变了（科技 / buff）：界面跟上。变小也不丢已经有的
func sync_slots() -> void:
	changed.emit()


## 腰带里的种类，按格子顺序
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in stacks:
		out.append(k)
	return out


func count_of(skill_id: StringName) -> int:
	return int(stacks.get(skill_id, 0))


## 一共几个（所有种类加起来）
func total() -> int:
	var n := 0
	for k in stacks:
		n += int(stacks[k])
	return n


## 还收不收这一种：已经有它（叠上去）或者还有空格
func can_add(skill_id: StringName) -> bool:
	if BeltSkillDef.find(skill_id) == null:
		return false
	return stacks.has(skill_id) or stacks.size() < slot_count()


## 放进 [param count] 个，返回放进了几个（0 = 不认识这种 / 格子满了）
func add(skill_id: StringName, count: int = 1) -> int:
	if count <= 0 or not can_add(skill_id):
		return 0
	stacks[skill_id] = count_of(skill_id) + count
	changed.emit()
	return count


## 能不能用这一种：空串 = 能，否则是原因（界面飘字）
func can_use(skill_id: StringName) -> String:
	var def := BeltSkillDef.find(skill_id)
	if def == null or count_of(skill_id) <= 0:
		return UiText.t("log.belt_none_left")
	if _run == null or _run.is_over():
		return UiText.t("log.run_over")
	var prebattle := _run.events != null and not _run.events.pending_battle.is_empty()
	if prebattle and not def.on_prebattle():
		return UiText.t("log.not_prebattle")
	if not prebattle and not def.on_map():
		return UiText.t("log.prebattle_only")
	for e in def.effects:
		if e == null:
			continue
		var why := e.blocked_reason(_run)
		if why != "":
			return why
	return ""


## 用掉一个：都能用才逐个生效，然后少一个（到零那格空出来）。返回空串 = 用了，否则是原因
func use(skill_id: StringName) -> String:
	var why := can_use(skill_id)
	if why != "":
		return why
	var def := BeltSkillDef.find(skill_id)
	var left := count_of(skill_id) - 1
	if left > 0:
		stacks[skill_id] = left
	else:
		stacks.erase(skill_id)
	for e in def.effects:
		if e != null:
			e.apply(_run)
	used.emit(skill_id)
	changed.emit()
	return ""


func to_dict() -> Dictionary:
	var d := {}
	for k in stacks:
		d[String(k)] = int(stacks[k])
	return {"stacks": d}


func restore(d: Dictionary) -> void:
	_saved = d.duplicate(true)


## 开局发的：章节的 `starting_belt`、角色能力 / 局外 buff 的 `starting_belt`（[member RunContext.belt_start]）、科技（模块输入 `grants`）。
## 放不下的种类不发（格子满了）
func _grant_start() -> void:
	var all: Array = []
	if _run.chapter != null:
		for sid in _run.chapter.starting_belt:
			all.append([sid, 1])
	var ctx := _run.hooks.run_context()
	if ctx != null:
		for sid in ctx.belt_start:
			all.append([sid, int(ctx.belt_start[sid])])
	var grants: Dictionary = _run.module_input(ID).get("grants", {})
	for sid in grants:
		all.append([StringName(String(sid)), int(grants[sid])])
	for pair in all:
		add(StringName(String(pair[0])), int(pair[1]))
