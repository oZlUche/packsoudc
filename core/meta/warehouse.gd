## 仓库（163，作者定）：**一页一块格子**，各页独立、不共享空间；扩建加页（[TechWarehousePages]），不加行。
##
## 对外还是一个容器（[ItemContainer]）：发放、带回置入、开局带入 / 放回、一键出售、科技上交都只认 `get_item / remove / admit / items`，
## 不用知道有几页。自动放（[method admit] / [method try_add]）按页序落在第一页放得下的地方（163 待定 1 = A）。
## 界面一页一块视图（[member pages] 里的 [GridInventory]），拖拽、整理只动那一页。
##
## 任何一页变了，本容器发 `changed`（批量期间合并）。页的 id 是 [constant PAGE_ID_BASE] + 页号（别和带回来的棋盘撞号）
class_name Warehouse
extends ItemContainer

const PAGE_ID_BASE := 200
## 读档时放不下的东西最多临时加几页来放（之后有空页时科技重算会收回）
const RESCUE_PAGES := 4

## 一页多大（[MetaRules.warehouse_size]）
var page_size: Vector2i = Vector2i(10, 8)
## 各页，按页序
var pages: Array[GridInventory] = []
## 准入（[MetaState.keeps]）：设了就同步给每一页
var accept_filter: Callable = Callable():
	set(v):
		accept_filter = v
		for p in pages:
			p.accept_filter = v

## 老接口：一页的尺寸（139 的按宽放大、开局屏都按它算列数）
var size: Vector2i:
	get:
		return page_size


func _init(p_page_size: Vector2i = Vector2i(10, 8), p_id: int = 0, p_pages: int = 1) -> void:
	id = p_id
	page_size = p_page_size
	set_page_count(p_pages)


#region 页
func page_count() -> int:
	return pages.size()


func page(i: int) -> GridInventory:
	return pages[i] if i >= 0 and i < pages.size() else null


## 这件东西在第几页（不在仓库里 -1）
func page_of(uid: int) -> int:
	for i in pages.size():
		if pages[i].has_item(uid):
			return i
	return -1


## [param c] 是不是本仓库（或它的某一页）—— 界面拖拽 / 双击拿到的是页，比较「从仓库来的」用它
func owns(c: ItemContainer) -> bool:
	return c != null and (c == self or (c is GridInventory and pages.has(c)))     # 游戏测试 v4.50：地上的 ItemStash 问进来，typed 数组的 has 会报引擎错


## 页数变成 [param n]：多了在后面加空页；少了只删**末尾的空页**（碰到有东西的页停下并告警，和 120 的缩行一样）。返回变化后的页数
func set_page_count(n: int) -> int:
	var want := maxi(1, n)
	var grew := false
	while pages.size() < want:
		var p := GridInventory.new(page_size, PAGE_ID_BASE + pages.size(), false)
		p.accept_filter = accept_filter
		p.changed.connect(_notify_changed)
		pages.append(p)
		grew = true
	var shrank := false
	while pages.size() > want and pages[-1].item_count() == 0:
		(pages[-1] as GridInventory).changed.disconnect(_notify_changed)
		pages.pop_back()
		shrank = true
	if pages.size() > want:
		push_warning("Warehouse.set_page_count: 第 %d 页有东西，只缩到 %d 页（要 %d）" % [pages.size(), pages.size(), want])
	if grew or shrank:
		_notify_changed()
	return pages.size()
#endregion


#region 准入与放
func accepts(def: ItemDef) -> bool:
	return not pages.is_empty() and pages[0].accepts(def)


func admit(inst: ItemInstance) -> bool:
	return try_add(inst)


func can_admit(def: ItemDef) -> bool:
	for p in pages:
		if p.can_admit(def):
			return true
	return false


## 按页序找第一页放得下的。放不下返回 false，实例保持游离态
func try_add(inst: ItemInstance, allow_rotate: bool = true) -> bool:
	if inst == null:
		return false
	for p in pages:
		if p.try_add(inst, allow_rotate):
			return true
	return false


## 原位放不下的一件：按页序找空位，再不行临时加页（最多 [constant RESCUE_PAGES] 页）。返回加了几页；放不下返回 -1（实例保持游离态）。
## 读档（120 / 163）与 173 的「带回的背包放不回原位」都走这里
func rescue(inst: ItemInstance) -> int:
	var added := 0
	while not try_add(inst):
		if added >= RESCUE_PAGES:
			return -1
		set_page_count(page_count() + 1)
		added += 1
	return added


