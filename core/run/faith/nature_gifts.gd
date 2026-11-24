## 388 第 3 批 B 段：自然之神的牌局内给东西 —— 按稀有度权重抽一件（药材、食材、种子、自然系道具），放进背包、放不下放地上。
## 权重是下标 = 稀有度（0 普通 … 4 传说）。抽中的那一档没有东西：[param skip] 真 = 只在有东西的几档里按比例分（报告 392 的种子），
## 假 = 往下一档取，下面都没有再往上（架构设计 11-24：药材感知）
class_name NatureGifts
extends RefCounted

## 不当礼物给的（任务物、唯一的、信物、珍宝）
const SKIP: Array[StringName] = [&"unique", &"commission", &"keepsake", &"treasure"]
const SEED_TAG := &"seed"
const NATURE := &"nature"
## 初值（牌数据里 w0..w4 能改）：作者给药材感知写的那组
const WEIGHTS: Array[float] = [50.0, 35.0, 10.0, 5.0, 0.0]
## 动物交谈、收获：传说也可能有
const WEIGHTS_WIDE: Array[float] = [50.0, 35.0, 10.0, 5.0, 1.0]


## 局里能拿到的道具（照搜索那份：不出包、金银、珍宝）
static func _base(run: RunState) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	if run == null or run.items == null:
		return out
	var sr: SearchRules = run.events.rules.search if run.events != null and run.events.rules != null and run.events.rules.search != null else SearchRules.new()
	for id in SearchSession.candidates(sr, run.items):
		var d := run.items.get_def(id)
		if d != null and not d.has_any_tag(SKIP):
			out.append(d)
	return out


## 药材：草药做的素材（委托 hand_in 的 material = herb 用的那一类）
static func is_herb(def: ItemDef) -> bool:
	return def != null and def.has_tag(&"material") and def.material == "herb"


static func pool(run: RunState, kind: StringName) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for d in _base(run):
		var ok := false
		match kind:
			&"herb":
				ok = is_herb(d)
			&"ingredient":
				ok = d.has_tag(&"ingredient")
			&"seed":
				ok = d.has_tag(SEED_TAG)
			_:
				ok = d.has_tag(NATURE)
		if ok:
			out.append(d)
	return out


## 抽一件：先按 [param weights] 抽稀有度（低于 [param floor_r] 的不抽），再在那一档里平均抽
static func roll(defs: Array[ItemDef], weights: Array[float], rng: RandomNumberGenerator, floor_r: int = 0, skip: bool = false) -> ItemDef:
	if defs.is_empty():
		return null
	var by: Dictionary = {}
	for d in defs:
		var r := clampi(d.rarity, 0, 4)
		if not by.has(r):
			by[r] = [] as Array[ItemDef]
		(by[r] as Array[ItemDef]).append(d)
	var w: Array[float] = []
	var total := 0.0
	for r in 5:
		var x := weights[r] if r < weights.size() else 0.0
		if r < floor_r or (skip and not by.has(r)):
			x = 0.0
		w.append(maxf(0.0, x))
		total += w[r]
	var want := floor_r
	if total > 0.0:
		var t := rng.randf() * total
		for r in 5:
			t -= w[r]
			if t < 0.0:
				want = r
				break
	var got := -1
	for r in range(want, -1, -1):
		if by.has(r):
			got = r
			break
	if got < 0:
		for r in range(want + 1, 5):
			if by.has(r):
				got = r
				break
	if got < 0:
		return null
	var list: Array[ItemDef] = by[got]
	return list[rng.randi_range(0, list.size() - 1)]


## 正好这一档（初种采摘）：没有就往下，再没有往上
static func of_rarity(defs: Array[ItemDef], rarity: int, rng: RandomNumberGenerator) -> ItemDef:
	var w: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	w[clampi(rarity, 0, 4)] = 1.0
	return roll(defs, w, rng, 0, false)


## 这一局第几次给（随机数用）
static func rng_for(run: RunState, key: String) -> RandomNumberGenerator:
	var lv := LevelModule.of(run)
	var n := 0
	if lv != null:
		n = int(lv.god_state.get("gift_n", 0))
		lv.god_state["gift_n"] = n + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:nature:%s:%d" % [run.run_seed if run != null else 0, key, n])
	return rng


## 放进背包，放不下放地上（[param ground] 真 = 直接放地上）。返回放下的实例（哪都放不下 null）
static func give(run: RunState, def: ItemDef, ground: bool = false) -> ItemInstance:
	if run == null or def == null:
		return null
	var inst := ItemInstance.create(def)
	if not ground and run.board != null and run.board.try_add(inst):
		return inst
	if run.storage != null and run.storage.insert(inst):
		return inst
	return null


## 牌数据里的权重（w0..w4，没写用 [param fallback]）
static func weights_of(lv: LevelModule, cid: StringName, fallback: Array[float]) -> Array[float]:
	var out: Array[float] = fallback.duplicate()
	var card := LevelModule.god_card_of(lv.card_def(cid)) if lv != null else null
	if card == null:
		return out
	for r in 5:
		var k := "w%d" % r
		if card.values.has(k):
			out[r] = float(card.values[k])
	return out
