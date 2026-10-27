## 107（作者定）：关键词弹窗按 `tip` 字段开关、信仰状态只靠灰 / 亮、图鉴异体叠影外框不动。
##
## 规矩一句话：**能直观理解的词不弹**，弹窗留给带玩家猜不到的规则的词；`tip = false` 的词
## 不进侧窗、主文字里也不标色，但**说明文字一字不动**（编辑器词典、文档照用）。
extends RefCounted

const NS := preload("res://tests/ui/test_node_screens.gd")

## 作者点名不弹的固定词条
const QUIET_TERMS: Array[String] = ["自发", "开战时", "出手时", "受伤时", "层数够时", "资源低于时", "冷却", "耐力", "耗耐力", "信力"]
## 带规则、照弹的固定词条
const LOUD_TERMS: Array[String] = ["急速", "格挡", "护甲", "直接伤害", "永续", "叠层", "合成", "增益槽", "受益槽", "中毒", "流血"]
## 作者点名不弹的标签
const QUIET_TAGS: Array[StringName] = [&"melee", &"ranged", &"weapon", &"shield", &"armor", &"treasure", &"keepsake", &"fire", &"poison", &"bleed", &"remedy"]
## 带规则（休眠 / 激活条件、献祭信息）、照弹的标签
const LOUD_TAGS: Array[StringName] = [&"sealed", &"nature", &"crafted", &"magic"]     # 250：faith / faith_anchor / sigil / 材质标签删了（信仰、信物改成归神道具自带的词条）


static func run_term_table(t: TestCase) -> void:
	t.begin("107 · 固定词条表：直白的词 tip 关着、带规则的开着；说明文字一律保留；表自检 tip 只能是 bool")
	for name in QUIET_TERMS:
		t.check(Glossary.TERMS.has(name), "「%s」还在表里" % name)
		t.check(not Glossary.term_tip(name), "「%s」不弹词条（作者点名）" % name)
		t.check(Glossary.term_text(name) != "", "「%s」的说明文字保留" % name)
	for name in LOUD_TERMS:
		t.check(Glossary.term_tip(name), "「%s」照弹（带玩家猜不到的规则）" % name)
		t.check(Glossary.term_text(name) != "", "「%s」有说明" % name)
	# 休眠整条删掉（作者定：用灰 / 亮区分，不要词条）
	t.check(not Glossary.TERMS.has("休眠"), "「休眠」不再是玩家词条")
	t.eq(Glossary.term_text("休眠"), "", "删了就取不到文字")
	t.check(not Glossary.term_tip("休眠"), "也不弹")

	# 表自检：每条都得是带 text 的字典，tip 只能是 bool
	for name in Glossary.TERMS:
		var entry = Glossary.TERMS[name]
		t.check(entry is Dictionary, "「%s」是字典（{text, tip}）" % name)
		if entry is Dictionary:
			var d := entry as Dictionary
			t.check(String(d.get("text", "")) != "", "「%s」有 text" % name)
			t.check(not d.has("tip") or (d["tip"] is bool), "「%s」的 tip 只能是 bool" % name)


static func run_tag_tips(t: TestCase) -> void:
	t.begin("107 · 标签的 tip：一看就懂的大类与伤害类型不弹，带规则的照弹；名字照样列在标签行里")
	for tag in QUIET_TAGS:
		t.check(TagRegistry.get_def(tag) != null, "标签 %s 还在" % tag)
		t.check(not TagRegistry.tip_of(tag), "%s 不弹词条" % tag)
		t.check(TagRegistry.describe(tag) != "", "%s 的说明文字保留" % tag)
	for tag in LOUD_TAGS:
		t.check(TagRegistry.tip_of(tag), "%s 照弹（带规则 / 献祭信息）" % tag)
	t.check(Glossary.tag_terms(QUIET_TAGS).is_empty(), "一串不弹的标签收不出任何词条")


