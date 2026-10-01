## 神坛与信仰级效果（093 / 095，作者定）：站在开着神坛的点上可以**献祭**（销毁道具换信力）或者做一次
## **特殊操作**（蛮神献祭生命上限、日神祈祷……）—— 两者共享这个点上的一次机会，用掉就关；走开也关。
## 激活信仰到了阶的效果（[FaithPerk]）在这里取：编译战斗单位、算战利品、踩点、献祭之后各有一处回调。
## 095 的赐福也在这里：走一步时棋盘上的东西可能受赐福，战利品 / 搜索翻到的普通道具按概率换成赐福版。
##
## 101 第 1 刀：神坛的状态（开在哪个点、哪些点用过）、仪式的账（次数、改过的基线）、存档、接线全在这里，
## [RunState] 不认识神坛。信仰本身（[FaithState] / [FaithPower]：谁激活、几阶、多少信力）仍然在 [RunState] 上。
## 取它用 [method of]。
class_name AltarModule
extends RunModule

const ID := &"altar"

## 神坛上献祭 / 特殊操作 / 受赐福了，给日志与屏的一句（名字不能叫 changed：[Resource] 已经有一个）
signal noted(text: String)
## 095：一件东西受了赐福（包内转化 / 神坛 / 事件）
signal item_blessed(inst: ItemInstance, faith_id: StringName)

## 这一次在哪个点上开着（-1 = 没有；走开就关）
var node: int = -1
## 哪些点上已经用过那一次机会（献祭与特殊操作共享）
var used: Dictionary = {}
## 093：特殊操作攒的账（蛮神献祭生命上限的次数、日神祈祷的次数……）：键 → 数，跟存档；效果构件自己读写
var rituals: Dictionary = {}
## 093：特殊操作改的基线（蛮神：生命上限 −、耐力上限 +、急速 +），并进 [method RunState.effective_baseline]
var stat_bonus: Dictionary = {}
var _run: RunState = null


## 这一局的神坛模块（没装返回 null）
static func of(run: RunState) -> AltarModule:
	return run.module(ID) as AltarModule if run != null else null


## 仪式的账（效果构件常用；没装神坛返回一份空的，写进去也没人看）
static func rituals_of(run: RunState) -> Dictionary:
	var m := of(run)
	return m.rituals if m != null else {}


func id() -> StringName:
	return ID


func describe() -> String:
	return "神坛：献祭换信力，或者做一次特殊操作（每个点一次机会）"


func install(run: RunState) -> void:
	if run == null:
		return
	_run = run
	run.hooks.register(&"bless_substitute", bless_substitute)     # 095：战利品 / 搜索的赐福替代
	if run.events != null:
		if not run.events.altar_opened.is_connected(_on_altar_opened):
			run.events.altar_opened.connect(_on_altar_opened)
	if not run.leaving.is_connected(_on_leaving):
		run.leaving.connect(_on_leaving)
	if not run.stepped.is_connected(_on_stepped):
		run.stepped.connect(_on_stepped)
	if run.travel != null and not run.travel.moved.is_connected(_on_moved):
		run.travel.moved.connect(_on_moved)


#region 信仰级效果（093）
## 现在生效的信仰级效果（激活信仰的、tier ≤ 现在的阶）
func perks() -> Array[FaithPerk]:
	var def := _run.active_faith() if _run != null else null
	return def.perks_at(_run.active_faith_tier()) if def != null else [] as Array[FaithPerk]


## 某一种效果现在生效没有（按注册表名字，`stat_mod` 之类）；没有 null
func perk(type_name: StringName) -> FaithPerk:
	for p in perks():
		if ContentSchema.registry_name_of(p) == type_name:
			return p
	return null
#endregion


#region 神坛
## 神坛可用：站在开着神坛的点上、这一次还没用过特殊操作、有激活的信仰
func is_open() -> bool:
	if _run == null or _run.travel == null:
		return false
	return node >= 0 and _run.travel.current_id == node and not used.has(node) and _run.active_faith() != null


