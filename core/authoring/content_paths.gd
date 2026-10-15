## 内容管线的目录约定（架构文档 10.1）。
##
## [b]只有这一处定义。[/b] 编辑器写作者数据、命令行读作者数据、两边都产出引擎资产 ——
## 三方各写一份路径常量的话，某天改了目录就会出现「编辑器存到 A、导入器读 B」
## 这种谁都不报错、但内容就是不生效的情况。
class_name ContentPaths
extends RefCounted

#region 作者数据（人写的 JSON，进 git，MOD 作者改这里）
const AUTHORING := "res://data/authoring"
const AUTHORING_TAGS := AUTHORING + "/tags"
const AUTHORING_DAMAGE_TYPES := AUTHORING + "/damage_types"
const AUTHORING_ITEMS := AUTHORING + "/items"
const AUTHORING_LOADOUTS := AUTHORING + "/loadouts"
const AUTHORING_CHARACTERS := AUTHORING + "/characters"
const AUTHORING_DIFFICULTIES := AUTHORING + "/difficulties"
const AUTHORING_EVENTS := AUTHORING + "/events"
const AUTHORING_BUFFS := AUTHORING + "/buffs"
const AUTHORING_SETS := AUTHORING + "/sets"
## 146：规则构件库（扳机 / 节奏 / 消耗与检查 / 效果）
const AUTHORING_RULE_PARTS := AUTHORING + "/rule_parts"
const AUTHORING_RUN_BUFFS := AUTHORING + "/run_buffs"
const AUTHORING_FAITHS := AUTHORING + "/faiths"
const AUTHORING_RECIPES := AUTHORING + "/recipes"
const AUTHORING_ENEMIES := AUTHORING + "/enemies"
const AUTHORING_ENEMY_POOLS := AUTHORING + "/enemy_pools"
const AUTHORING_HUNTERS := AUTHORING + "/hunters"
const AUTHORING_DROP_RULES := AUTHORING + "/drop_rules"
const AUTHORING_CARRY_RULES := AUTHORING + "/carry_rules"
const AUTHORING_ENCUMBRANCE_RULES := AUTHORING + "/encumbrance_rules"     # 129
const AUTHORING_NODE_RULES := AUTHORING + "/node_rules"
const AUTHORING_ECONOMY_RULES := AUTHORING + "/economy_rules"
const AUTHORING_META_RULES := AUTHORING + "/meta_rules"
const AUTHORING_CHAPTERS := AUTHORING + "/chapters"
const AUTHORING_ACHIEVEMENTS := AUTHORING + "/achievements"
const AUTHORING_TECHS := AUTHORING + "/techs"
const AUTHORING_HELP_PAGES := AUTHORING + "/help_pages"
const AUTHORING_CHEST_SKINS := AUTHORING + "/chest_skins"     # 154
const AUTHORING_BELT_SKILLS := AUTHORING + "/belt_skills"     # 160 补一
const AUTHORING_REACTIONS := AUTHORING + "/reactions"     # 175
#endregion

#region 引擎资产（导入器产出，游戏读这里）
const TAGS := "res://data/tags"
const DAMAGE_TYPES := "res://data/damage_types"
const ITEMS := "res://data/items"
const LOADOUTS := "res://data/loadouts"
const CHARACTERS := "res://data/characters"
const DIFFICULTIES := "res://data/difficulties"
const EVENTS := "res://data/events"
const BUFFS := "res://data/buffs"
const SETS := "res://data/sets"
const RULE_PARTS := "res://data/rule_parts"
const RUN_BUFFS := "res://data/run_buffs"
const FAITHS := "res://data/faiths"
const RECIPES := "res://data/recipes"
const ENEMIES := "res://data/enemies"
const ENEMY_POOLS := "res://data/enemy_pools"
const HUNTERS := "res://data/hunters"
const DROP_RULES := "res://data/drop_rules"
const CARRY_RULES := "res://data/carry_rules"
const ENCUMBRANCE_RULES := "res://data/encumbrance_rules"
const NODE_RULES := "res://data/node_rules"
const ECONOMY_RULES := "res://data/economy_rules"
const META_RULES := "res://data/meta_rules"
const CHAPTERS := "res://data/chapters"
const ACHIEVEMENTS := "res://data/achievements"
const TECHS := "res://data/techs"
const HELP_PAGES := "res://data/help_pages"
const CHEST_SKINS := "res://data/chest_skins"
const BELT_SKILLS := "res://data/belt_skills"
const REACTIONS := "res://data/reactions"
#endregion

