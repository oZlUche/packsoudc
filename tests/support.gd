## 套件共用的帮助函数（102 第 A-5 条）：装内容。临时文件路径与收尾在 `tests/run/flow_support.gd`。
##
## 以前每个套件各写一份 `_content()` / `_cleanup()`，改一处内容装载要改十几个文件。
## 100 第 4 步落地之后 [method content] 就是 `ContentLibrary.load_all()` 的一行转发。
class_name TestSupport
extends RefCounted


## 一个套件要的内容。字段是各套件原来自带的 `Content` 的并集（精简 T-1：21 份各抄一份收成这一份）。
## 道具 / 敌人 / 套装 / 章节每个套件都要，[method load_content] 总装；其余按名字要 —— 没要的留空，
## `flow_support.flow` 把它们接进 [GameFlow] 时等于没接，原来没装事件的套件不会忽然多出事件层。
class Content:
	extends RefCounted
	## 道具库（全部套件）
	var items: ItemDatabase
	## 敌人库（全部套件）
	var enemies: EnemyDatabase
	## 套装库（除 test_carry 外全部；多装一份不碍事）
	var sets: SetDatabase
	## 主章节：默认自由模式；test_prologue3 / test_tutorial2 要自己的序章
	var chapter: ChapterDef
	## 主章节的敌人池（test_text_and_tooltips / test_carry）
	var pool: EnemyPool
	## 序章一（test_node_screens / test_tutorial2 / test_prologue）
	var prologue: ChapterDef
	## 序章二（test_prologue3）
	var prologue2: ChapterDef
	## 自由模式，序章套件拿来验「通关解锁第一章」（test_prologue / test_tutorial2 / test_prologue3）
	var chapter1: ChapterDef
	## 开局装备（test_node_screens / test_meta_grid / test_event_layer / test_node_storage / test_character_setup /
	## test_game_flow / test_author_087 / test_run_buffs / test_calibration）
	var loadouts: Array[LoadoutDef]
	## 事件表（test_node_screens / test_event_layer / test_prologue3 / test_author_087 / test_tutorial2 / test_prologue /
	## test_event_constructs）
	var events: Dictionary
	## 一局 buff 表（test_event_layer / test_encumbrance / test_run_buffs）
	var buffs: Dictionary
	## 信仰表（test_prologue3 / test_prologue）
	var faiths: Dictionary
	## 配方（test_tutorial2）
	var recipes: Array[RecipeDef]
	## 角色（test_character_setup / test_prologue / test_character_skills）
	var characters: Array[CharacterDef]
	## 布鲁图斯一个人（test_prologue3 / test_tutorial2）
	var brutus: CharacterDef
	## 猎手表（test_hunters / test_character_skills / test_calibration —— 后者原来叫 hunters）
	var hunter_defs: Dictionary
	## 难度（test_difficulty / test_erosion）
	var difficulties: Array[DifficultyDef]
	## 局外规则（test_meta_grid / test_character_setup —— 原来叫 rules，和下面的节点规则撞名才分开）
	var meta_rules: MetaRules
	## 主章节的节点规则（test_event_layer / test_event_constructs —— 原来叫 rules）
	var node_rules: NodeRules
	## 主章节的携带规则（test_carry）
	var carry: CarryRule
	## 主章节的预设图。解析要跑地图源，套件自己填（test_tutorial2）
	var graph: MapGraph


## 装一个套件要的内容：道具 / 敌人 / 套装、主章节 [param chapter_id] 与它的敌人池、三个固定章节总装；
## [param wants] 里点名的再装，认这些名字：loadouts / events / buffs / faiths / recipes / characters / brutus /
## hunter_defs / difficulties / meta_rules / node_rules / carry。
## 各套件原来装什么就要什么，别多要 —— 多要的表会被 `flow_support.flow` 接进一局，那套件的行为就变了。
static func load_content(chapter_id: String = "free_mode", wants: PackedStringArray = PackedStringArray()) -> Content:
	var c := Content.new()
	c.items = ItemDatabase.new()
	c.items.load_dir()
	c.enemies = EnemyDatabase.new()
	c.enemies.load_all()
	c.sets = SetDatabase.new()
	c.sets.load_dir()
	c.chapter = load(ContentPaths.asset_file("chapters", chapter_id))
	c.pool = c.enemies.pool(c.chapter.enemy_pool)
	c.prologue = load(ContentPaths.asset_file("chapters", "prologue"))
	c.prologue2 = load(ContentPaths.asset_file("chapters", "prologue_2"))
	c.chapter1 = load(ContentPaths.asset_file("chapters", "free_mode"))
	for w in wants:
		match w:
			"loadouts":
				c.loadouts = GameFlow.load_loadouts()
			"events":
				c.events = EventPlacer.load_all()
			"buffs":
				c.buffs = RunBuffs.load_all()
			"faiths":
				c.faiths = FaithDef.load_all()
			"recipes":
				c.recipes = RecipeDef.load_all()
			"characters":
				c.characters = GameFlow.load_characters()
			"brutus":
				for ch in GameFlow.load_characters():
					if ch.id == &"brutus":
						c.brutus = ch
			"hunter_defs":
				c.hunter_defs = HunterSystem.load_all()
			"difficulties":
				c.difficulties = GameFlow.load_difficulties()
			"meta_rules":
				c.meta_rules = GameFlow.load_meta_rules()
			"node_rules":
				c.node_rules = load(ContentPaths.asset_file("node_rules", String(c.chapter.node_rules)))
			"carry":
				c.carry = load(ContentPaths.asset_file("carry_rules", String(c.chapter.carry_rule)))
			_:
				push_error("TestSupport.load_content：不认识的内容名「%s」" % w)
	return c


