## 298（作者 2026-11-11 13:10）：悬浮窗「可拼为」写出拼接配方（两边都写），搭档是道具词、出件是配方词；
## 配方里的道具名也是道具词（改造 D：砧 / 铁匠铺的升级前后两窗随升级配方一起拆了）
extends RefCounted

const CS := preload("res://tests/run/test_characters_149.gd")


static func run_fusion_line(t: TestCase) -> void:
	t.begin("298 · 「可拼为」两边都写；搭档是道具词、出件是配方词；拼接配方子窗写出件 +「要　两件」")
	var c := CS._content()
	var knife := c.items.get_def(&"knife")
	var stone := c.items.get_def(&"whetstone")
	var line := ItemTooltip.fusions_line(knife)
	t.check(line.contains("[url=item:whetstone]") and line.contains("[url=recipe:fuse_quenched_dagger]"), "刀：+ 磨刀石 → 淬火匕首（%s）" % line)
	t.check(ItemTooltip.fusions_line(stone).contains("[url=item:knife]"), "磨刀石那边也写（搭档是刀）")
	t.eq(ItemTooltip.fusions_line(c.items.get_def(&"smoked_fish")), "", "熏鱼拼不了：空（310：伤药有了拼接配方）")
	var body := String(ItemTooltip.describe_full(ItemInstance.create(knife)).get("body", ""))
	var fi := body.find(UiText.t("tip.fuses_to").split("%")[0])
	t.check(fi >= 0, "刀的悬浮窗里有「可拼为」")
	var full := ItemTooltip.recipe_full(&"fuse_quenched_dagger")
	t.check(String(full.get("head", "")).contains(Names.of(c.items.get_def(&"quenched_dagger"))), "拼接配方子窗：头是出件")
	var fb := String(full.get("body", ""))
	t.check(fb.contains("[url=item:knife]") and fb.contains("[url=item:whetstone]"), "要　刀 + 磨刀石（道具词）")
	t.eq(ItemTooltip.recipe_full(&"anvil_bloodbone_spike"), {}, "改造 D：旧砧配方 id 查不到，空")
	t.eq(ItemTooltip.item_word(knife).begins_with("[url=item:knife]"), true, "道具词前缀 item:")
