## 打赢了掉什么（架构文档 6.1，M4-2）。纯逻辑、可复现：同一份内容 + 同一个上下文 + 同一个种子 → 同样的掉落。
##
## 两段：
## 1. **敌人自己的道具各掷一次。** 概率 = 基础（按稀有度，越稀有越低）+ 难度 × difficulty_bonus + 幸运 × luck_bonus
##    + 道具 / 套装的战利品效果（`LootContext.drop_owned_chance`）+ 各来源（局外 buff、地图 buff，占位）。夹进 0～1。
## 2. **珍宝。** `rolls` 次尝试（基础 1，战利品效果可加），每次按 treasure_chance（可选吃同一套修正）掷；
##    中了按 treasure_weights（+ rarity_bias）抽稀有度，再在「带珍宝标签、这个稀有度、敌人**没有**」的道具里抽一件
##    （category_bias 加权）。珍宝道具还没定义时会记下 `treasure_missing`，不掉、不报错。
##
## 结果装进尸体容器（[method corpse_of]）：就是一个 [GridInventory]，M1 的代码原样复用。
class_name DropResolver
extends RefCounted


## 敌人自己这件道具掉不掉的概率
static func owned_chance(rule: DropRule, ctx: LootContext, def: ItemDef) -> float:
	if rule == null or def == null:
		return 0.0
	var p := rule.base_of(def.rarity) + _common_bonus(rule, ctx)
	if ctx != null:
		p += StatMath.to_float(ctx.drop_owned_chance)
		for s in ctx.sources:
			p += (s as DropBonusSource).owned_bonus(ctx, def)
		p *= ctx.drop_mult
	return clampf(p, 0.0, 1.0)


## 一次珍宝尝试的概率
static func treasure_chance(rule: DropRule, ctx: LootContext) -> float:
	if rule == null:
		return 0.0
	var p := rule.treasure_chance
	if rule.treasure_modified:
		p += _common_bonus(rule, ctx)
	if ctx != null:
		for s in ctx.sources:
			p += (s as DropBonusSource).treasure_bonus(ctx)
		p *= ctx.drop_mult
	return clampf(p, 0.0, 1.0)


## 难度与幸运：两个都是 LootContext 自带的数
static func _common_bonus(rule: DropRule, ctx: LootContext) -> float:
	if ctx == null:
		return 0.0
	return float(maxi(0, ctx.difficulty)) * rule.difficulty_bonus + float(ctx.luck) * rule.luck_bonus


