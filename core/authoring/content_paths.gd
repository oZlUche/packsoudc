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
const AUTHORING_RUN_BUFFS := AUTHORING + "/run_buffs"
const AUTHORING_FAITHS := AUTHORING + "/faiths"
const AUTHORING_RECIPES := AUTHORING + "/recipes"
const AUTHORING_ENEMIES := AUTHORING + "/enemies"
const AUTHORING_ENEMY_POOLS := AUTHORING + "/enemy_pools"
const AUTHORING_HUNTERS := AUTHORING + "/hunters"
const AUTHORING_DROP_RULES := AUTHORING + "/drop_rules"
const AUTHORING_CARRY_RULES := AUTHORING + "/carry_rules"
const AUTHORING_NODE_RULES := AUTHORING + "/node_rules"
const AUTHORING_ECONOMY_RULES := AUTHORING + "/economy_rules"
const AUTHORING_META_RULES := AUTHORING + "/meta_rules"
const AUTHORING_CHAPTERS := AUTHORING + "/chapters"
const AUTHORING_ACHIEVEMENTS := AUTHORING + "/achievements"
const AUTHORING_TECHS := AUTHORING + "/techs"
const AUTHORING_HELP_PAGES := AUTHORING + "/help_pages"
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
const RUN_BUFFS := "res://data/run_buffs"
const FAITHS := "res://data/faiths"
const RECIPES := "res://data/recipes"
const ENEMIES := "res://data/enemies"
const ENEMY_POOLS := "res://data/enemy_pools"
const HUNTERS := "res://data/hunters"
const DROP_RULES := "res://data/drop_rules"
const CARRY_RULES := "res://data/carry_rules"
const NODE_RULES := "res://data/node_rules"
const ECONOMY_RULES := "res://data/economy_rules"
const META_RULES := "res://data/meta_rules"
const CHAPTERS := "res://data/chapters"
const ACHIEVEMENTS := "res://data/achievements"
const TECHS := "res://data/techs"
const HELP_PAGES := "res://data/help_pages"
#endregion

## 种类 → [作者数据目录, 资产目录]。顺序即导入顺序：后者可以按 id 引用前者。
##
## 100（作者定）：**`buffs` / `sets` 不在这里**，在 [constant EDITOR_ONLY_KINDS] 里 —— 独立的 buff / 套装文件一份都还没有
## （buff 现在都写在道具里），两边都是空目录，登记在这里只是让批量导入与一致性检查（[ContentCheck]）多跑两种空的。
const KINDS := {
	"tags": [AUTHORING_TAGS, TAGS],
	"damage_types": [AUTHORING_DAMAGE_TYPES, DAMAGE_TYPES],
	"run_buffs": [AUTHORING_RUN_BUFFS, RUN_BUFFS],
	"faiths": [AUTHORING_FAITHS, FAITHS],
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
	"node_rules": [AUTHORING_NODE_RULES, NODE_RULES],
	"economy_rules": [AUTHORING_ECONOMY_RULES, ECONOMY_RULES],
	"meta_rules": [AUTHORING_META_RULES, META_RULES],
	"chapters": [AUTHORING_CHAPTERS, CHAPTERS],
	"achievements": [AUTHORING_ACHIEVEMENTS, ACHIEVEMENTS],
	"techs": [AUTHORING_TECHS, TECHS],
	"help_pages": [AUTHORING_HELP_PAGES, HELP_PAGES],
}
## 开局装备、角色（初始包对着道具查）与敌人都在道具之后（清单、招牌道具、流派标签要对着道具查），池在敌人之后，三种规则独立，
## 章节按 id 引用池与规则；成就（091）排最后（对象可能是道具 / 章节）
## 096：标签与伤害类型最先（道具的标签对着它提醒；没有它们也能导）；110：局外科技在道具之后（要交的材料对着道具查）；114：百科的机制页最后（相关道具对着道具查）
const ORDER := ["tags", "damage_types", "run_buffs", "faiths", "items", "recipes", "loadouts", "characters", "difficulties", "events", "enemies", "enemy_pools", "hunters", "drop_rules", "carry_rules", "node_rules", "economy_rules", "meta_rules", "chapters", "achievements", "techs", "help_pages"]


## 100（作者定）：有目录、但独立内容一份都还没有的种类 —— **不进 [constant KINDS]**（批量导入与一致性检查都不跑它们），
## 只有各自的编辑器在用（buff 制作器、套装编辑器自己写 JSON + `.tres`）。
## 真有了第一份独立内容，把这一行搬回 `KINDS` 并在 `ORDER` 里排在 `items` 之前，那份内容就自动进管线与检查
const EDITOR_ONLY_KINDS := {
	"buffs": [AUTHORING_BUFFS, BUFFS],
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
