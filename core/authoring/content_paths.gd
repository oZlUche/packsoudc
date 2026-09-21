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
const AUTHORING_BUFFS := AUTHORING + "/buffs"
const AUTHORING_SETS := AUTHORING + "/sets"
#endregion

#region 引擎资产（导入器产出，游戏读这里）
const ITEMS := "res://data/items"
const BUFFS := "res://data/buffs"
const SETS := "res://data/sets"
#endregion

## 种类 → [作者数据目录, 资产目录]。顺序即导入顺序：后者可以按 id 引用前者。
const KINDS := {
	"buffs": [AUTHORING_BUFFS, BUFFS],
	"sets": [AUTHORING_SETS, SETS],
	"items": [AUTHORING_ITEMS, ITEMS],
}
const ORDER := ["buffs", "sets", "items"]


static func authoring_file(kind: String, id: String) -> String:
	return "%s/%s.json" % [KINDS[kind][0], id]


static func asset_file(kind: String, id: String) -> String:
	return "%s/%s.tres" % [KINDS[kind][1], id]
