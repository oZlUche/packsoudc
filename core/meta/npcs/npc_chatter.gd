## 282（作者 2026-11-05 12:42 / 12:48）：NPC 说哪一句。
## 专属对话（[NpcSpecial]）条件都满足就先说它、一辈子一次，说完给道具；否则从开放的闲话里掷一句 ——
## 可以重复，只保证最近 [constant RECENT] 句不重复（[member MetaState.npc_said] 定长队列）；开放的不够就从最早说过的放开
class_name NpcChatter
extends RefCounted

const RECENT := 10

static var _defs: Dictionary = {}


## 全部 NPC（id → [NpcDef]）；没导入时空
static func defs() -> Dictionary:
	if _defs.is_empty():
		for res in ContentPaths.load_resources(ContentPaths.NPCS):
			if res is NpcDef:
				_defs[(res as NpcDef).id] = res
	return _defs


static func get_def(id: StringName) -> NpcDef:
	return defs().get(id, null)


## 条件看的上下文：局外 + 这一局（基地里 [param run] 是 null）
static func context(meta: MetaState, run: RunState = null, items: ItemDatabase = null) -> EventContext:
	var ctx := EventContext.new()
	ctx.meta = meta
	ctx.items = items
	if run != null:
		ctx.items = run.items
		ctx.board = run.board
		ctx.storage = run.storage
		ctx.hooks = run.events.hooks if run.events != null else ctx.hooks
	return ctx


static func _open(requires: Array[EventCondition], ctx: EventContext) -> bool:
	for c in requires:
		if c != null and not c.check(ctx):
			return false
	return true


## 这会儿该说的专属对话（没做过、条件都满足）；没有 null
static func special_for(def: NpcDef, meta: MetaState, run: RunState = null, items: ItemDatabase = null) -> NpcSpecial:
	if def == null:
		return null
	var ctx := context(meta, run, items)
	for sp in def.specials:
		if sp != null and not done(meta, sp.id) and _open(sp.requires, ctx):
			return sp
	return null


static func done(meta: MetaState, special_id: StringName) -> bool:
	return meta != null and bool(meta.npc_done.get(String(special_id), false))


## 开放的闲话（条件都满足的）
static func open_lines(def: NpcDef, meta: MetaState, run: RunState = null, items: ItemDatabase = null) -> Array[NpcLine]:
	var out: Array[NpcLine] = []
	if def == null:
		return out
	var ctx := context(meta, run, items)
	for l in def.lines:
		if l != null and _open(l.requires, ctx):
			out.append(l)
	return out


## 掷一句：排除最近说过的 [constant RECENT] 句；开放的不够就从最早说过的那句起放开，直到有得挑。记进队列。没有开放的 null
static func next_line(def: NpcDef, meta: MetaState, rng: RandomNumberGenerator, run: RunState = null, items: ItemDatabase = null) -> NpcLine:
	var open := open_lines(def, meta, run, items)
	if open.is_empty():
		return null
	var said: Array = recent(meta, def.id)
	var pool: Array[NpcLine] = []
	for skip in range(mini(said.size(), RECENT), -1, -1):
		var banned: Array = said.slice(said.size() - skip)
		pool.assign(open.filter(func(l: NpcLine) -> bool: return not banned.has(String(l.id))))
		if not pool.is_empty():
			break
	var pick: NpcLine = pool[rng.randi_range(0, pool.size() - 1)]
	_remember(meta, def.id, pick.id)
	return pick


## 这个 NPC 最近说过的句 id（旧的在前，最多 [constant RECENT] 句）
static func recent(meta: MetaState, npc: StringName) -> Array:
	return (meta.npc_said.get(String(npc), []) as Array).duplicate() if meta != null else []


static func _remember(meta: MetaState, npc: StringName, line: StringName) -> void:
	if meta == null:
		return
	var q := recent(meta, npc)
	q.append(String(line))
	while q.size() > RECENT:
		q.pop_front()
	meta.npc_said[String(npc)] = q


## 点一下头像：专属对话优先（记作做过、给道具），否则掷一句闲话。
## 返回 {"text": 这一句（当前语言；可能是空的，作者还没写）, "special": 专属对话 id（闲话是空）, "given": 给了的道具 id（没给空）}；这个 NPC 一句都没有返回空字典
static func talk(npc: StringName, meta: MetaState, items: ItemDatabase, rng: RandomNumberGenerator, run: RunState = null) -> Dictionary:
	var def := get_def(npc)
	if def == null:
		return {}
	var sp := special_for(def, meta, run, items)
	if sp != null:
		meta.npc_done[String(sp.id)] = true
		var given := _give(sp.give, meta, items, run)
		return {"text": Names.pick(sp.texts, sp.text), "special": sp.id, "given": given}
	var line := next_line(def, meta, rng, run, items)
	if line == null:
		return {}
	return {"text": Names.pick(line.texts, line.text), "special": &"", "given": &""}


## 专属对话给的道具进仓库（满了临时加页）；独一道具已有就不给
static func _give(id: StringName, meta: MetaState, items: ItemDatabase, run: RunState) -> StringName:
	if id == &"" or meta == null or items == null or meta.warehouse == null:
		return &""
	var d := items.get_def(id)
	if d == null or not UniqueItems.can_give(d, meta, run, items):
		return &""
	return id if meta.warehouse.rescue(ItemInstance.create(d)) >= 0 else &""
