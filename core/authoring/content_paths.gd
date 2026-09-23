## 内容管线的目录约定（架构文档 10.1）。
##
## [b]只有这一处定义。[/b] 编辑器写作者数据、命令行读作者数据、两边都产出引擎资产 ——
## 三方各写一份路径常量的话，某天改了目录就会出现「编辑器存到 A、导入器读 B」
## 这种谁都不报错、但内容就是不生效的情况。
class_name ContentPaths
extends RefCounted

#region 作者数据（人写的 JSON，进 git，MOD 作者改这里）
const AUTHORING := "res://data/authoring"
const AUTHORING_ITEMS := AUTHORING + "/items"
const AUTHORING_LOADOUTS := AUTHORING + "/loadouts"
const AUTHORING_EVENTS := AUTHORING + "/events"
const AUTHORING_BUFFS := AUTHORING + "/buffs"
const AUTHORING_SETS := AUTHORING + "/sets"
const AUTHORING_RUN_BUFFS := AUTHORING + "/run_buffs"
const AUTHORING_ENEMIES := AUTHORING + "/enemies"
const AUTHORING_ENEMY_POOLS := AUTHORING + "/enemy_pools"
const AUTHORING_DROP_RULES := AUTHORING + "/drop_rules"
const AUTHORING_NODE_RULES := AUTHORING + "/node_rules"
const AUTHORING_ECONOMY_RULES := AUTHORING + "/economy_rules"
const AUTHORING_META_RULES := AUTHORING + "/meta_rules"
const AUTHORING_CHAPTERS := AUTHORING + "/chapters"
#endregion

#region 引擎资产（导入器产出，游戏读这里）
const ITEMS := "res://data/items"
const LOADOUTS := "res://data/loadouts"
const EVENTS := "res://data/events"
const BUFFS := "res://data/buffs"
const SETS := "res://data/sets"
const RUN_BUFFS := "res://data/run_buffs"
const ENEMIES := "res://data/enemies"
const ENEMY_POOLS := "res://data/enemy_pools"
const DROP_RULES := "res://data/drop_rules"
const NODE_RULES := "res://data/node_rules"
const ECONOMY_RULES := "res://data/economy_rules"
const META_RULES := "res://data/meta_rules"
const CHAPTERS := "res://data/chapters"
#endregion

## 种类 → [作者数据目录, 资产目录]。顺序即导入顺序：后者可以按 id 引用前者。
const KINDS := {
	"buffs": [AUTHORING_BUFFS, BUFFS],
	"sets": [AUTHORING_SETS, SETS],
	"run_buffs": [AUTHORING_RUN_BUFFS, RUN_BUFFS],
	"items": [AUTHORING_ITEMS, ITEMS],
	"loadouts": [AUTHORING_LOADOUTS, LOADOUTS],
	"events": [AUTHORING_EVENTS, EVENTS],
	"enemies": [AUTHORING_ENEMIES, ENEMIES],
	"enemy_pools": [AUTHORING_ENEMY_POOLS, ENEMY_POOLS],
	"drop_rules": [AUTHORING_DROP_RULES, DROP_RULES],
	"node_rules": [AUTHORING_NODE_RULES, NODE_RULES],
	"economy_rules": [AUTHORING_ECONOMY_RULES, ECONOMY_RULES],
	"meta_rules": [AUTHORING_META_RULES, META_RULES],
	"chapters": [AUTHORING_CHAPTERS, CHAPTERS],
}
## 开局装备与敌人都在道具之后（清单、招牌道具、流派标签要对着道具查），池在敌人之后，三种规则独立，
## 章节排最后（按 id 引用池与规则）
const ORDER := ["buffs", "sets", "run_buffs", "items", "loadouts", "events", "enemies", "enemy_pools", "drop_rules", "node_rules", "economy_rules", "meta_rules", "chapters"]


static func authoring_file(kind: String, id: String) -> String:
	return "%s/%s.json" % [KINDS[kind][0], id]


static func asset_file(kind: String, id: String) -> String:
	return "%s/%s.tres" % [KINDS[kind][1], id]
