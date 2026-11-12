## 313（试玩切片 S1 第三批）：切片清单核对 —— 清单（data/manifests/<切片>.json）和章节、地图、配方、敌人、事件对不对得上。
## 静态的几条：不认识的 id、空的货架 / 搜索、撤离点走得到、配方原料有来源、清单外的配方做不出来、敌人的东西摆得下；
## 再按种子整局走一遍（每个点都去、事件选第一个能选的、搜到底、打、看货不买），见过的道具都得在清单里。
## 每条问题一行文字；没有问题 = 空表
class_name SliceAudit
extends RefCounted

const DIR := "res://data/manifests"

## 走一局最多做多少步（防止事件绕圈）
const MAX_ACTIONS := 400


static func load_manifest(id: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [DIR, id]))
	return d if d is Dictionary else {}


static func _strs(a: Variant) -> Array[String]:
	var out: Array[String] = []
	if a is Array:
		for x in a:
			out.append(String(x))
	return out


## 地图节点内容里写到的道具 id（敌人身上的、保底掉落、搜索写死的、货架、搜索遭遇）
static func content_ids(content: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for e in content.get("items", []):
		out.append(String(e["id"]))
	out.append_array(_strs(content.get("guaranteed_drops", [])))
	for round_ in content.get("search_finds", []):
		out.append_array(_strs(round_))
	out.append_array(_strs(content.get(ShopSession.FIXED_KEY, [])))
	if content.get("encounter", null) is Dictionary:
		out.append_array(content_ids(content["encounter"]))
	return out


static func _map_dict(ch: ChapterDef) -> Dictionary:
	if ch == null or ch.map_source == null or ch.map_source.mode != MapSource.Mode.PRESET:
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ch.map_source.preset_path))
	return d if d is Dictionary else {}


