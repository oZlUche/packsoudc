## 地图节点的浮窗文字（084，作者：鼠标移到节点上显示；第二章开放，所以是开关；内容能在默认 / 自定义之间切）。
##
## 一个点归到一个**类别**（[method category_of]）：用过的点一律 `visited`（已经没东西了），其余按类型。
## 模板从三处取，先到先得：节点内容 `tooltip`（这个点专有）→ 章节 `tooltip_texts[类别]`（`tooltip_mode == "custom"` 时）→ 内置 [constant DEFAULTS]
## （221 F1：[constant DEFAULTS] 是中文原文，按语言取用 [method default_for]，`UiText` 的 `node.tip.<类别>`）。
## 模板经 [TextTemplate] 渲染，战斗点常用 `{battle_data}`；全部键见 docs/text-placeholders.md。
## 纯逻辑：返回 BBCode 文字与要不要画对手的棋盘，画是地图屏的事
class_name NodeTooltip
extends RefCounted

const DEFAULTS := {
	"battle": "{c:danger}{enemy_name}{/c}\n生命 {enemy_hp}\n带着 {enemy_count} 件：{enemy_items}",
	"visited": "{c:dim}这里已经没东西了。{/c}",
	"search": "这里有值得搜索的东西，但翻得越久越可能惊动附近的人。",
	"event": "这里可能会发生什么。",
	"shop": "有人在这里做买卖。",
	"rest": "能歇脚的地方，回一点体力；里面有一座铸炉，能把三件道具熔铸成一枚铸牌（用一次就熄）。",
	"extract": "撤离点：站上去按「撤离」结束这一局。",
	"random": "{c:dim}看不透的地方，踩上去才知道是什么。{/c}",
	"spawn": "出发的地方。",
	"safe": "保险箱：把背包里的东西放进去就算带出去了 —— 就算行动失败也带得出。关上（或走开）就送回基地，不能再改。",
	"chest": "上锁的宝箱：长按开锁，越好的箱子越费时。",
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
		&"search", &"event", &"shop", &"rest", &"extract", &"random", &"spawn", &"safe", &"chest":
			return String(type)
	return "other"


## 这个点该用的模板（未渲染）
static func template_for(chapter: ChapterDef, node: MapNode) -> String:
	if node != null and String(node.content.get("tooltip", "")) != "":
		return String(node.content["tooltip"])
	var cat := category_of(node)
	if chapter != null and chapter.tooltip_mode == "custom" and chapter.tooltip_texts.has(cat):
		return String(chapter.tooltip_texts[cat])
	return default_for(cat)


## 221 F1：内置模板，按当前语言（没登记的类别用 `other`）
static func default_for(cat: String) -> String:
	if not DEFAULTS.has(cat):
		cat = "other"
	return UiText.pick(UiText.TEXT.get("node.tip.%s" % cat), String(DEFAULTS[cat]))


## 渲染好的浮窗文字（BBCode）
static func text_for(run: RunState, chapter: ChapterDef, node: MapNode) -> String:
	var text := TextTemplate.render(template_for(chapter, node), TextTemplate.context_for(run, node))
	# 127：没用过的搜索点 —— 进阶的第一行写明；有保底就加一行「每次至少几件，其中……」
	if node != null and category_of(node) == "search":
		if SearchSession.is_advanced(node):
			text = "[color=#f0ad4e]%s[/color]\n" % UiText.t("node.advanced_search") + text
		var p_floor := SearchSession.floor_for(node, run.node_rules.search if run != null and run.node_rules != null else null, run.difficulty if run != null else null)
		if not p_floor.is_empty():
			text += "\n" + TextTemplate.render(UiText.t("node.search_floor_line"), {"search_floor_count": p_floor.size(), "search_floor_text": SearchSession.floor_text(p_floor)})
	return _countdown_line(run, node, text)


static func _countdown_line(run: RunState, node: MapNode, text: String) -> String:
	# 092：倒计时过半关闭的撤离点，浮窗里说清楚
	var cd := CountdownModule.of(run)     # 101：倒计时是一局的模块
	if node != null and PaidExtracts.closes_at(node) >= 0 and cd != null and cd.has_countdown():
		if cd.extract_closed(node):
			text += "\n[color=#d9534f]%s[/color]" % UiText.t("node.extract_closed")
		else:
			text += "\n[color=#f0ad4e]%s[/color]" % (UiText.t("node.extract_closes_at") % [PaidExtracts.closes_at(node), cd.left() - PaidExtracts.closes_at(node)])
	return text


## 反馈：每个点的地上各自留着 —— 这个点上放着的东西（站在上面时是身上地上的，走开了是留在这里的），一行 BBCode；没有返回 ""。
## 和 [NodeStorageModule] 同一份账，不受章节的「节点浮窗」开关管（这是玩家自己放的东西）
static func stash_text(run: RunState, node: MapNode) -> String:
	if run == null or node == null:
		return ""
	var here := run.travel != null and run.travel.current_id == node.id
	var ns := NodeStorageModule.of(run)
	var items: Array = (run.storage.items() if run.storage != null else []) if here else (ns.stored_at(node.id) if ns != null else [])
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
	return "[color=#f0ad4e]%s[/color]%s" % [UiText.t("node.stash") % items.size(), UiText.t("node.stash_sep").join(parts)]


## 浮窗里要不要画对手的棋盘：没用过的战斗点、内容里有敌人
static func shows_board(node: MapNode) -> bool:
	return node != null and category_of(node) == "battle" and EnemyKit.has_enemy(node.content)
