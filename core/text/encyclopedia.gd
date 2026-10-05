## 百科（114，作者定）：「这个游戏的所有名词和行为」，离开上下文也能查。图鉴（089）管道具、词条侧窗（087）管「此刻停着的这件」，
## 百科是 107 说的那个「将来的帮助页」。
##
## 两类页，同一张目录：
## [codeblock]
## 机制页   手写，HelpPageDef（data/authoring/help_pages）       流程 / 背包 / 战斗规则 / 信仰 / 地图 / 局外
## 词条页   自动生成，不写内容 —— 文字跟着定义改                  固定词条、标签、伤害类型、buff、属性、乘区、时机
## [endcodeblock]
## 这一层只产出**数据**（页的表、正文的 BBCode 与链接 `[url=页 id]`）；怎么画是 [code]ui/game/encyclopedia_screen.gd[/code] 的事。
## 全部页始终可见（规则不是剧透），唯一遮的是「相关道具」里图鉴没点亮的道具名（[member lit]）
class_name Encyclopedia
extends RefCounted

## 词条页的分类（排在机制页的分类之后）
const TERMS_CATEGORY := "terms"
## 词条页的分组：来源 → 名字
const GROUPS := {
	"term": {"zh": "词条", "en": "Terms"}, "tag": {"zh": "标签", "en": "Tags"}, "dtype": {"zh": "伤害类型", "en": "Damage types"},
	"buff": {"zh": "状态", "en": "Statuses"}, "stat": {"zh": "属性", "en": "Stats"},
	"trigger": {"zh": "时机", "en": "Timings"},
}
const GROUP_ORDER := ["term", "tag", "dtype", "buff", "stat", "trigger"]
## 还没有说明的词条页正文
const NO_TEXT := "（这一页的说明还没写。）"

## 页 id → 页：`{id, title, category, group, order, text, related: Array[String], items: Array[StringName]}`
var _pages: Dictionary = {}
## 目录顺序的页 id
var _order: Array[String] = []
## 正文里认得的词 → 页 id（画链接用）；长的先认
var _links: Dictionary = {}
## 道具库（「相关道具」的名字、标签页「带这个标签的道具」、buff 页「来自」）
var items: ItemDatabase = null
## 图鉴点亮了没有：`func(id: StringName) -> bool`；无效 = 全当亮了
var lit: Callable = Callable()


