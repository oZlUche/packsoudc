## 地图节点的浮窗文字（084，作者：鼠标移到节点上显示；第二章开放，所以是开关；内容能在默认 / 自定义之间切）。
##
## 一个点归到一个**类别**（[method category_of]）：用过的点一律 `visited`（已经没东西了），其余按类型。
## 模板从三处取，先到先得：节点内容 `tooltip`（这个点专有）→ 章节 `tooltip_texts[类别]`（`tooltip_mode == "custom"` 时）→ 内置 [constant DEFAULTS]。
## 模板经 [TextTemplate] 渲染，战斗点常用 `{battle_data}`；全部键见 docs/text-placeholders.md。
## 纯逻辑：返回 BBCode 文字与要不要画对手的棋盘，画是地图屏的事
class_name NodeTooltip
extends RefCounted

const DEFAULTS := {
	"battle": "{c:danger}{enemy_name}{/c}（{enemy_strength} 档）\n生命 {enemy_hp}　约 {enemy_dps} DPS\n带着 {enemy_count} 件：{enemy_items}",
	"visited": "{c:dim}这里已经没东西了。{/c}",
	"search": "这里有值得搜索的东西，但翻得越久越可能惊动附近的人。",
	"event": "这里可能会发生什么。",
	"shop": "有人在这里做买卖。",
	"rest": "能歇脚的地方，回一点体力。",
	"extract": "撤离点：站上去按「撤离」结束这一局。",
	"random": "{c:dim}看不透的地方，踩上去才知道是什么。{/c}",
	"spawn": "出发的地方。",
	"other": "{node_type}",
}


## 这个点算哪一类
static func category_of(node: MapNode) -> String:
	if node == null:
		return "other"
	if node.is_visited() and node.type != &"extract" and node.type != &"spawn":
		return "visited"
	var type := NodeEvents.effective_type(node)
	match type:
		&"battle", &"elite", &"core":
			return "battle"
		&"search", &"event", &"shop", &"rest", &"extract", &"random", &"spawn":
			return String(type)
	return "other"


## 这个点该用的模板（未渲染）
static func template_for(chapter: ChapterDef, node: MapNode) -> String:
	if node != null and String(node.content.get("tooltip", "")) != "":
		return String(node.content["tooltip"])
	var cat := category_of(node)
	if chapter != null and chapter.tooltip_mode == "custom" and chapter.tooltip_texts.has(cat):
		return String(chapter.tooltip_texts[cat])
	return String(DEFAULTS.get(cat, DEFAULTS["other"]))


## 渲染好的浮窗文字（BBCode）
static func text_for(run: RunState, chapter: ChapterDef, node: MapNode) -> String:
	return TextTemplate.render(template_for(chapter, node), TextTemplate.context_for(run, node))


## 浮窗里要不要画对手的棋盘：没用过的战斗点、内容里有敌人
static func shows_board(node: MapNode) -> bool:
	return node != null and category_of(node) == "battle" and EnemyKit.has_enemy(node.content)