static func run_longbow_sidebar(t: TestCase) -> void:
	t.begin("107 · 狩猎之神赐福的长弓：词条从 13 个降到三个 —— 信仰、信物（标签）与标记（它施加的 buff）")
	var c := NS._content()
	var bow := c.items.get_def(&"blessed_longbow")
	t.not_null(bow, "有赐福长弓")
	if bow == null:
		return
	var saved := ItemTooltip.faith_probe
	ItemTooltip.faith_probe = Callable()
	var full := ItemTooltip.describe_full(ItemInstance.create(bow))
	var names: Array[String] = []
	for term in (full["terms"] as Dictionary).values():
		if String((term as Dictionary)["text"]) != "":     # 193 补充三：标签图标各有一条只写名字的词条（停上去看名字），不算「有说明的词条」
			names.append(String((term as Dictionary)["name"]))
	names.sort()
	# 方案举例时说「只剩信仰、信物两个」，漏算了它自己施加的【标记】——
	# buff 词条按 2.3 的规矩不受 tip 管（说明是按定义生成的效果，正是玩家要看的），所以是三个
	t.eq(names, ["信仰", "信物", "标记"], "只剩这三个词条：%s" % str(names))
	t.check(Glossary.describe_buff(Glossary.buffs_in_item(bow).get(&"marked", null)).contains("格挡"), "标记的说明仍按定义生成（破绽 3 层 → 格挡 −3）")
	# 不弹的词在主文字里也不标色
	var text := String(full["text"])
	for quiet in ["自发", "耗耐力", "冷却", "信力"]:
		t.check(not text.contains("[u]%s[/u]" % quiet), "「%s」在主文字里不标色" % quiet)
	t.check(text.contains("term:tag:weapon"), "副行的标签照旧（193 补充三起画成图标）")
	ItemTooltip.faith_probe = saved


static func run_faith_state_is_color(t: TestCase) -> void:
	t.begin("107 · 休眠不写字、只用颜色：激活的信仰道具亮，休眠 / 没激活的灰，没有「—— 现在…」尾巴")
	var c := NS._content()
	var bow := c.items.get_def(&"blessed_longbow")
	var saved := ItemTooltip.faith_probe
	var dim := "[color=#%s]" % ItemTooltip.DIM_HEX

	ItemTooltip.faith_probe = func() -> Dictionary: return {"active": &"hunt", "tier": 5, "points": 9999}
	var lit := ItemTooltip.describe(ItemInstance.create(bow))
	t.check(ItemTooltip.faith_lit(bow, ItemTooltip.faith_status()), "狩猎激活：这件亮")
	t.check(lit.contains("[color=@faith]") and not lit.contains(dim), "有亮色的信仰行（257：信力色 / 数值色）")
	t.check(not Glossary.strip_bbcode(lit).contains("现在"), "没有状态尾巴")
	t.check(not Glossary.strip_bbcode(lit).contains("休眠"), "不写休眠")

	ItemTooltip.faith_probe = func() -> Dictionary: return {"active": &"brute", "tier": 2, "points": 120}
	var dormant := ItemTooltip.describe(ItemInstance.create(bow))
	t.check(not ItemTooltip.faith_lit(bow, ItemTooltip.faith_status()), "蛮神激活：狩猎的弓不亮")
	t.check(dormant.contains(dim), "信仰行是灰的")
	t.check(not Glossary.strip_bbcode(dormant).contains("休眠"), "休眠也只是灰，不写字")
	t.eq(InventoryView.status_note(true, false), "", "作者 10-26：棋盘上休眠的护符也不写「休眠」，只压灰")
	t.eq(InventoryView.status_note(true, true), UiText.t("inv.benched"), "不参战照写")
	ItemTooltip.faith_probe = saved


static func run_buff_only_damage(t: TestCase) -> void:
	t.begin("107（作者定）· 毒与流血没有直接伤害形态：道具自己的规则里打毒伤 / 流血伤 → 导入 error，buff 里的照旧")
	var ctx := ContentImporter.Context.new()
	var hit := {"trigger": {"type": "on_schedule"}, "cadence": {"type": "cooldown", "seconds": 1.0},
		"effects": [{"type": "deal_damage", "damage_type": "poison", "amount": 2.0, "damage_stat": ""}]}
	var bad := ImportReport.new()
	ContentImporter.import_item({"id": "t_direct_poison", "shape": ["1"], "tags": ["weapon"],
		"combat": {"rules": [hit]}}, ctx, bad)
	t.check(not bad.ok() and bad.to_text().contains("毒与流血没有直接伤害形态"), "直接打毒伤：拦下（%s）" % bad.to_text())

	var bleed := hit.duplicate(true)
	(bleed["effects"] as Array)[0]["damage_type"] = "bleed"
	var bad2 := ImportReport.new()
	ContentImporter.import_item({"id": "t_direct_bleed", "shape": ["1"], "tags": ["weapon"],
		"combat": {"rules": [bleed]}}, ctx, bad2)
	t.check(not bad2.ok(), "直接打流血伤：也拦下")

	# buff 里的那条照旧：毒刀就是这么写的
	var ok := ImportReport.new()
	ContentImporter.import_item({"id": "t_poison_knife", "shape": ["1"], "tags": ["weapon"], "combat": {"rules": [{
		"trigger": {"type": "on_schedule"}, "cadence": {"type": "cooldown", "seconds": 1.0},
		"effects": [{"type": "deal_damage"}, {"type": "apply_status", "buff": {"id": "t_poison", "display_name": "中毒", "is_debuff": true,
			"rules": [{"trigger": {"type": "on_schedule"}, "cadence": {"type": "cooldown", "seconds": 1.0},
				"effects": [{"type": "deal_damage", "target": "SELF", "damage_type": "poison", "amount": 2.0, "damage_stat": "", "per_stack": true}]}]}}]}]}}, ctx, ok)
	t.check(ok.ok(), "buff 内部的每秒毒伤照旧（%s）" % ok.to_text())
	# 火焰照旧可以直接打（它两种形态都有）
	var fire := hit.duplicate(true)
	(fire["effects"] as Array)[0]["damage_type"] = "fire"
	var fire_ok := ImportReport.new()
	ContentImporter.import_item({"id": "t_fire_sword", "shape": ["1"], "tags": ["weapon"], "combat": {"rules": [fire]}}, ctx, fire_ok)
	t.check(fire_ok.ok(), "武器直接打火焰伤害照旧（火焰有直接伤害形态）")


