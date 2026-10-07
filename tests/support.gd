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
				c.events = GameFlow.load_events()
			"buffs":
				c.buffs = GameFlow.load_run_buffs()
			"faiths":
				c.faiths = GameFlow.load_faiths()
			"recipes":
				c.recipes = GameFlow.load_recipes()
			"characters":
				c.characters = GameFlow.load_characters()
			"brutus":
				for ch in GameFlow.load_characters():
					if ch.id == &"brutus":
						c.brutus = ch
			"hunter_defs":
				c.hunter_defs = GameFlow.load_hunters()
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