## 敌人目录里的全部敌人 id（`EnemyDatabase.load_all` 装的就是这些；140 删了库上只有测试用的 enemy_ids）
static func enemy_ids() -> Array:
	return _ids_in(EnemyDatabase.ENEMY_DIR, EnemyDef)


## 敌人池目录里的全部池 id（同上，对应删掉的 pool_ids）
static func pool_ids() -> Array:
	return _ids_in(EnemyDatabase.POOL_DIR, EnemyPool)


static func _ids_in(dir_path: String, type: Variant) -> Array:
	var out: Array = []
	for res in ContentPaths.load_resources(dir_path):
		if is_instance_of(res, type) and not out.has(res.id):
			out.append(res.id)
	return out


## 池里这个敌人的那一行；没有返回 null（140 删了 EnemyPool.entry_of，只有测试在查）
static func pool_entry(pool: EnemyPool, enemy_id: StringName) -> EnemyPoolEntry:
	for e in pool.entries:
		if e != null and e.enemy == enemy_id:
			return e
	return null


## 一份内容（道具、敌人、套装、buff、事件、章节、关卡与角色……）。
## 返回字典而不是一个类型，是为了和现有套件里的 `_content()` 形状一致，搬过来不用改断言
static func content() -> Dictionary:
	var c := load_content("free_mode", ["buffs", "events", "faiths", "recipes", "loadouts", "characters", "hunter_defs", "difficulties"])
	return {
		"items": c.items,
		"enemies": c.enemies,
		"sets": c.sets,
		"buffs": c.buffs,
		"events": c.events,
		"faiths": c.faiths,
		"recipes": c.recipes,
		"chapters": GameFlow.load_chapters(),
		"loadouts": c.loadouts,
		"characters": c.characters,
		"hunters": c.hunter_defs,
		"difficulties": c.difficulties,
	}


#region 摆道具：自己找空位，不写死坐标
## 道具的形状随时会被作者在编辑器里改（143 之后一件装备可能是任意不规则形状），
## 测试把道具摆在写死的坐标上、或假设「防弹衣是 2×2」，改一次形状就红一片，而被测的行为一点没变。
## 这一组帮助函数让套件只说「放进去」「放在不挨着它的地方」「放在它的增益格上」，
## 位置由棋盘自己找。找不到返回 null / 空字典 —— 套件用 `t.not_null` 接住，红得明明白白。
##
## 只有专门测几何的套件（放置、顶替、包、整理）和 143「主数值 ÷ 格数」才该关心坐标与形状。

## [param what] 可以是 [ItemDef] 或还没放进任何容器的 [ItemInstance]；统一成实例
static func _inst(what) -> ItemInstance:
	if what is ItemInstance:
		return what
	if what is ItemDef:
		return ItemInstance.create(what, 0)
	return null


## 放进棋盘第一个放得下的位置（可旋转）。放不下返回 null
static func put(board: GridInventory, what) -> ItemInstance:
	var inst := _inst(what)
	if inst == null or not board.try_add(inst, true):
		return null
	return inst


## 放进第一个满足 [param ok] 的位置：逐个落点 / 朝向试，候选位置先写进实例（origin / rotation），
## 再问 `ok.call(inst) -> bool`，所以判断里可以直接用 [method cells_of] / [method markers_of]。放不下返回 null
static func put_where(board: GridInventory, what, ok: Callable) -> ItemInstance:
	var inst := _inst(what)
	if inst == null or inst.def == null:
		return null
	var rots := inst.def.shape.distinct_rotation_count() if inst.def.shape != null else 1
	for y in board.size.y:
		for x in board.size.x:
			for rot in rots:
				var at := Vector2i(x, y)
				if not board.can_place_item(inst, at, rot):
					continue
				inst.origin = at
				inst.rotation = rot
				if ok.call(inst) and board.place(inst, at, rot):
					return inst
	return null