static func frame_codex_stack(t: TestCase, root: Window) -> void:
	t.begin("107（作者定）· 图鉴异体格：黑色外框不变，叠的是里面的物品")
	var c := NS._content()
	var sword := c.items.get_def(&"shortsword")
	t.not_null(sword, "有短剑")
	if sword == null:
		return
	var tile := CodexTile.new(sword, true, 1, UiPalette.cjk_font())
	var variants: Array[ItemDef] = [sword]
	var lit_flags: Array[bool] = [true]
	for id in [&"shortsword_brute", &"shortsword_sun"]:
		var v := c.items.get_def(id)
		if v != null:
			variants.append(v)
			lit_flags.append(false)
	tile.variants = variants
	tile.variant_lit = lit_flags
	root.add_child(tile)
	t.check(tile.variant_count() >= 1, "短剑有异体（%d）" % tile.variant_count())
	t.eq(tile.stack_layers(), mini(tile.variant_count(), 2), "最多垫两层")
	t.eq(tile.size, CodexTile.SIZE, "外框就是一格的大小，没有错位的底板撑大它")

	var plain := CodexTile.new(c.items.get_def(&"charm_brute"), true, 1, UiPalette.cjk_font())
	root.add_child(plain)
	t.eq(plain.variant_count(), 0, "护符没有异体")
	t.eq(plain.stack_layers(), 0, "没异体就不叠")
	tile.queue_free()
	plain.queue_free()


static func run_internal_style_tags(t: TestCase) -> void:
	t.begin("107 后续（作者定）：快攻 / 重击 / 重型留作内部标签 —— 敌人照旧按它挑武器，玩家哪儿都看不到")
	for id in [&"rapid", &"burst", &"heavy"]:
		t.check(TagRegistry.is_internal(id), "%s 是内部标签" % id)
		t.check(TagRegistry.get_def(id) != null, "%s 还登记着（没删）" % id)
	for id in [&"weapon", &"fire", &"crafted", &"remedy"]:     # 250：melee / ranged 降成内部
		t.check(not TagRegistry.is_internal(id), "%s 照常给玩家看" % id)
	t.check(not TagRegistry.is_internal(&"no_such_tag"), "没登记的标签不算内部（界面照原词显示）")
	t.eq(TagRegistry.shown([&"weapon", &"rapid", &"crafted"]), [&"weapon", &"crafted"], "shown 去掉内部的、顺序不变")
	var c := NS._content()
	var saved := ItemTooltip.faith_probe
	ItemTooltip.faith_probe = Callable()
	for pair in [[&"knife", "快攻"], [&"warhammer", "重击"], [&"longbow", "快攻"]]:
		var def := c.items.get_def(pair[0])
		t.not_null(def, "有 %s" % pair[0])
		if def == null:
			continue
		var text := String(ItemTooltip.describe_full(ItemInstance.create(def))["text"])
		t.check(not text.contains(pair[1]), "%s 的悬浮窗不写「%s」" % [pair[0], pair[1]])
		t.check(text.contains("term:tag:weapon"), "%s 的标签还在副行里（列别的标签，193 补充三起是图标）" % pair[0])
	ItemTooltip.faith_probe = saved
	t.check(Glossary.tag_terms([&"rapid", &"burst", &"heavy"]).is_empty(), "也不进词条侧窗")
