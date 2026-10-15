## 地图点的类型 → 名字（101 第 5 刀）。
##
## 名字是**文字**，不是长相：事件文本的 `{node_type}`、神罚与改造的日志、界面上的标题都用同一份，
## 所以它和别的文字一起住在 `core/text`。长相（圆里的那个字、颜色）仍在 [MapNodeStyle]，
## 它的 `label` 就从这里取 —— 这样 `core/` 不认识 `ui/`（架构文档 1 节的依赖方向）。
##
## 名单来自 [MapNodeTypes]；加一种点就在这里补一行，[MapNodeStyle] 补它的字与颜色。
class_name NodeText
extends RefCounted

## type → 名字
const LABELS := {
	&"battle": "战斗",
	&"elite": "精英战斗",
	&"event": "事件",
	&"random": "随机",
	&"search": "搜索点",
	&"shop": "商店",
	&"rest": "休息区",
	&"extract": "撤离点",
	&"junction": "岔路",
	&"core": "核心",
	&"spawn": "出生点",
	&"safe": "保险箱",
	&"chest": "宝箱",
}

const UNKNOWN := "未知"


## 这种点叫什么；没登记的叫「未知」
static func label_of(type: StringName) -> String:
	return String(LABELS.get(type, UNKNOWN))
