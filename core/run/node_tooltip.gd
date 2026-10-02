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
	"safe": "保险箱：把背包里的东西放进去就算带出去了 —— 就算行动失败也带得出。关上（或走开）就送回基地，不能再改。",
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
		&"search", &"event", &"shop", &"rest", &"extract", &"random", &"spawn", &"safe":
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
	var text := TextTemplate.render(template_for(chapter, node), TextTemplate.context_for(run, node))
	# 092：倒计时过半关闭的撤离点，浮窗里说清楚
	if run != null and node != null and PaidExtracts.closes_at(node) >= 0 and run.has_countdown():
		if run.extract_closed(node):
			text += "\n[color=#d9534f]这个撤离点已经关闭（倒计时过半）。[/color]"
		else:
			text += "\n[color=#f0ad4e]倒计时剩 %d 时关闭（还有 %d 步）。[/color]" % [PaidExtracts.closes_at(node), run.countdown_left() - PaidExtracts.closes_at(node)]
	return text


## 反馈：每个点的暂存区各自留着 —— 这个点上放着的东西（站在上面时是身上暂存区里的，走开了是留在这里的），一行 BBCode；没有返回 ""。
## 和 [member RunState.node_storages] 同一份账，不受章节的「节点浮窗」开关管（这是玩家自己放的东西）
static func stash_text(run: RunState, node: MapNode) -> String:
	if run == null or node == null:
		return ""
	var items: Array = run.storage.items() if run.travel != null and run.travel.current_id == node.id and run.storage != null else run.stored_at(node.id)
	if items.is_empty():
		return ""
	var counts := {}
	var order: Array[String] = []
	for inst in items:
		var it := inst as ItemInstance
		if it == null or it.def == null:
			continue
		var name := Names.of(it.def)
		if not counts.has(name):
			order.append(name)
		counts[name] = int(counts.get(name, 0)) + 1
	var parts: Array[String] = []
	for name in order:
		parts.append(name if int(counts[name]) == 1 else "%s ×%d" % [name, counts[name]])
	return "[color=#f0ad4e]暂存区（%d 件）：[/color]%s" % [items.size(), "、".join(parts)]


## 浮窗里要不要画对手的棋盘：没用过的战斗点、内容里有敌人
static func shows_board(node: MapNode) -> bool:
	return node != null and category_of(node) == "battle" and EnemyKit.has_enemy(node.content)