## 静态核对；[param recipes] 是全部配方（清单外的也要看，看它做不做得出来）
static func check_static(m: Dictionary, items: ItemDatabase, enemies: EnemyDatabase, recipes: Array, events: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	var allowed := _strs(m.get("allowed_item_ids", []))
	for id in allowed:
		if items.get_def(StringName(id)) == null:
			bad.append("清单里的道具 %s 不存在" % id)
	var recipe_ids := _strs(m.get("recipe_ids", []))
	var by_id := {}
	for r in recipes:
		by_id[String((r as RecipeDef).id)] = r
	for id in recipe_ids:
		if not by_id.has(id):
			bad.append("清单里的配方 %s 不存在" % id)
	for id in _strs(m.get("enemy_ids", [])):
		if enemies.enemy(StringName(id)) == null:
			bad.append("清单里的敌人 %s 不存在" % id)
	for id in _strs(m.get("event_ids", [])):
		if not events.has(StringName(id)):
			bad.append("清单里的事件 %s 不存在" % id)
	var ch := ContentPaths.load_asset("chapters", String(m.get("chapter", ""))) as ChapterDef
	if ch == null:
		bad.append("清单的章节 %s 不存在" % m.get("chapter", ""))
		return bad
	var d := _map_dict(ch)
	if d.is_empty():
		bad.append("章节 %s 不是读得出来的预设地图" % ch.id)
		return bad
	# 来源：开局 + 地图上写到的，按件数记（短剑全图一把，就拼不出要两把短剑的配方）
	var sources := {}
	for id in ch.starting_items:
		sources[String(id)] = int(sources.get(String(id), 0)) + 1
		if not allowed.has(String(id)):
			bad.append("开局道具 %s 不在清单里" % id)
	for id in ch.characters:
		if String(id) != String(m.get("character", "")):
			bad.append("章节的角色 %s 不是清单的角色" % id)
	var enemy_ids := _strs(m.get("enemy_ids", []))
	var event_ids := _strs(m.get("event_ids", []))
	for n in d.get("nodes", []):
		var c: Dictionary = n.get("content", {})
		var nid := int(n["id"])
		for id in content_ids(c):
			sources[id] = int(sources.get(id, 0)) + 1
			if items.get_def(StringName(id)) == null:
				bad.append("点 %d 的道具 %s 不存在" % [nid, id])
			elif not allowed.has(id):
				bad.append("点 %d 的道具 %s 不在清单里" % [nid, id])
		if String(n["type"]) == "shop" and _strs(c.get(ShopSession.FIXED_KEY, [])).is_empty():
			bad.append("商店点 %d 没有写死的货架（会按正式版随机抽货）" % nid)
		if String(n["type"]) == "search":
			var finds: Array = c.get("search_finds", [])
			if finds.is_empty() or finds.any(func(r) -> bool: return not (r is Array) or (r as Array).is_empty()):
				bad.append("搜索点 %d 有一轮没写搜到什么（会按正式版随机抽）" % nid)
		if c.has("event") and not event_ids.has(String(c["event"])):
			bad.append("点 %d 的事件 %s 不在清单里" % [nid, c["event"]])
		var foes: Array = []
		if c.has("enemy"):
			foes.append(c)
		if c.get("encounter", null) is Dictionary:
			foes.append(c["encounter"])
		for foe in foes:
			var eid := String(foe.get("enemy", ""))
			if not enemy_ids.has(eid):
				bad.append("点 %d 的敌人 %s 不在清单里" % [nid, eid])
			if enemies.enemy(StringName(eid)) != null and not EnemyKit.unplaced_items(foe, items).is_empty():
				bad.append("点 %d 的敌人 %s 有东西摆不下：%s" % [nid, eid, EnemyKit.unplaced_items(foe, items)])
	# 配方：做得出来的（原料件数够）一直合下去，直到不再多出东西；合出来的算一件
	var grew := true
	while grew:
		grew = false
		for r in recipes:
			var rd := r as RecipeDef
			if not sources.has(String(rd.output)) and _enough(rd, sources):
				sources[String(rd.output)] = 1
				grew = true
	for r in recipes:
		var rd := r as RecipeDef
		var makeable := _enough(rd, sources)
		if recipe_ids.has(String(rd.id)):
			if not makeable:
				bad.append("配方 %s 的原料在切片里不够（要 %s）" % [rd.id, rd.inputs])
			if not allowed.has(String(rd.output)):
				bad.append("配方 %s 的成品 %s 不在清单里" % [rd.id, rd.output])
		elif makeable:
			bad.append("清单外的配方 %s 在切片里做得出来（成品 %s）" % [rd.id, rd.output])
	# 撤离点：从出生点都走得到
	var g := MapGraph.from_dict(d)
	if g == null:
		bad.append("地图读不成图")
		return bad
	var seen := {}
	var queue: Array = []
	for e in g.entry_ids:
		seen[int(e)] = true
		queue.append(int(e))
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for nb in g.neighbors(at):
			if not seen.has(int(nb)):
				seen[int(nb)] = true
				queue.append(int(nb))
	var exits := 0
	for n in d.get("nodes", []):
		if String(n["type"]) == "extract":
			exits += 1
			if not seen.has(int(n["id"])):
				bad.append("撤离点 %d 从出生点走不到" % int(n["id"]))
	if exits == 0:
		bad.append("地图上没有撤离点")
	return bad


## [param sources] 里每种原料的件数够不够 [param rd] 要的
static func _enough(rd: RecipeDef, sources: Dictionary) -> bool:
	for x in rd.inputs:
		if int(sources.get(String(x), 0)) < rd.inputs.count(x):
			return false
	return true


## 一局里眼下能看见的道具（背包、地上、待拾取、开着的搜索、开着的店）
static func _visible_ids(s: RunState) -> Array[String]:
	var out: Array[String] = []
	var boxes: Array = [s.board, s.storage, s.pending_loot]
	if s.events.current_search != null:
		boxes.append(s.events.current_search.haul())
	if s.events.current_shop != null:
		boxes.append(s.events.current_shop.board)
	for box in boxes:
		if box == null:
			continue
		for inst in (box as ItemContainer).items():
			out.append(String((inst as ItemInstance).def.id))
	return out


## 把眼下能处理的都处理掉：事件选第一个能选的、搜到底、开打、看完货走人、待拾取全拿。返回做了几步（0 = 没事可做）
static func _settle(s: RunState, log_: Dictionary) -> int:
	var acted := 0
	for _k in MAX_ACTIONS:
		if s.is_over():
			break
		for id in _visible_ids(s):
			log_[id] = true
		var ev := s.events
		if ev.current_search != null and ev.current_search.active:
			if ev.current_search.can_search():
				ev.current_search.search()
			else:
				ev.pause_search()
		elif ev.pending_event() != null:
			var picked := -1
			for i in ev.pending_event().options.size():
				if bool(ev.option_state(i)["ok"]):
					picked = i
					break
			if picked < 0 or not ev.choose(picked):
				break
		elif ev.pending_battle_node() != null:
			if not ev.start_pending_battle():
				break
		elif ev.current_shop != null:
			ev.current_shop.leave()
		elif s.pending_loot != null:
			s.take_all_loot()
			if s.pending_loot != null:
				s.discard_loot()
		else:
			break
		acted += 1
	for id in _visible_ids(s):
		log_[id] = true
	return acted


static func _path(g: MapGraph, from: int, to: int) -> Array[int]:
	var prev := {from: -1}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var here: int = queue.pop_front()
		if here == to:
			break
		for nb in g.neighbors(here):
			if not prev.has(int(nb)):
				prev[int(nb)] = here
				queue.append(int(nb))
	var out: Array[int] = []
	if not prev.has(to):
		return out
	var at := to
	while at != from:
		out.push_front(at)
		at = int(prev[at])
	return out


## 按 [param seed] 整局走一遍：按节点编号挨个去（走不到的跳过），最后去最近的撤离点。返回见过的道具 id
static func walk(m: Dictionary, p_seed: int, items: ItemDatabase, enemies: EnemyDatabase, sets: SetDatabase) -> Dictionary:
	var log_ := {}
	var ch := ContentPaths.load_asset("chapters", String(m.get("chapter", ""))) as ChapterDef
	var who := ContentPaths.load_asset("characters", String(m.get("character", ""))) as CharacterDef
	var s := RunState.start(ch, p_seed, items, enemies, sets, [] as Array[StringName], RunBuffs.load_all(), [] as Array[StringName], who)
	if s == null:
		return log_
	s.event_defs = EventPlacer.load_all()
	if s.travel.current_id < 0:
		s.pick_spawn(s.map.entry_ids[0])
	_settle(s, log_)
	var ids := s.map.node_ids()
	ids.sort()
	var exits: Array[int] = []
	for id in ids:
		if s.map.get_node(id).type == &"extract":
			exits.append(id)
			continue
		for step in _path(s.map, s.travel.current_id, id):
			if s.is_over() or not s.step_to(step):
				break
			_settle(s, log_)
	for id in exits:
		if s.is_over():
			break
		for step in _path(s.map, s.travel.current_id, id):
			if s.is_over() or not s.step_to(step):
				break
			_settle(s, log_)
		s.try_extract()
	s.dispose()
	return log_


## 全套：静态几条 + [param seeds] 个种子整局走。返回 {"problems": 问题表, "seen": 见过的道具 id（排好序）}
static func run_all(m: Dictionary, seeds: int) -> Dictionary:
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var problems := check_static(m, items, enemies, RecipeDef.load_all(), EventPlacer.load_all())
	var allowed := _strs(m.get("allowed_item_ids", []))
	var seen := {}
	for k in range(1, seeds + 1):
		var log_ := walk(m, k, items, enemies, sets)
		if log_.is_empty():
			problems.append("种子 %d 开不了局" % k)
		for id in log_:
			seen[id] = true
			if not allowed.has(String(id)):
				problems.append("种子 %d 见到了清单外的 %s" % [k, id])
	var ids: Array = seen.keys()
	ids.sort()
	return {"problems": problems, "seen": ids}
