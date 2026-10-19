## 节点内容 → 敌人的棋盘与战斗单位（架构文档 5.10）。
##
## [b]和玩家走同一个 [BattleCompiler]。[/b] 预览里的生命、DPS、件数与真打出来的一致，
## 因为预览拿到的就是 [method spec_of] 编译出来的那份 —— 编译是纯函数。
## 打赢了搜的也是这块棋盘（6.1 的尸体容器），[method board_of] 重建出来直接当容器用。
class_name EnemyKit
extends RefCounted


## 212：魔兽 / 机关的棋盘带这个标记（meta）—— 悬浮窗看到它就写道具的 wild 面
const WILD_META := &"wild"


## 这个点里有没有敌人
static func has_enemy(content: Dictionary) -> bool:
	return content.has("enemy") and String(content["enemy"]) != ""


## 按内容里记的位置与朝向重建棋盘。认不得的道具跳过（内容比道具库老的时候）
## [param find_room] 假 = 写的位置摆不下就不放（[method unplaced_items] 查数据用）
static func board_of(content: Dictionary, items: ItemDatabase, find_room: bool = true) -> GridInventory:
	var size_raw: Array = content.get("board", [4, 3])
	var size := Vector2i(int(size_raw[0]), int(size_raw[1]))
	# 084：身上有包就和玩家一样 —— 道具只能在包里（requires_bag），包先摆；老内容（没有包）照旧直接摆
	var entries: Array = []
	var has_bag := false
	for raw in entries_of(content):
		var entry := raw as Dictionary
		var def := items.get_def(StringName(String(entry.get("id", ""))))
		if def == null:
			continue
		entries.append([def, entry])
		if def.is_bag:
			has_bag = true
	# 包先、写了位置的先（165：没写位置的 —— 还没摆过的预设内容 —— 最后自己找空位）
	var rank := func(pair: Array) -> int:
		return (0 if (pair[0] as ItemDef).is_bag else 2) + (0 if (pair[1] as Dictionary).has("at") else 1)
	var order: Array = []
	for r in 4:
		for pair in entries:
			if rank.call(pair) == r:
				order.append(pair)
	var board := GridInventory.new(size, 0, has_bag)
	if bool(content.get("wild", false)):
		board.set_meta(WILD_META, true)
	for pair in order:
		var def: ItemDef = pair[0]
		var entry: Dictionary = pair[1]
		var inst := ItemInstance.create(def, int(entry.get("rot", 0)))
		if not entry.has("at"):
			if not board.try_add(inst):
				push_warning("敌人的道具摆不下：%s（棋盘 %s）" % [def.id, size])
			continue
		var at: Array = entry["at"]
		if not board.place(inst, Vector2i(int(at[0]), int(at[1])), int(entry.get("rot", 0))):
			# 作者 2026-10-12：敌人只该掉自己身上的东西 —— 写的位置摆不下（旧存档记着改形状之前的位置：143 把短剑改成 T 形），
			# 自己找个空位放；还放不下才说一声（[method unplaced_items] 给测试查）
			if not find_room or not board.try_add(inst):
				push_warning("敌人的道具摆不下：%s @ %s（棋盘 %s）" % [def.id, at, size])
	return board


## 内容里的全部件：`items` 加上还没摆过的 `groups`（165：预设图的组，开局时 [method EnemyPlacer.arrange] 会把它们展开进 items）
static func entries_of(content: Dictionary) -> Array:
	var out: Array = []
	for raw in content.get("items", []):
		if raw is Dictionary:
			out.append(raw)
	for g in content.get("groups", []):
		for raw in g:
			if raw is Dictionary:
				var e := (raw as Dictionary).duplicate()
				e.erase("at")     # 组内的 at 是相对锚点的，不是棋盘上的格
				e.erase("rot")
				out.append(e)
	return out


## 作者 2026-10-12：这份节点内容里**照写的位置**摆不下的道具 id（预设图的测试逐个敌人查；游戏里会自己找空位，数据还是该写对）
static func unplaced_items(content: Dictionary, items: ItemDatabase) -> Array[StringName]:
	var board := board_of(content, items, false)
	var placed := {}
	for inst in board.items():
		placed[(inst as ItemInstance).def.id] = int(placed.get((inst as ItemInstance).def.id, 0)) + 1
	var out: Array[StringName] = []
	for raw in entries_of(content):
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
	var inp := CompileInput.of(baseline_of(def, tier, content))
	inp.wild = def.is_wild()     # 212：魔兽 / 机关用道具的 wild 面
	return BattleCompiler.compile(board_of(content, items), inp)


## 一行给人看的摘要：名字、生命、几件、都是什么（2026-10-17：档位、流派键、DPS 是内部读数，不给玩家看）
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
	var line := "%s　生命 %d　%d 件：%s" % [def.display_name, spec.max_hp_int(), names.size(), "、".join(names)]
	# 126：身上带的非战斗道具（必掉）
	if carried > 0:
		line += "　携带 %d 件" % carried
	return line