## 献祭：这些道具（从棋盘 / 暂存区 / 祭品台拿来的实例）销毁换信力。
## 返回 {"points", "tier_before", "tier_after", "log", "count"}；不能献的跳过
func offer(insts: Array, at_node: MapNode = null) -> Dictionary:
	var def := _run.active_faith() if _run != null else null
	var tier := _run.active_faith_tier() if _run != null else -1
	var out := {"points": 0, "tier_before": tier, "tier_after": tier, "log": [] as Array[String], "count": 0}
	if def == null:
		return out
	var defs: Array = []
	for inst in insts:
		var it := inst as ItemInstance
		if it == null or it.def == null:
			continue
		var v := def.offering_value(it.def)
		if v <= 0:
			continue
		out["points"] = int(out["points"]) + v
		out["count"] = int(out["count"]) + 1
		defs.append(it.def)
	if int(out["points"]) <= 0:
		return out
	out["tier_after"] = _run.faith_power.add_points(def.id, int(out["points"]))
	(out["log"] as Array[String]).append("献祭 %d 件，%s +%d 信力" % [int(out["count"]), Names.of(def), int(out["points"])])
	if int(out["tier_after"]) > int(out["tier_before"]):
		(out["log"] as Array[String]).append("%s升到 Lv.%d" % [Names.of(def), int(out["tier_after"])])
	for p in perks():
		var line := (p as FaithPerk).on_offered(_run, defs, at_node)
		if line != "":
			(out["log"] as Array[String]).append(line)
	noted.emit("、".join(out["log"]))
	return out


## 神坛上现在能做的特殊操作（阶到了的、有按钮文字的）
func actions() -> Array[FaithPerk]:
	var out: Array[FaithPerk] = []
	for p in perks():
		if (p as FaithPerk).altar_label() != "":
			out.append(p)
	return out


## 做一个神坛特殊操作：这一次机会用掉（这个点上不能再献祭 / 再操作）。返回给日志的一句；空 = 没做
func special(p: FaithPerk, at_node: MapNode, option: StringName = &"") -> String:
	if p == null or not is_open() or p.altar_available(_run, at_node) != "":
		return ""
	var line := p.altar_apply(_run, at_node, option)
	if line == "":
		return ""
	used[node] = true
	noted.emit(line)
	return line
#endregion


#region 赐福（095）
## 095：战利品 / 搜索翻到的普通道具按概率换成赐福版（激活了信仰只换那位神的，没激活随机一位有赐福版的神）
func bless_substitute(ids: Array[StringName], chance_idle: float, chance_active: float, rng: RandomNumberGenerator) -> Array[StringName]:
	if _run == null:
		return ids
	return Blessings.substitute(ids, _run.items, _run.active_faith_id(), _run.faith_defs.keys(), chance_idle, chance_active, rng)


## 095：走一步之后：激活了信仰，棋盘上每件能被赐福的道具独立掷一次
## （convert_chance + 每级 convert_per_tier）变成那位神的赐福版
func bless_step() -> void:
	var def := _run.active_faith() if _run != null else null
	var board: GridInventory = _run.board if _run != null else null
	if def == null or board == null or _run.items == null:
		return
	var chance := def.convert_chance + def.convert_per_tier * float(maxi(0, _run.active_faith_tier()))
	if chance <= 0.0:
		return
	var steps := _run.travel.clock.total if _run.travel != null and _run.travel.clock != null else 0
	for raw in board.items().duplicate():
		var inst := raw as ItemInstance
		if inst == null or Blessings.variant_of(_run.items, inst.def.id, def.id) == null:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:bless:%d:%d" % [_run.run_seed, steps, inst.uid])
		if rng.randf() < chance:
			var was := Names.of(inst.def)
			var v := Blessings.bless_instance(inst, _run.items, def.id)
			if v != null:
				board.changed.emit()
				item_blessed.emit(inst, def.id)
				noted.emit("%s的目光落在「%s」上：它成了「%s」" % [Names.of(def), was, Names.of(v)])
#endregion


func to_dict() -> Dictionary:
	return {"rituals": rituals.duplicate(), "stat_bonus": stat_bonus.duplicate(), "used": used.keys()}


func restore(d: Dictionary) -> void:
	rituals = (d.get("rituals", {}) as Dictionary).duplicate() if d.get("rituals", {}) is Dictionary else {}
	stat_bonus = (d.get("stat_bonus", {}) as Dictionary).duplicate() if d.get("stat_bonus", {}) is Dictionary else {}
	for k in d.get("used", []):
		used[int(k)] = true


func _on_altar_opened(n: MapNode) -> void:
	node = n.id if n != null else -1


## 走开就关神坛（下次回来这个点也不再有：休息点用过了）
func _on_leaving(_node_id: int) -> void:
	node = -1


func _on_stepped(_node_id: int, reason: StringName) -> void:
	if reason == &"step":
		bless_step()     # 095：只有自己走一步会掷（被事件挪走、原地耗时不掷）


## 093（大地之神 3 级）：踩上一个点给对应类型的道具
func _on_moved(intent: MoveIntent, first: bool) -> void:
	if _run == null or _run.map == null:
		return
	var n := _run.map.get_node(intent.to_id) if _run.map.has_node(intent.to_id) else null
	for p in perks():
		var line := (p as FaithPerk).on_node_entered(_run, n, first)
		if line != "":
			noted.emit(line)
