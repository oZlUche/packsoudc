## 388 第 2 批：日神基础牌【奇迹】—— 拿到当场，把背包里随机一件素材换成同类（自然 / 工艺 / 魔法）、高一档稀有度的随机素材；
## 传说的不换。新的一件放回原位，放不下就找个空位，再放不下这次不换。返回 {from, to}（没换 = 空）
class_name Miracle
extends RefCounted

const CLASSES: Array[StringName] = [&"nature", &"crafted", &"magic"]
const LEGENDARY := 4
## 不当素材换的（任务物、唯一的、信物）
const SKIP: Array[StringName] = [&"unique", &"commission", &"keepsake"]


static func class_of(def: ItemDef) -> StringName:
	for c in CLASSES:
		if def.has_tag(c):
			return c
	return &""


static func _ok(def: ItemDef) -> bool:
	if def == null or not def.has_tag(&"material") or class_of(def) == &"":
		return false
	for t in SKIP:
		if def.has_tag(t):
			return false
	return true


static func apply(run: RunState) -> Dictionary:
	if run == null or run.board == null or run.items == null:
		return {}
	var pool: Array[ItemInstance] = []
	for raw in run.board.items():
		var inst := raw as ItemInstance
		if inst != null and _ok(inst.def) and inst.def.rarity < LEGENDARY and not run.board.is_locked(inst.uid):
			pool.append(inst)
	if pool.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	var lv := LevelModule.of(run)
	rng.seed = hash("%d:miracle:%d" % [run.run_seed, lv.draws if lv != null else 0])
	for i in range(pool.size() - 1, 0, -1):     # 按种子洗（不用全局随机）
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for inst in pool:
		var want := inst.def.rarity + 1
		var cls := class_of(inst.def)
		var ups: Array[ItemDef] = []
		for id in run.items.ids():
			var d := run.items.get_def(id)
			if _ok(d) and d.rarity == want and class_of(d) == cls:
				ups.append(d)
		if ups.is_empty():
			continue
		var to := ups[rng.randi_range(0, ups.size() - 1)]
		var at := inst.origin
		var rot := inst.rotation
		run.board.remove(inst.uid)
		var fresh := ItemInstance.create(to)
		if run.board.can_place_def(to, at, rot) and run.board.place(fresh, at, rot):
			return {"from": String(inst.def.id), "to": String(to.id)}
		if run.board.try_add(fresh):
			return {"from": String(inst.def.id), "to": String(to.id)}
		run.board.place(inst, at, rot)     # 放不下：这件不换，试下一件
	return {}
