## 内容的多语言名字（088，作者定）。
##
## 每个内容定义都有 `display_name`（中文，作者写的原文）和 `display_names`（`{"en": "Knife"}`，别的语言）。界面要显示名字一律走
## [method of]：按 [UiText.lang] 取 `display_names[lang]`，没有就回落 `display_name`。语言在主菜单切（[GameSettings.language]）。
##
## 为什么是字段而不是 Godot 的 `tr()` / 翻译表：名字**跟着内容走** —— 道具、敌人、buff 都走同一条内容管线（JSON → .tres），
## 作者在编辑器里改一件道具就把它的英文名一起改了，不用再去另一张表里对键；翻译文件那套（CSV / PO）适合界面上几千条固定文字，
## 那是 [UiText] 的活。两套各管一边：**内容的名字在内容里，界面的文字在 UiText 里。**
## 说明文字：`description` + `descriptions` 字典，[method description_of] 取（096 起标签 / 伤害类型用；事件正文有自己的 `texts`）。
class_name Names
extends RefCounted


## 这个定义在当前语言下叫什么。没有 display_names / 当前语言没写 / 对象为 null 时回落 display_name / 空串
static func of(obj: Object, lang: String = "") -> String:
	if obj == null:
		return ""
	var table: Variant = obj.get("display_names")
	var base: Variant = obj.get("display_name")
	return pick(table as Dictionary if table is Dictionary else {}, String(base) if base != null else "", lang)


## 148：**这一件**叫什么 —— 有耐久的（魔晶石）前面加状态前缀（明亮的 / 闪烁的 / 黯淡的 / 破碎的），其余同 [method of]。
## 格子标签、悬浮窗标题、拖拽中的那一件这些**手里有实例**的地方用它；只有定义的地方（图鉴、商店货架、编辑器）照旧 [method of]
static func of_item(inst: ItemInstance, lang: String = "") -> String:
	if inst == null or inst.def == null:
		return ""
	var base := of(inst.def, lang)
	# 175 第三批：附魔前缀（铸牌附上的覆盖预置的）。铸牌自己写成「铸牌 · 嗜血的」
	var ench := Forge.enchant_of(inst)
	var enchant := Forge.prefix(ench, lang) if not ench.is_empty() else ""
	if inst.def.is_token():
		return base + (" · " + enchant if enchant != "" else "")
	var wear := inst.def.wear.prefix_for(inst.charges(), lang) if inst.def.wear != null else ""
	return wear + enchant + base


## 语言回落的那一步（名字、事件的标题 / 正文 / 选项都走它）：[param table] 里有当前语言（或指定语言 [param lang]）且不是空串就用它，
## 否则回落 [param base]（作者写的原文）
static func pick(table: Dictionary, base: String, lang: String = "") -> String:
	var l := lang if lang != "" else UiText.lang
	var v := String(table.get(l, ""))
	return v if v != "" else base


## 096：说明文字（`description` / `descriptions`）同一条路：当前语言没写就回落 description。
## 104：过一遍 [TextTemplate]，上下文是这个定义自己的数值字段
static func description_of(obj: Object, lang: String = "") -> String:
	if obj == null:
		return ""
	var l := lang if lang != "" else UiText.lang
	var text := ""
	var table: Variant = obj.get("descriptions")
	if table is Dictionary and (table as Dictionary).has(l):
		text = String((table as Dictionary)[l])
	if text == "":
		var base: Variant = obj.get("description")
		text = String(base) if base != null else ""
	# 104 第十节：说明里的数写成 {字段名}，按这个定义自己的字段填（[TextParams]）
	return TextTemplate.render(text, TextParams.of(obj)) if text.contains("{") else text


## 有没有给这种语言写名字
static func has(obj: Object, lang: String) -> bool:
	if obj == null:
		return false
	var table: Variant = obj.get("display_names")
	return table is Dictionary and (table as Dictionary).has(lang) and String((table as Dictionary)[lang]) != ""
