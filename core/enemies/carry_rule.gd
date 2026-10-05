## 126（作者定）：敌人身上随机携带的非战斗道具 —— 零到若干件，越值钱越少见；出现与掉落是两套独立的概率。
##
## 作者原话：「给敌人增加身上会携带的非战斗道具，随机出现（0~N 件），价值越高出现几率越低，和掉落率独立」。
## 出现由这里定（生成地图时，[EnemyPlacer.build_content] 在战斗道具摆完之后再摆），掉不掉由 [DropRule] 定
## （`carried_always_drop`，默认必掉）。内容里这几件带 `"carried": true`。
## 作者数据，走内容管线：`data/authoring/carry_rules/*.json` → `data/carry_rules/*.tres`，章节按 id 引用（空 = 不带）。
class_name CarryRule
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

## 从带这些标签之一、**没有战斗档**、不是包、不带珍宝标签的道具里抽（封存 / 遗物 / 赐福版本来就不在 [method ItemDatabase.ids] 里）
@export var tags: Array[StringName] = [&"material"]
## 档位 → 件数区间 [min, max]，均匀抽；超出表长按最后一档
@export var count_by_strength: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 4)]
## 每件的抽取权重 = 1 / 价值 ^ value_power。1 = 价值翻倍、几率减半；越大越偏向便宜货
@export var value_power: float = 1.0
## 允许比档位的稀有度上限高这么多（外环小兵偶尔也背一卷丝绸）。档位没有上限（-1）就不限
@export var rarity_cap_bonus: int = 1
## 同一件能不能抽到不止一次
@export var allow_repeat: bool = true

const TREASURE := &"treasure"


## 这一档抽几件的区间
func count_range(strength: int) -> Vector2i:
	if count_by_strength.is_empty():
		return Vector2i.ZERO
	return count_by_strength[clampi(strength, 0, count_by_strength.size() - 1)]


## 候选：id 按文本升序（抽出来的才可复现）。[param rarity_cap] < 0 = 不限
func candidates(items: ItemDatabase, rarity_cap: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if items == null:
		return out
	var cap := rarity_cap + rarity_cap_bonus if rarity_cap >= 0 else -1
	for raw in items.ids():
		var id := StringName(raw)
		var d := items.get_def(id)
		if d == null or d.combat != null or d.is_bag or d.tags.has(TREASURE):
			continue
		if cap >= 0 and d.rarity > cap:
			continue
		var hit := false
		for t in tags:
			if d.tags.has(t):
				hit = true
				break
		if hit:
			out.append(id)
	Ids.sort(out)
	return out


## 抽取权重：价值越高越少见
func weight(def: ItemDef) -> float:
	return 1.0 / pow(float(maxi(1, ItemValue.of(def))), maxf(0.0001, value_power))


## 掷：这个敌人身上带哪几件（还没摆）
func roll(items: ItemDatabase, strength: int, rarity_cap: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var out: Array[StringName] = []
	var span := count_range(strength)
	var n := rng.randi_range(maxi(0, span.x), maxi(0, span.y)) if span.y > 0 else 0
	if n <= 0:
		return out
	var pool := candidates(items, rarity_cap)
	for i in n:
		if pool.is_empty():
			break
		var total := 0.0
		for id in pool:
			total += weight(items.get_def(id))
		var r := rng.randf() * total
		var pick := pool[pool.size() - 1]
		for id in pool:
			r -= weight(items.get_def(id))
			if r <= 0.0:
				pick = id
				break
		out.append(pick)
		if not allow_repeat:
			pool.erase(pick)
	return out
