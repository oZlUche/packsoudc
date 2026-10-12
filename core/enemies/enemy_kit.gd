## 节点内容 → 敌人的棋盘与战斗单位（架构文档 5.10）。
##
## [b]和玩家走同一个 [BattleCompiler]。[/b] 预览里的生命、DPS、件数与真打出来的一致，
## 因为预览拿到的就是 [method spec_of] 编译出来的那份 —— 编译是纯函数。
## 打赢了搜的也是这块棋盘（6.1 的尸体容器），[method board_of] 重建出来直接当容器用。
class_name EnemyKit
extends RefCounted


## 这个点里有没有敌人
static func has_enemy(content: Dictionary) -> bool:
	return content.has("enemy") and String(content["enemy"]) != ""


## 按内容里记的位置与朝向重建棋盘。认不得的道具跳过（内容比道具库老的时候）
static func board_of(content: Dictionary, items: ItemDatabase) -> GridInventory:
	var size_raw: Array = content.get("board", [4, 3])
	var size := Vector2i(int(size_raw[0]), int(size_raw[1]))
	# 084：身上有包就和玩家一样 —— 道具只能在包里（requires_bag），包先摆；老内容（没有包）照旧直接摆
	var entries: Array = []
	var has_bag := false
	for raw in content.get("items", []):
		var entry := raw as Dictionary
		var def := items.get_def(StringName(String(entry.get("id", ""))))
		if def == null:
			continue
		entries.append([def, entry])
		if def.is_bag:
			has_bag = true
	entries.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[0] as ItemDef).is_bag and not (b[0] as ItemDef).is_bag)
	var board := GridInventory.new(size, 0, has_bag)
	for pair in entries:
		var def: ItemDef = pair[0]
		var entry: Dictionary = pair[1]
		var at: Array = entry.get("at", [0, 0])
		var inst := ItemInstance.create(def, int(entry.get("rot", 0)))
		if not board.place(inst, Vector2i(int(at[0]), int(at[1])), int(entry.get("rot", 0))):
			# 作者 2026-10-12：敌人只该掉自己身上的东西 —— 摆不下的这件战斗里没有、掉落表却按 items 算，说一声（[method unplaced_items] 给测试查）
			push_warning("敌人的道具摆不下：%s @ %s（棋盘 %s）" % [def.id, at, size])
	return board


## 作者 2026-10-12：这份节点内容里摆不下的道具 id（预设图的测试逐个敌人查）
static func unplaced_items(content: Dictionary, items: ItemDatabase) -> Array[StringName]:
	var board := board_of(content, items)
	var placed := {}
	for inst in board.items():
		placed[(inst as ItemInstance).def.id] = int(placed.get((inst as ItemInstance).def.id, 0)) + 1
	var out: Array[StringName] = []
	for raw in content.get("items", []):
		var id := StringName(String((raw as Dictionary).get("id", "")))
		if items.get_def(id) == null:
			continue
		if int(placed.get(id, 0)) > 0:
			placed[id] = int(placed[id]) - 1
		else:
			out.append(id)
	return out


## 基线：默认值 → 敌人自己的覆盖 → 档位倍率 → 节点内容的覆盖（`content.base_stats`，084：预设图里写死的教程敌人自己定数，不跟全局敌人数值一起涨）
static func baseline_of(def: EnemyDef, tier: StrengthTier, content: Dictionary = {}) -> CombatantBaseline:
	var b := CombatantBaseline.default_baseline()
	if def != null:
		for key in def.base_stats:
			b.base_stats[String(key)] = float(def.base_stats[key])
	if tier != null:
		for key in tier.stat_scale:
			var k := String(key)
			b.base_stats[k] = b.value_of(StringName(k), 0.0) * float(tier.stat_scale[key])
	var over = content.get("base_stats", null)
	if over is Dictionary:
		for key in over:
			var k := String(key)
			# 旧存档里的节点内容：armor 是 153 之前的固定减伤（新世界里 base_stats 不会有 armor，护甲只认 max_armor），
			# max_shield 是补充一之前的护盾
			if k == "armor":
				k = String(BattleStats.BLOCK)
			elif k == "max_shield":
				k = String(BattleStats.MAX_ARMOR)
			b.base_stats[k] = float(over[key])
	return b


## 编译成战斗单位。敌人定义找不到时返回 null
static func spec_of(content: Dictionary, enemies: EnemyDatabase, pool: EnemyPool, items: ItemDatabase) -> CombatantSpec:
	var def := enemies.enemy(StringName(String(content.get("enemy", "")))) if enemies != null else null
	if def == null:
		return null
	var tier := pool.tier_of(int(content.get("strength", 0))) if pool != null else null
	return BattleCompiler.compile_board(board_of(content, items), baseline_of(def, tier, content))


## 一行给人看的摘要：名字、档位、生命、DPS、几件、都是什么
static func summary(content: Dictionary, enemies: EnemyDatabase, pool: EnemyPool, items: ItemDatabase) -> String:
	var def := enemies.enemy(StringName(String(content.get("enemy", "")))) if enemies != null else null
	if def == null:
		return ""
	var spec := spec_of(content, enemies, pool, items)
	var names: Array[String] = []
	var carried := 0
	for raw in content.get("items", []):
		if bool((raw as Dictionary).get("carried", false)):
			carried += 1
		var idef := items.get_def(StringName(String((raw as Dictionary).get("id", ""))))
		names.append(idef.display_name if idef != null else String((raw as Dictionary).get("id", "?")))
	var line := "%s（档位 %d，%s）　生命 %d　约 %.1f DPS　%d 件：%s" % [
		def.display_name, int(content.get("strength", 0)), "／".join(def.schools),
		spec.max_hp_int(), spec.rough_dps(), names.size(), "、".join(names)]
	# 126：身上带的非战斗道具（必掉）
	if carried > 0:
		line += "　携带 %d 件" % carried
	return line
