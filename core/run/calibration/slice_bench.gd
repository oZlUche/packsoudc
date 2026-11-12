## 312（试玩切片 S1）：切片地图上每一场写死的仗，按四种玩家配置各打一批种子 —— 定敌人数值用。只出表，不改数
## 玩家 = 切片角色（开局的包）+ 配置里的东西（先摆包、大件先放，和序章测试同一个摆法）
class_name SliceBench
extends RefCounted

const CONFIGS := {
	"开局预设": ["knife", "bandage", "ration"],
	"双刀": ["twin_blades", "bandage", "ration"],
	"涂毒匕首": ["poisoned_knife", "knife", "bandage", "ration"],
	"加盾甲": ["knife", "knife", "round_shield", "leather_armor", "bandage", "ration"],
	"两把匕首 + 皮甲": ["knife", "knife", "leather_armor", "bandage", "ration"],
	"双刀 + 皮甲": ["twin_blades", "leather_armor", "bandage", "ration"],
	"淬火匕首 + 匕首 + 皮甲": ["quenched_dagger", "knife", "leather_armor", "bandage", "ration"],
	"阔剑 + 圆盾 + 皮甲": ["broadsword", "round_shield", "leather_armor", "bandage", "ration"],
	"涂毒匕首 + 弯刀 + 圆盾 + 皮甲": ["poisoned_knife", "scimitar", "round_shield", "leather_armor", "bandage", "ration"],
}


## 地图上要打的：[{"node": id, "label": 文字, "content": 敌人内容}]（搜索点的遭遇也算）
static func fights_of(map_path: String) -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(map_path))
	var out: Array = []
	if not (d is Dictionary):
		return out
	for n in (d as Dictionary).get("nodes", []):
		var c: Dictionary = n.get("content", {})
		if c.has("enemy"):
			out.append({"node": int(n["id"]), "label": "%d %s" % [int(n["id"]), String(n["type"])], "content": c})
		elif c.has("encounter"):
			out.append({"node": int(n["id"]), "label": "%d 搜索遭遇" % int(n["id"]), "content": c["encounter"]})
	return out


static func player(ch: CharacterDef, items: ItemDatabase, ids: Array) -> CombatantSpec:
	var board := GridInventory.new(ch.board_size, 1, true)
	for bag_id in ch.starting_bags:
		board.try_add(ItemInstance.create(items.get_def(bag_id), 0), true)
	var sorted := ids.duplicate()
	sorted.sort_custom(func(a, b) -> bool:
		var da := items.get_def(StringName(String(a)))
		var db := items.get_def(StringName(String(b)))
		if da.is_bag != db.is_bag:
			return da.is_bag
		return da.cell_count() > db.cell_count() if da.cell_count() != db.cell_count() else String(a) < String(b))
	for id in sorted:
		board.try_add(ItemInstance.create(items.get_def(StringName(String(id))), 0), true)
	var ctx := RunContext.new()
	for e in ch.run_effects():
		e.modify(ctx)
	var base := ch.baseline()
	for key in ctx.stat_bonus:
		base.base_stats[String(key)] = float(base.base_stats.get(String(key), 0.0)) + float(ctx.stat_bonus[key])
	var spec := BattleCompiler.compile_board(board, base)
	spec.set_rules.append_array(ch.combat_rules())
	return spec


## 一格：胜率、赢的那几场剩多少血（比例）、平均打多久（秒）
static func cell(me: CombatantSpec, foe: CombatantSpec, seeds: int) -> Dictionary:
	var wins := 0
	var hp := 0.0
	var secs := 0.0
	for s in range(1, seeds + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var r := BattleSim.run(me, foe, rng, 60.0)
		secs += StatMath.to_float(r.duration)
		if r.winner == 0:
			wins += 1
			var left: Variant = BattleMetrics.hp_ratio(r, 0)
			hp += float(left) if left != null else 0.0
	return {"win": float(wins) / float(maxi(1, seeds)), "hp": hp / float(maxi(1, wins)), "secs": secs / float(maxi(1, seeds))}


static func markdown(map_path: String, ch: CharacterDef, items: ItemDatabase, enemies: EnemyDatabase, seeds: int) -> String:
	var names: Array = CONFIGS.keys()
	var md := "| 仗 | 敌人 | %s |\n|---|---|%s\n" % [" | ".join(names), "---|".repeat(names.size())]
	var specs := {}
	for k in names:
		specs[k] = player(ch, items, CONFIGS[k])
	for f in fights_of(map_path):
		var c: Dictionary = f["content"]
		var foe := EnemyKit.spec_of(c, enemies, null, items)
		var def := enemies.enemy(StringName(String(c.get("enemy", ""))))
		var cells: Array[String] = []
		for k in names:
			var x := cell(specs[k], foe, seeds)
			cells.append("%d%%（剩 %d%%，%.1f 秒）" % [roundi(x["win"] * 100.0), roundi(x["hp"] * 100.0), x["secs"]])
		md += "| %s | %s 生命 %d 格挡 %d | %s |\n" % [f["label"], Names.of(def) if def != null else String(c.get("enemy", "")), StatMath.to_int(foe.max_hp), StatMath.to_int(foe.baseline.total_of(BattleStats.BLOCK) if foe.baseline != null else 0), " | ".join(cells)]
	return md