## 种类 → [作者数据目录, 资产目录]。顺序即导入顺序：后者可以按 id 引用前者。
##
## 100（作者定）：**`sets` 不在这里**，在 [constant EDITOR_ONLY_KINDS] 里 —— 独立的套装文件一份都还没有。
## 146：buff 有了独立文件（道具里按 id 引用），搬回来了；规则构件库 `rule_parts` 也在这里
const KINDS := {
	"tags": [AUTHORING_TAGS, TAGS],
	"damage_types": [AUTHORING_DAMAGE_TYPES, DAMAGE_TYPES],
	"run_buffs": [AUTHORING_RUN_BUFFS, RUN_BUFFS],
	"faiths": [AUTHORING_FAITHS, FAITHS],
	"buffs": [AUTHORING_BUFFS, BUFFS],
	"reactions": [AUTHORING_REACTIONS, REACTIONS],
	"rule_parts": [AUTHORING_RULE_PARTS, RULE_PARTS],
	"recipes": [AUTHORING_RECIPES, RECIPES],
	"items": [AUTHORING_ITEMS, ITEMS],
	"loadouts": [AUTHORING_LOADOUTS, LOADOUTS],
	"characters": [AUTHORING_CHARACTERS, CHARACTERS],
	"difficulties": [AUTHORING_DIFFICULTIES, DIFFICULTIES],
	"events": [AUTHORING_EVENTS, EVENTS],
	"enemies": [AUTHORING_ENEMIES, ENEMIES],
	"enemy_pools": [AUTHORING_ENEMY_POOLS, ENEMY_POOLS],
	"hunters": [AUTHORING_HUNTERS, HUNTERS],
	"drop_rules": [AUTHORING_DROP_RULES, DROP_RULES],
	"carry_rules": [AUTHORING_CARRY_RULES, CARRY_RULES],
	"encumbrance_rules": [AUTHORING_ENCUMBRANCE_RULES, ENCUMBRANCE_RULES],
	"node_rules": [AUTHORING_NODE_RULES, NODE_RULES],
	"economy_rules": [AUTHORING_ECONOMY_RULES, ECONOMY_RULES],
	"meta_rules": [AUTHORING_META_RULES, META_RULES],
	"chapters": [AUTHORING_CHAPTERS, CHAPTERS],
	"achievements": [AUTHORING_ACHIEVEMENTS, ACHIEVEMENTS],
	"techs": [AUTHORING_TECHS, TECHS],
	"help_pages": [AUTHORING_HELP_PAGES, HELP_PAGES],
	"chest_skins": [AUTHORING_CHEST_SKINS, CHEST_SKINS],
	"belt_skills": [AUTHORING_BELT_SKILLS, BELT_SKILLS],
}
## 开局装备、角色（初始包对着道具查）与敌人都在道具之后（清单、招牌道具、流派标签要对着道具查），池在敌人之后，三种规则独立，
## 章节按 id 引用池与规则；成就（091）排最后（对象可能是道具 / 章节）
## 096：标签与伤害类型最先（道具的标签对着它提醒；没有它们也能导）；110：局外科技在道具之后（要交的材料对着道具查）；114：百科的机制页最后（相关道具对着道具查）
## 154：宝箱皮肤在章节之前（章节按 id 引用它）
## 146：buff → 规则构件 → 道具（构件里的施加状态可以按 id 引用 buff；buff 自己的规则不能引用构件，所以没有环）
## 175：元素反应在 buff 之后（效果里按 id 施加 buff）
## 160 补一：随身技能排在前面（局外 buff、角色、事件、经济规则、章节、科技按 id 引用它）
const ORDER := ["tags", "damage_types", "belt_skills", "run_buffs", "faiths", "buffs", "reactions", "rule_parts", "items", "recipes", "loadouts", "characters", "difficulties", "events", "enemies", "enemy_pools", "hunters", "drop_rules", "carry_rules", "encumbrance_rules", "node_rules", "economy_rules", "meta_rules", "chest_skins", "chapters", "achievements", "techs", "help_pages"]


