class_name RedSources
extends RefCounted
## 281 §四.4（作者 10:47 改版）：红武的**劣化版**（`<红武 id>_lesser`，面板与红武一样、没有独有机制、不是独一的）——
## 核心 BOSS 与猎手（档 ≥3）开战前掷一次「持有」，持有就真的拿着打（棋盘上替掉同类的一件，战前准备屏看得见）；
## 打赢了再掷一次掉落。常规掉落不收劣化版（[method DropResolver.roll] 跳过），只走这里。
## 持有 = 1% × (1 + 进阶级)，上限 5%；掉落 = 20% + 10% × 进阶级。按对手手里的武器类配

const HOLD_KEY := "red_hold"
const HOLD_BASE := 0.01
const HOLD_CAP := 0.05
const DROP_BASE := 0.2
const DROP_STEP := 0.1
## 武器类的标签（弓弩看远程 + 爆发 / 快攻，[method class_of]）
const CLASS_TAGS: Array[StringName] = [&"staff", &"dual", &"dagger", &"polearm", &"two_hand", &"one_hand"]


## 劣化版摆不下时最多拿掉几件杂件腾地方
const MAKE_ROOM := 3


## 红武来路要的点档位（架构设计 10:22：和紫武器上限同一档）
const MIN_STRENGTH := 3


## 这一章出不出红武的来路：序章（教学图）不出，别的章都出（点没有档位时用它）
static func chapter_ok(chapter: ChapterDef) -> bool:
	return chapter != null and not String(chapter.id).begins_with("prologue")


## 这个点 / 这个对手够不够档：有档位看档位 ≥ [constant MIN_STRENGTH]，没有（-1）退回 [method chapter_ok]
static func strength_ok(strength: int, chapter: ChapterDef) -> bool:
	return strength >= MIN_STRENGTH if strength >= 0 else chapter_ok(chapter)


static func level_of(run: RunState) -> int:
	return maxi(0, run.difficulty.level) if run != null and run.difficulty != null else 0


static func hold_chance(level: int) -> float:
	return minf(HOLD_CAP, HOLD_BASE * float(1 + maxi(0, level)))


static func drop_chance(level: int) -> float:
	return clampf(DROP_BASE + DROP_STEP * float(maxi(0, level)), 0.0, 1.0)


## 武器类：法杖 / 双持 / 短兵 / 长柄 / 双手 / 单手 / 弓 / 弩；不是武器返回空
static func class_of(def: ItemDef) -> StringName:
	if def == null or not def.tags.has(&"weapon"):
		return &""
	for t in CLASS_TAGS:
		if def.tags.has(t):
			return t
	if def.tags.has(&"ranged"):
		return &"crossbow" if def.tags.has(&"burst") else &"bow"     # 弩全是爆发、弓全是快攻
	return &""


## 劣化版 id → 武器类
static func lesser_classes(items: ItemDatabase) -> Dictionary:
	var out := {}
	for id in items.all_ids():
		var d := items.get_def(id)
		if d != null and d.is_lesser():
			out[id] = class_of(d)
	return out