## 造一本：手写的机制页 + 按当前内容生成的词条页
static func build(help: Array, item_db: ItemDatabase) -> Encyclopedia:
	var e := Encyclopedia.new()
	e.items = item_db
	e._generate_terms()
	var authored: Array = help.duplicate()
	authored.sort_custom(func(a: HelpPageDef, b: HelpPageDef) -> bool:
		var ca := HelpPageDef.CATEGORIES.find(String(a.category))
		var cb := HelpPageDef.CATEGORIES.find(String(b.category))
		if ca != cb:
			return ca < cb
		return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	var head: Array[String] = []
	for h in authored:
		var def := h as HelpPageDef
		if def == null or def.id == &"":
			continue
		var id := String(def.id)
		e._pages[id] = {"id": id, "title": Names.of(def), "category": String(def.category), "group": "", "order": def.order,
			"text": def.text_for(), "related": Array(def.related, TYPE_STRING, "", null), "items": Array(def.see_items, TYPE_STRING_NAME, "", null)}
		head.append(id)
		e._links[Names.of(def)] = id     # 机制页的标题压过同名词条（「合成」先跳那一页）
	head.append_array(e._order)
	e._order = head
	return e


#region 生成词条页
func _add(id: String, title: String, group: String, text: String, related: Array[String] = [], with_items: Array[StringName] = []) -> void:
	if _pages.has(id) or title == "":
		return
	_pages[id] = {"id": id, "title": title, "category": TERMS_CATEGORY, "group": group, "order": _order.size(),
		"text": text if text != "" else NO_TEXT, "related": related, "items": with_items}
	_order.append(id)
	if not _links.has(title):
		_links[title] = id


func _generate_terms() -> void:
	for name in Glossary.TERMS:
		_add("term:" + String(name), String(name), "term", Glossary.term_text(String(name)))
	for t in TagRegistry.ids():
		var tag := StringName(String(t))
		if TagRegistry.is_internal(tag) or FaithDef.id_of_tag(tag) != &"":
			continue
		_add("tag:" + String(tag), TagRegistry.name_of(tag), "tag", TagRegistry.describe(tag), [], _items_with_tag(tag))
	for d in DamageTypes.ids():
		_add("dtype:" + String(d), DamageTypes.name_of(d), "dtype", DamageTypes.describe(d))
	var buffs := _all_buffs()
	var buff_ids: Array = buffs.keys()
	buff_ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	for bid in buff_ids:
		var def: BuffDef = buffs[bid]["def"]
		var name := Names.of(def) if Names.of(def) != "" else String(bid)
		_add("buff:" + String(bid), name, "buff", Glossary.describe_buff(def), [], buffs[bid]["from"])
	# 属性 / 时机（133：乘区取消，不再有乘区页）：名字和固定词条同名的（急速、冷却、自发……）不另开页，那一页就是它
	for key in Glossary.STAT_NAMES:
		_add_named("stat:" + String(key), Glossary.stat_name(StringName(key)), "stat")
	for key in Glossary.TRIGGER_NAMES:
		_add_named("trigger:" + String(key), String(Glossary.TRIGGER_NAMES[key]), "trigger")


func _add_named(id: String, title: String, group: String) -> void:
	if Glossary.TERMS.has(title) or _links.has(title):
		return
	_add(id, title, group, Glossary.term_text(title))


## 带这个标签的道具 id（按 id 排）
func _items_with_tag(tag: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if items == null:
		return out
	for id in items.ids():
		var d := items.get_def(id)
		if d != null and d.tags.has(tag):
			out.append(id)
	Ids.sort(out)
	return out


## 道具库里出现的全部 buff：id → {def, from: [施加它的道具 id]}
func _all_buffs() -> Dictionary:
	var out := {}
	if items == null:
		return out
	var ids: Array[StringName] = []
	ids.assign(items.ids())
	Ids.sort(ids)
	for id in ids:
		var found := Glossary.buffs_in_item(items.get_def(id))
		for bid in found:
			if not out.has(bid):
				out[bid] = {"def": found[bid], "from": [] as Array[StringName]}
			(out[bid]["from"] as Array[StringName]).append(id)
	return out
#endregion


#region 查
## 目录顺序的全部页 id
func ids() -> Array[String]:
	return _order.duplicate()


func page(id: String) -> Dictionary:
	return _pages.get(id, {})


func has_page(id: String) -> bool:
	return _pages.has(id)


## 这个词有没有自己的一页（词条名、页标题）；有返回页 id，没有空
func page_for(word: String) -> String:
	return String(_links.get(word, ""))


## 目录：`[{category, name, groups: [{group, name, ids}]}]`，机制页的分类在前、词条页在后
func toc() -> Array:
	var out: Array = []
	var cats: Array = HelpPageDef.CATEGORIES.duplicate()
	cats.append(TERMS_CATEGORY)
	for cat in cats:
		var groups: Array = []
		var keys: Array = [""] if cat != TERMS_CATEGORY else GROUP_ORDER
		for g in keys:
			var ids: Array[String] = []
			for id in _order:
				var p: Dictionary = _pages[id]
				if String(p["category"]) == cat and String(p["group"]) == g:
					ids.append(id)
			if not ids.is_empty():
				groups.append({"group": g, "name": group_name(g), "ids": ids})
		if not groups.is_empty():
			out.append({"category": cat, "name": category_name(cat), "groups": groups})
	return out


static func category_name(cat: String) -> String:
	if cat == TERMS_CATEGORY:
		return "词条" if UiText.lang == "zh" else "Glossary"
	return HelpPageDef.category_name(cat)


static func group_name(g: String) -> String:
	return Glossary._pick(GROUPS.get(g, null), g) if g != "" else ""


## 搜索：标题或正文（去掉记号）里有这段字的页，标题命中的排前面。空查询返回空
func search(query: String, ctx: Dictionary = {}) -> Array[String]:
	var q := query.strip_edges().to_lower()
	var by_title: Array[String] = []
	var by_text: Array[String] = []
	if q == "":
		return by_title
	for id in _order:
		var p: Dictionary = _pages[id]
		if String(p["title"]).to_lower().contains(q):
			by_title.append(id)
		elif Glossary.strip_bbcode(TextTemplate.plain(String(p["text"]), ctx)).to_lower().contains(q):
			by_text.append(id)
	by_title.append_array(by_text)
	return by_title
#endregion


#region 画
## 一页的正文（BBCode，颜色还是 TextTemplate 的颜色名 —— 界面画之前过 `UiPalette.resolve_styles`）：
## 占位符换掉、认得的词画成链接 `[url=页 id]`，下面接「相关」与「相关道具」
func render(id: String, ctx: Dictionary = {}) -> String:
	var p: Dictionary = _pages.get(id, {})
	if p.is_empty():
		return ""
	var body := link_words(TextTemplate.render(String(p["text"]), ctx), id)
	var tail: Array[String] = []
	var rel: Array[String] = []
	for r in p.get("related", []):
		var target := String(r) if _pages.has(String(r)) else page_for(String(r))
		if target != "" and target != id:
			rel.append(link(target))
	if not rel.is_empty():
		tail.append(("相关：" if UiText.lang == "zh" else "See also: ") + "　".join(rel))
	var names: Array[String] = []
	for item_id in p.get("items", []):
		names.append(_item_name(StringName(String(item_id))))
	if not names.is_empty():
		var label := "来自：" if String(p["group"]) == "buff" else ("相关道具：" if UiText.lang == "zh" else "Items: ")
		tail.append(label + "、".join(names))
	if tail.is_empty():
		return body
	return body + "\n\n" + "\n".join(tail)


## 指向一页的链接（标题）
func link(id: String) -> String:
	var p: Dictionary = _pages.get(id, {})
	return "[url=%s]%s[/url]" % [id, String(p.get("title", id))] if not p.is_empty() else id


## 正文里认得的词画成链接（不链自己；已经在 BBCode 标签里的不动）。长的词先认，占位挡住免得短词把长词切开
func link_words(text: String, self_id: String = "") -> String:
	var words: Array[String] = []
	for w in _links:
		if String(w).length() >= 2 and String(_links[w]) != self_id:
			words.append(String(w))
	words.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var out := text
	var holders: Array[String] = []
	for i in words.size():
		var holder := "\u0001%d\u0002" % i
		holders.append(holder)
		out = out.replace(words[i], holder)
	for i in words.size():
		out = out.replace(holders[i], "[url=%s]%s[/url]" % [String(_links[words[i]]), words[i]])
	return out


func _item_name(id: StringName) -> String:
	var def := items.get_def(id) if items != null else null
	if def == null:
		return String(id)
	if lit.is_valid() and not bool(lit.call(id)):
		return "？"
	return Names.of(def)
#endregion