## 放到第 [param at_page] 页的 [param origin]
func place(inst: ItemInstance, origin: Vector2i, rot: int = 0, at_page: int = 0) -> bool:
	var p := page(at_page)
	return p != null and p.place(inst, origin, rot)
#endregion


#region 读取
func get_item(uid: int) -> ItemInstance:
	for p in pages:
		var inst := p.get_item(uid)
		if inst != null:
			return inst
	return null


func has_item(uid: int) -> bool:
	return page_of(uid) >= 0


## 按页序、页内按各页的顺序
func items() -> Array:
	var out: Array = []
	for p in pages:
		out.append_array(p.items())
	return out


func item_count() -> int:
	var n := 0
	for p in pages:
		n += p.item_count()
	return n


func remove(uid: int) -> ItemInstance:
	var i := page_of(uid)
	return pages[i].remove(uid) if i >= 0 else null
#endregion


#region 存档
func to_dict() -> Dictionary:
	var out: Array = []
	for p in pages:
		out.append(p.to_dict())
	return {"pages": out}


## 读回来。[param p_pages] > 0 = 页数已经算好（科技推算，120 的顺序），否则按存档里的页数。
## 新档逐页原位放；老档（163 之前，一块 `{"size", "items"}`）按页切：落在第一页范围里的原位放，更下面的按页序重摆。
## 原位放不下（页被改小、页数变少）的按页序找空位，再不行临时加页 —— 一件也不丢
## 173：挪了位置的记进 [param report]；加页也放不下的交给 [param homeless_out]（持有方折钱），没给照旧告警丢弃
static func from_dict(d: Dictionary, db: ItemDatabase, p_page_size: Vector2i, p_pages: int = 0,
		report: SaveReport = null, homeless_out: Variant = null) -> Warehouse:
	var page_dicts: Array = d.get("pages", []) if d.has("pages") else [d]
	var legacy := not d.has("pages")
	var count := p_pages
	if count <= 0:
		if legacy:
			var s: Array = d.get("size", [p_page_size.x, p_page_size.y])
			count = ceili(float(int(s[1])) / float(maxi(1, p_page_size.y)))
		else:
			count = page_dicts.size()
	var w := Warehouse.new(p_page_size, MetaState.WAREHOUSE_ID, maxi(1, count))
	var saved_seq := {}
	var homeless: Array = []
	w.begin_batch()
	for i in page_dicts.size():
		var raw_page = page_dicts[i]
		if not raw_page is Dictionary:
			continue
		for raw in (raw_page as Dictionary).get("items", []):
			var inst := ItemInstance.from_dict(raw, db)
			if inst == null:
				continue     # 定义已不存在，from_dict 已告警
			saved_seq[inst.uid] = inst.placed_seq
			var p := w.page(i)
			if p != null and p.place(inst, inst.origin, inst.rotation):
				continue
			homeless.append(inst)
	for inst in homeless:
		var rescued := w.rescue(inst)
		if rescued < 0:
			if homeless_out is Array:
				(homeless_out as Array).append(inst)
			else:
				push_warning("Warehouse.from_dict: uid %d 加页也放不下，已丢弃（定义比一页还大？）" % inst.uid)
			continue
		if report != null:
			report.rehome(inst.def.id, "warehouse", "warehouse.page%d" % (w.page_of(inst.uid) + 1))
		if rescued > 0:
			push_warning("Warehouse.from_dict: uid %d 放不下，临时加了 %d 页（东西不丢；之后空出来时科技重算会收回）" % [inst.uid, rescued])
	w.end_batch()
	for i in w.page_count():
		var p := w.page(i)
		var top := 0
		for inst in p.items():
			(inst as ItemInstance).placed_seq = int(saved_seq.get((inst as ItemInstance).uid, 0))
			top = maxi(top, (inst as ItemInstance).placed_seq)
		var pd: Variant = page_dicts[i] if i < page_dicts.size() else null
		p.place_seq = maxi(int((pd as Dictionary).get("place_seq", 0)) if pd is Dictionary else 0, top)
	return w
#endregion
