## 298（作者 2026-11-11 13:10）：悬浮窗「可拼为」写出拼接配方（两边都写），搭档是道具词、出件是配方词；
## 配方里的武器 / 魔晶名也是道具词；砧和铁匠铺的升级前后两窗并排（右窗改了的行左边金线）
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
	t.eq(ItemTooltip.fusions_line(c.items.get_def(&"salve")), "", "伤药拼不了：空")
	var body := String(ItemTooltip.describe_full(ItemInstance.create(knife)).get("body", ""))
	var fi := body.find(UiText.t("tip.fuses_to").split("%")[0])
	t.check(fi >= 0, "刀的悬浮窗里有「可拼为」")
	var ui := body.find(UiText.t("tip.upgrades_to").split("%")[0])
	t.check(ui < 0 or fi < ui, "「可拼为」在「可升为」上面")
	var full := ItemTooltip.recipe_full(&"fuse_quenched_dagger")
	t.check(String(full.get("head", "")).contains(Names.of(c.items.get_def(&"quenched_dagger"))), "拼接配方子窗：头是出件")
	var fb := String(full.get("body", ""))
	t.check(fb.contains("[url=item:knife]") and fb.contains("[url=item:whetstone]"), "要　刀 + 磨刀石（道具词）")
	t.check(String(ItemTooltip.recipe_full(&"anvil_bloodbone_spike").get("body", "")).contains("[url=item:bonefang_dagger]"), "砧配方子窗里的武器名也是道具词")
	t.eq(ItemTooltip.item_word(knife).begins_with("[url=item:knife]"), true, "道具词前缀 item:")


static func run_upgrade_rules(t: TestCase) -> void:
	t.begin("298 · 升级类配方认得出；铁匠铺预览：仓库没那把 → 左边空，右边出件")
	var pool := Anvil.recipes()
	var r := SmithRecipeDef.find(pool, &"anvil_bloodbone_spike")
	t.check(Anvil.is_upgrade(r), "嗜血骨刺：一把 + 材料 = 升级类")
	t.check(not Anvil.is_upgrade(null), "空：不是")
	var c := CS._content()
	var meta := MetaState.new()
	var pv := Smithy.preview(meta, r, c.items)
	t.check(pv.get("before") == null, "仓库里没有骨牙匕首：左边空")
	t.eq((pv.get("after") as ItemInstance).def.id, &"bloodbone_spike", "右边：出件")
	t.eq(UpgradeCompare.differing(PackedStringArray(["a", "b"]), PackedStringArray(["a", "c", ""])), [1] as Array[int], "只标对不上的行，空行不标")


static func frame_compare_windows(t: TestCase, root: Window) -> void:
	t.begin("298 · 两窗并排：左现在、右之后；右窗有改了的行；可压暗左窗；收起")
	var c := CS._content()
	var cmp := UpgradeCompare.new()
	root.add_child(cmp)
	var before := ItemInstance.create(c.items.get_def(&"bonefang_dagger"))
	var after := ItemInstance.create(c.items.get_def(&"bloodbone_spike"))
	cmp.show_pair(before, after, true)
	t.check(cmp.visible, "摆上：显示")
	t.check(cmp.right.position.x >= cmp.left.size.x, "右窗在左窗右边")
	t.check(cmp.texts()[1].contains(Names.of(after.def)), "右窗是出件")
	t.check(not cmp.marked_lines().is_empty(), "右窗有金线行")
	t.check(cmp.left_dimmed(), "左窗压暗")
	cmp.clear()
	t.check(not cmp.visible, "收起")
	cmp.free()