## 开战前（战前准备屏之前）掷一次持有，结果记进内容（[constant HOLD_KEY]：持有的 id，没持有是空串）—— 记过了就不再掷。
## 持有就把对手手里同类的一件换成这把劣化版（位置不合就重新摆）；摆不下当没持有。返回持有的 id
static func arm(content: Dictionary, run: RunState, rng: RandomNumberGenerator, roll: float = -1.0) -> StringName:
	if content.has(HOLD_KEY):
		return StringName(String(content[HOLD_KEY]))
	content[HOLD_KEY] = ""
	if run == null or run.items == null or not EnemyKit.has_enemy(content) \
			or not strength_ok(int(content.get("strength", -1)), run.chapter):
		return &""
	var r := rng.randf() if roll < 0.0 else roll
	if r >= hold_chance(level_of(run)):
		return &""
	var reds := lesser_classes(run.items)
	var ids: Array = reds.keys()
	ids.sort()
	var entries: Array = content.get("items", [])
	var options: Array = []     # [下标, 劣化版 id]
	for i in entries.size():
		var e := entries[i] as Dictionary
		var cls := class_of(run.items.get_def(StringName(String(e.get("id", ""))))) if e != null else &""
		if cls == &"":
			continue
		for id in ids:
			if reds[id] == cls:
				options.append([i, id])
	if options.is_empty():
		return &""
	var pick: Array = options[rng.randi_range(0, options.size() - 1)]
	var red: StringName = pick[1]
	var before: Array = entries.duplicate(true)
	var swapped := (entries[int(pick[0])] as Dictionary).duplicate()
	swapped["id"] = String(red)
	swapped.erase("state")
	entries[int(pick[0])] = swapped
	content["items"] = entries
	if not _fits(content, run.items):
		swapped.erase("at")
		swapped.erase("rot")
		EnemyPlacer.arrange(content, run.items, rng)
	# 架构设计 12:24：摆不下就拿掉最不值钱的非包、非武器件再摆，最多拿 [constant MAKE_ROOM] 件
	for k in MAKE_ROOM:
		if _held(content, red, run.items) or not _drop_cheapest(content, red, run.items):
			break
		EnemyPlacer.arrange(content, run.items, rng)
	if not _held(content, red, run.items):
		content["items"] = before
		return &""
	content[HOLD_KEY] = String(red)
	return red


## 打赢了：持有的那把按掉落率掷，掉了放进 dropped。返回掉没掉
static func roll_drop(content: Dictionary, run: RunState, rng: RandomNumberGenerator, rolled: Dictionary, roll: float = -1.0) -> bool:
	var red := StringName(String(content.get(HOLD_KEY, "")))
	if red == &"" or run == null:
		return false
	var r := rng.randf() if roll < 0.0 else roll
	if r >= drop_chance(level_of(run)):
		return false
	var dropped: Array = rolled.get("dropped", [])
	if not dropped.has(red):
		dropped.append(red)
	rolled["dropped"] = dropped
	return true


## 内容里写了位置的件都摆得下
static func _fits(content: Dictionary, items: ItemDatabase) -> bool:
	var size_raw: Array = content.get("board", [4, 3])
	var has_bag := false
	for raw in content.get("items", []):
		var d := items.get_def(StringName(String((raw as Dictionary).get("id", ""))))
		has_bag = has_bag or (d != null and d.is_bag)
	var board := GridInventory.new(Vector2i(int(size_raw[0]), int(size_raw[1])), 0, has_bag)
	var uid_mark := ItemInstance._next_uid
	var ok := true
	for pass_bags in [true, false]:
		for raw in content.get("items", []):
			var e := raw as Dictionary
			var d := items.get_def(StringName(String(e.get("id", ""))))
			if d == null or d.is_bag != pass_bags or not e.has("at"):
				continue
			var at: Array = e["at"]
			if not board.place(ItemInstance.create(d, int(e.get("rot", 0))), Vector2i(int(at[0]), int(at[1])), int(e.get("rot", 0))):
				ok = false
	ItemInstance._next_uid = uid_mark
	return ok


## 劣化版真的在棋盘上（有位置、和别的件不重叠）
static func _held(content: Dictionary, red: StringName, items: ItemDatabase) -> bool:
	for raw in content.get("items", []):
		var e := raw as Dictionary
		if StringName(String(e.get("id", ""))) == red:
			return e.has("at") and _fits(content, items)
	return false


## 拿掉一件最不值钱的非包、非武器件（劣化版本身不动），位置全清、等重摆。没得拿返回 false
static func _drop_cheapest(content: Dictionary, red: StringName, items: ItemDatabase) -> bool:
	var entries: Array = content.get("items", [])
	var at := -1
	var low := 1 << 30
	for i in entries.size():
		var e := entries[i] as Dictionary
		var d := items.get_def(StringName(String(e.get("id", "")))) if e != null else null
		if d == null or d.id == red or d.is_bag or d.tags.has(&"weapon") or bool(e.get("carried", false)):
			continue     # 包、武器、身上必掉的携带品不拿
		var v := ItemValue.of(d)
		if v < low:
			low = v
			at = i
	if at < 0:
		return false
	entries.remove_at(at)
	for v in entries:
		(v as Dictionary).erase("at")
		(v as Dictionary).erase("rot")
	content["items"] = entries
	return true