## 敌人自己的道具 id 列表（节点内容里记的）
static func carried_ids(content: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for raw in content.get("items", []):
		out.append(StringName(String((raw as Dictionary).get("id", ""))))
	return out


## 可以当珍宝掉的道具：带珍宝标签、是这个稀有度、敌人没有。id 升序，抽出来的才可复现
static func treasure_candidates(rule: DropRule, items: ItemDatabase, rarity: int, carried: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in items.ids():
		var d := items.get_def(id)
		if d == null or d.rarity != rarity or carried.has(id) or not d.tags.has(rule.treasure_tag):
			continue
		out.append(id)
	out.sort()
	return out


## 掷：返回 {"dropped": [敌人自己掉的 id], "treasure": [珍宝 id], "treasure_missing": 中了却没有可掉的珍宝的次数}
static func roll(
	content: Dictionary, rule: DropRule, ctx: LootContext, items: ItemDatabase, rng: RandomNumberGenerator
) -> Dictionary:
	var out := {"dropped": [] as Array[StringName], "treasure": [] as Array[StringName], "treasure_missing": 0}
	if rule == null or items == null:
		return out
	var carried := carried_ids(content)
	for id in carried:
		var def := items.get_def(id)
		if def == null:
			continue
		# 作者定：敌人身上的包必掉（bags_always_drop），不占保底名额
		if (rule.bags_always_drop and def.is_bag) or rng.randf() < owned_chance(rule, ctx, def):
			(out["dropped"] as Array[StringName]).append(id)
	# 084：节点内容 `guaranteed_drops` 一定掉（教程：遭遇的敌人必掉一个包）。**只能是它身上有的**（作者：敌人不能掉没有的东西）
	for raw in content.get("guaranteed_drops", []):
		var gid := StringName(String(raw))
		if carried.has(gid) and items.get_def(gid) != null and not (out["dropped"] as Array[StringName]).has(gid):
			(out["dropped"] as Array[StringName]).append(gid)
	# 084：至少掉 min_drops 件身上有的（包不算数）—— 掷完不够，从没掉的非包里随机补
	var dropped_list: Array[StringName] = out["dropped"]
	if rule.min_drops > 0 and _non_bag_count(dropped_list, items) < rule.min_drops:
		var left: Array[StringName] = []
		for id in carried:
			var d := items.get_def(id)
			if d != null and not d.is_bag and not dropped_list.has(id):
				left.append(id)
		while _non_bag_count(dropped_list, items) < rule.min_drops and not left.is_empty():
			var k := rng.randi_range(0, left.size() - 1)
			dropped_list.append(left[k])
			left.remove_at(k)
	var tries := ctx.rolls if ctx != null else 1
	for i in maxi(0, tries):
		if rng.randf() >= treasure_chance(rule, ctx):
			continue
		var rarity := _pick_rarity(rule, ctx, rng)
		var cands := treasure_candidates(rule, items, rarity, carried)
		if cands.is_empty():
			# 这一档没有就看别的珍宝档位 —— 珍宝还没定义时全空，记一笔
			for r in rule.treasure_rarities():
				if r != rarity:
					cands = treasure_candidates(rule, items, r, carried)
					if not cands.is_empty():
						break
		if cands.is_empty():
			out["treasure_missing"] = int(out["treasure_missing"]) + 1
			continue
		(out["treasure"] as Array[StringName]).append(_pick_weighted(cands, ctx, items, rng))
	return out


## 珍宝的稀有度：表里的权重 + 战利品效果的 rarity_bias（同单位：权重）
static func _pick_rarity(rule: DropRule, ctx: LootContext, rng: RandomNumberGenerator) -> int:
	var rarities := rule.treasure_rarities()
	if rarities.is_empty():
		return -1
	var weights: Array[float] = []
	var total := 0.0
	for r in rarities:
		var w := rule.treasure_weight(r)
		if ctx != null:
			w += float(ctx.rarity_bias.get(r, 0))
		w = maxf(0.0, w)
		weights.append(w)
		total += w
	if total <= 0.0:
		return rarities[rarities.size() - 1]
	var x := rng.randf() * total
	for i in rarities.size():
		x -= weights[i]
		if x <= 0.0:
			return rarities[i]
	return rarities[rarities.size() - 1]


## 候选里抽一件：每件权重 1 + 它标签上的 category_bias 之和（百分比换成比例）
static func _pick_weighted(cands: Array[StringName], ctx: LootContext, items: ItemDatabase, rng: RandomNumberGenerator) -> StringName:
	var weights: Array[float] = []
	var total := 0.0
	for id in cands:
		var w := 1.0
		if ctx != null:
			for tag in items.get_def(id).tags:
				w += float(ctx.category_bias.get(tag, 0)) / 100.0
		w = maxf(0.0, w)
		weights.append(w)
		total += w
	if total <= 0.0:
		return cands[rng.randi_range(0, cands.size() - 1)]
	var x := rng.randf() * total
	for i in cands.size():
		x -= weights[i]
		if x <= 0.0:
			return cands[i]
	return cands[cands.size() - 1]


## 期望掉几件（沙盒预览用）：每件的概率之和 + 珍宝尝试次数 × 珍宝概率（有珍宝可掉才算）
static func expected_count(content: Dictionary, rule: DropRule, ctx: LootContext, items: ItemDatabase) -> float:
	if rule == null or items == null:
		return 0.0
	var total := 0.0
	var carried := carried_ids(content)
	for id in carried:
		total += owned_chance(rule, ctx, items.get_def(id))
	var any_treasure := false
	for r in rule.treasure_rarities():
		if not treasure_candidates(rule, items, r, carried).is_empty():
			any_treasure = true
			break
	if any_treasure:
		total += float(ctx.rolls if ctx != null else 1) * treasure_chance(rule, ctx)
	return total


## 尸体容器：掉下来的东西摆进一块棋盘（大小照敌人的棋盘；珍宝塞不下就加高，见 [LootPacker]）。
## 就是一个 GridInventory —— 搜刮界面直接拿它当容器
## 掉了几件不是包的（保底只数这些）
static func _non_bag_count(ids: Array[StringName], items: ItemDatabase) -> int:
	var n := 0
	for id in ids:
		var d := items.get_def(id)
		if d != null and not d.is_bag:
			n += 1
	return n


static func corpse_of(content: Dictionary, rolled: Dictionary, items: ItemDatabase) -> GridInventory:
	var size_raw: Array = content.get("board", [4, 3])
	var ids: Array[StringName] = []
	ids.append_array(rolled.get("dropped", [] as Array[StringName]))
	ids.append_array(rolled.get("treasure", [] as Array[StringName]))
	return LootPacker.board_of(ids, Vector2i(int(size_raw[0]), int(size_raw[1])), items)