## 放在和 [param others] 里每一件都**不连结**的地方：谁的增益 / 受益格都压不到对方
static func put_apart(board: GridInventory, what, others: Array) -> ItemInstance:
	return put_where(board, what, func(inst: ItemInstance) -> bool:
		for o in others:
			if touches(inst, o as ItemInstance):
				return false
		return true)


## 放在 [param holder] 的增益格上（会吃到它的邻接加成）
static func put_on_grant(board: GridInventory, what, holder: ItemInstance) -> ItemInstance:
	return put_where(board, what, func(inst: ItemInstance) -> bool:
		return grants_to(holder, inst))


## 放在增益格能盖到 [param targets] 每一件的地方（它给它们加成 / 挂规则）
static func put_granting(board: GridInventory, what, targets: Array) -> ItemInstance:
	return put_where(board, what, func(inst: ItemInstance) -> bool:
		for o in targets:
			if not grants_to(inst, o as ItemInstance):
				return false
		return true)


## [param holder] 的增益格压没压在 [param target] 身上
static func grants_to(holder: ItemInstance, target: ItemInstance) -> bool:
	return _overlap(grant_cells_of(holder), cells_of(target))


## 实例当前占的格子（绝对坐标）
static func cells_of(inst: ItemInstance) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in inst.cells():
		out.append(inst.origin + c)
	return out


## 实例占着的某一格（点击、悬停用）。原点不一定被占 —— 不规则形状的包围盒左上角可能是空的
static func a_cell_of(inst: ItemInstance) -> Vector2i:
	var cs := cells_of(inst)
	return cs[0] if not cs.is_empty() else inst.origin


## 实例的增益格（绝对坐标）；没有邻接定义返回空
static func grant_cells_of(inst: ItemInstance) -> Array[Vector2i]:
	if inst.def == null or inst.def.adjacency == null:
		return [] as Array[Vector2i]
	return inst.absolute_cells(inst.def.adjacency.grant_cells)


## 实例的增益格 + 受益格（绝对坐标）
static func markers_of(inst: ItemInstance) -> Array[Vector2i]:
	var out := grant_cells_of(inst)
	if inst.def != null and inst.def.adjacency != null:
		out.append_array(inst.absolute_cells(inst.def.adjacency.receive_cells))
	return out


## [param holder] 的增益格或受益格压没压在 [param target] 身上（压着就点亮，[BattleCompiler] 的连结就是这么算的）
static func lights(holder: ItemInstance, target: ItemInstance) -> bool:
	return _overlap(markers_of(holder), cells_of(target))


## 两件之间有没有邻接连结（任一方的标记格压在另一方身上）
static func touches(a: ItemInstance, b: ItemInstance) -> bool:
	return lights(a, b) or lights(b, a)


static func _overlap(xs: Array[Vector2i], ys: Array[Vector2i]) -> bool:
	for p in xs:
		if ys.has(p):
			return true
	return false


## 同一容器里给这件找个**别的**落点（换位置用）：{"origin", "rotation"}；没有返回空字典
static func other_spot(board: GridInventory, inst: ItemInstance) -> Dictionary:
	var rots := inst.def.shape.distinct_rotation_count() if inst.def.shape != null else 1
	for y in board.size.y:
		for x in board.size.x:
			for rot in rots:
				var at := Vector2i(x, y)
				if at != inst.origin and board.can_place_item(inst, at, rot):
					return {"origin": at, "rotation": rot}
	return {}


## 顶替式放进来，且**真的顶掉了**至少一件：返回被顶出来的实例；哪儿都顶不成返回 null
static func displace_somewhere(board: GridInventory, what):
	var inst := _inst(what)
	if inst == null or inst.def == null:
		return null
	var rots := inst.def.shape.distinct_rotation_count() if inst.def.shape != null else 1
	for y in board.size.y:
		for x in board.size.x:
			for rot in rots:
				var at := Vector2i(x, y)
				if not board.terrain_allows(inst.def, at, rot) or board.displaced_by(inst.def, at, rot).is_empty():
					continue
				var victims = board.place_displacing(inst, at, rot)
				if victims != null:
					return victims
	return null


## 一件指定形状的假道具（测「放不放得下」这类和真实内容形状无关的行为）
static func block_def(id: StringName, rows: Array) -> ItemDef:
	var d := ItemDef.new()
	d.id = id
	d.display_name = String(id)
	d.shape = ItemShape.from_ascii(rows)
	return d
#endregion