## 100（作者定）：有目录、但独立内容一份都还没有的种类 —— **不进 [constant KINDS]**（批量导入与一致性检查都不跑它们），
## 只有各自的编辑器在用（buff 制作器、套装编辑器自己写 JSON + `.tres`）。
## 真有了第一份独立内容，把这一行搬回 `KINDS` 并在 `ORDER` 里排在 `items` 之前，那份内容就自动进管线与检查
const EDITOR_ONLY_KINDS := {
	"sets": [AUTHORING_SETS, SETS],
}


## 这一种的两个目录（作者数据、资产）。不认识的种类返回空数组并报错 —— 路径还是只在这一处算
static func dirs_of(kind: String) -> Array:
	var pair: Variant = KINDS.get(kind, EDITOR_ONLY_KINDS.get(kind, null))
	if pair == null:
		push_error("ContentPaths: 不认识的内容种类 '%s'" % kind)
		return []
	return pair as Array


static func authoring_file(kind: String, id: String) -> String:
	var dirs := dirs_of(kind)
	return "%s/%s.json" % [dirs[0], id] if not dirs.is_empty() else ""


static func asset_file(kind: String, id: String) -> String:
	var dirs := dirs_of(kind)
	return "%s/%s.tres" % [dirs[1], id] if not dirs.is_empty() else ""


## 按种类与 id 装一份资产；文件不在（id 空、没导入过）返回 null。是什么类型由调用方自己认
static func load_asset(kind: String, id: String) -> Resource:
	var path := asset_file(kind, id)
	return load(path) if ResourceLoader.exists(path) else null


## 一个资产目录下的全部资源文件名（`.tres` / `.res`；导出后可能带 `.remap` 后缀，去掉一并认），按文件名升序；
## 打不开的目录返回空。以前十来处「扫目录装定义」各写一份这段循环，现在都从这里拿
static func resource_names(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			out.append(name)
	out.sort()
	return out


## 一个资产目录下的全部资源，按文件名顺序装进来（装不出来的跳过）。是什么类型由调用方自己认
static func load_resources(dir_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	for name in resource_names(dir_path):
		var res := ResourceLoader.load(dir_path.path_join(name))
		if res != null:
			out.append(res)
	return out


## 173 §3.5：内容版本戳 —— 道具、标签、信仰、章节、敌人、事件的资产文件名排序后的哈希（前 12 位）。写进存档头，
## 读档时报告「这份档存于内容版本 X，现为 Y」，只作诊断、不参与判断。一次进程算一次
static var _stamp: String = ""
const STAMP_KINDS := [ITEMS, TAGS, FAITHS, CHAPTERS, ENEMIES, EVENTS]


static func content_stamp() -> String:
	if _stamp == "":
		var parts: PackedStringArray = []
		for dir_path in STAMP_KINDS:
			parts.append(String(dir_path).get_file() + ":" + ",".join(resource_names(dir_path)))
		_stamp = "\n".join(parts).md5_text().substr(0, 12)
	return _stamp


## 一个作者数据目录下的全部 id：`.json` 文件的名字去掉后缀，按文件名升序；打不开的目录返回空。
## 四个内容编辑器的列表与地图编辑器的两个下拉框都从这里拿（以前各写一份同样的循环）
static func ids_in(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for f in files:
		if f.ends_with(".json"):
			out.append(f.get_basename())
	return out
