## 153（作者定，五项待定按推荐）：防护改名【格挡】—— 盾牌专属的固定减伤，每面盾一层、只取最高；
## 格挡轴（加固 / 破绽）加在生效层之上；敌人天生的算一层；buff 不许直接改格挡；非盾不许给格挡；旧键 armor 当 block 读并提醒
extends RefCounted

const H := preload("res://tests/battle/test_effect_system.gd")
const P := preload("res://tests/battle/test_damage_pipeline.gd")


static func _shield_item(uid: int, block: float) -> CompiledItem:
	return H._compiled(uid, "shield_%d" % uid, {"block": block})


static func run_layers(t: TestCase) -> void:
	t.begin("153 · 每面盾一层、只取最高；天生也是一层；加固 / 破绽加在生效层之上")
	var two := CombatantRuntime.from_spec(H._spec(100.0, [_shield_item(1, 5.0), _shield_item(2, 5.0)]), 1)
	t.eq(two.stat_int(BattleStats.BLOCK), 5, "两面 5 格挡的盾：5，不是 10")
	t.eq(two.block_layers.size(), 2, "两层都留着（备用）")
	var mixed := CombatantRuntime.from_spec(H._spec(100.0, [_shield_item(1, 5.0), _shield_item(2, 19.0)]), 1)
	t.eq(mixed.stat_int(BattleStats.BLOCK), 19, "19 和 5：取 19")
	t.eq(int(mixed.block_layers[0]["uid"]), 2, "最高的排第一")

	var spec := H._spec(100.0, [_shield_item(1, 5.0)])
	spec.baseline = StatSet.new()
	spec.baseline.set_base(BattleStats.BLOCK, StatMath.from_float(3.0))
	var guard := CombatantRuntime.from_spec(spec, 1)
	t.eq(guard.block_layers.size(), 2, "天生 3 + 盾 5：两层")
	t.eq(guard.stat_int(BattleStats.BLOCK), 5, "取最高 5")
	guard.block_layers.remove_at(0)     # 最高那层没了（将来的「盾碎」）
	guard.mark_dirty()
	t.eq(guard.stat_int(BattleStats.BLOCK), 3, "最高那层没了，次高（天生 3）顶上")

	var bare := CombatantRuntime.from_spec(H._spec(100.0, [_shield_item(1, 5.0)]), 1)
	bare.shift_axis(StatAxes.BLOCK, 8)
	t.eq(bare.stat_int(BattleStats.BLOCK), 13, "加固 8 加在生效层 5 上：13")
	bare.shift_axis(StatAxes.BLOCK, -11)
	t.eq(bare.stat_int(BattleStats.BLOCK), 2, "再破绽 11：5 + 8 − 11 = 2")
	var none := CombatantRuntime.from_spec(H._spec(100.0, []), 1)
	none.shift_axis(StatAxes.BLOCK, -3)
	t.eq(none.stat_int(BattleStats.BLOCK), -3, "没盾中了破绽 3：−3（106 倒贴不变）")
	t.eq(StatAxes.name_of(StatAxes.BLOCK, 1), "加固", "轴正名加固（不和格挡撞名）")
	t.eq(StatAxes.name_of(StatAxes.BLOCK, -1), "破绽", "负名破绽")


static func run_damage(t: TestCase) -> void:
	t.begin("153 · 伤害管线：两面盾挨 10 点只减一面；buff 带的加固（弹开）照加")
	var ctx := H._battle(P._attacker(10.0), H._spec(100.0, [_shield_item(2, 4.0), _shield_item(3, 4.0)]))
	P._run(ctx)
	t.eq(P._hp(ctx, 1), 94, "两面 4 格挡：10 点打出 6（以前相加会是 2）")
	var deflect: BuffDef = ContentLibrary.buffs().get(&"deflect", null)
	t.check(deflect != null and deflect.mods.is_empty() and deflect.axis_stacks_per(StatAxes.BLOCK) == 8, "弹开：每层带 8 层加固")
	var marked: BuffDef = ContentLibrary.buffs().get(&"marked", null)
	t.check(marked != null and marked.axis_stacks_per(StatAxes.BLOCK) == -3, "标记：带 3 层破绽")
	if deflect != null:
		var ctx2 := H._battle(P._attacker(20.0), H._spec(100.0, [_shield_item(2, 5.0)]))
		ctx2.sides[1].apply_buff(deflect, 1, 0)
		P._run(ctx2)
		t.eq(P._hp(ctx2, 1), 93, "盾 5 + 弹开 8：20 点打出 7")


static func run_import(t: TestCase) -> void:
	t.begin("153 · 导入：非盾给格挡报错；buff 的 mods 改格挡报错；旧键 armor 当 block 读并提醒；赐福给格挡只能落在盾上")
	var ok := ImportReport.new()
	var sh := ContentImporter.import_item({"id": "t_sh", "shape": ["11"], "tags": ["shield"], "combat": {"base_stats": {"block": 5}}}, ContentImporter.Context.new(), ok)
	t.check(ok.ok() and StatMath.to_int(int(sh.combat.base_stats.get("block", 0) * StatMath.ONE)) >= 0, "盾给格挡：放行（%s）" % ok.to_text())
	var bad := ImportReport.new()
	ContentImporter.import_item({"id": "t_vest", "shape": ["11"], "tags": ["armor"], "combat": {"base_stats": {"block": 5}}}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok() and bad.to_text().contains("格挡只归盾牌"), "防具给格挡：报错（%s）" % bad.to_text())

	# 补充一：armor 改名前后意思不同，不猜 —— 报错并写清两种去处
	var old := ImportReport.new()
	ContentImporter.import_item({"id": "t_old", "shape": ["11"], "tags": ["shield"], "combat": {"base_stats": {"armor": 5}}}, ContentImporter.Context.new(), old)
	t.check(not old.ok() and old.to_text().contains("block") and old.to_text().contains("max_armor"), "旧键 armor：报错，指向 block / max_armor（%s）" % old.to_text())

	var buff := ImportReport.new()
	ContentImporter.import_buff({"id": "t_wall", "stackable": false, "duration_sec": 4.0, "mods": [{"stat": "block", "amount": 8.0}]}, ContentImporter.Context.new(), buff)
	t.check(not buff.ok() and buff.to_text().contains("axes"), "buff 直接改格挡：报错，指向 axes（%s）" % buff.to_text())
	var axis_buff := ImportReport.new()
	ContentImporter.import_buff({"id": "t_wall2", "stackable": false, "duration_sec": 4.0, "axes": [{"axis": "block", "stacks": 8}]}, ContentImporter.Context.new(), axis_buff)
	t.check(axis_buff.ok(), "buff 带加固轴：放行")

	for faith in ["nature", "earth"]:
		var def: FaithDef = load(ContentPaths.asset_file("faiths", faith))
		if def == null:
			continue
		var gives_block := 0
		for b in def.blessings:
			if ContentImporter._bonuses_touch_block((b as Blessing).faith_bonuses):
				gives_block += 1
				var tags := (b as Blessing).tags
				t.check(tags.size() == 1 and tags[0] == &"shield", "%s：给格挡的那条赐福只认盾（%s）" % [faith, str(tags)])
		t.eq(gives_block, 1, "%s：拆成两条，只有盾那条给格挡" % faith)


static func run_content(t: TestCase) -> void:
	t.begin("153 · 内容：盾给格挡、防具不给；守卫去掉天生 4；词条与教程文字改成格挡")
	var c := TestSupport.content()
	for id in ["round_shield", "tower_shield", "blessed_shield"]:
		var def: ItemDef = c.items.get_def(StringName(id))
		t.check(def != null and def.tags.has(&"shield") and def.combat.base_stats.has("block"), "%s：带 shield 标签、给格挡" % id)
	for id in c.items.ids():
		var def: ItemDef = c.items.get_def(id)
		if def != null and def.combat != null and def.combat.base_stats.has("block"):
			t.check(def.tags.has(&"shield"), "%s 给格挡，就得是盾" % id)
		if def != null and def.combat != null:
			t.check(not def.combat.base_stats.has("armor"), "%s 没有旧键 armor" % id)
	t.eq(Glossary.stat_name(BattleStats.BLOCK), "格挡", "属性名格挡")
	t.check(Glossary.term_text("格挡").contains("最高"), "词条「格挡」写着只算最高的一面")
	t.eq(Glossary.term_text("防护"), "", "词条「防护」没了")
	t.check(TextTemplate.render("{item_stat:tower_shield:block}", {}) != "", "教程文字能引用盾的格挡")


static func frame_panel(t: TestCase, root: Window) -> void:
	t.begin("153 · 回放面板：一格「格挡 N」—— 取最高、加上加固 / 破绽与 buff 带的；轴不另画一格；悬浮窗列各层")
	var panel := CombatantPanel.new()
	root.add_child(panel)
	panel.item_names = {2: "塔盾", 3: "圆盾"}
	panel.reset({"resources": {}, "block_layers": [
		{"uid": 2, "id": "tower_shield", "value": StatMath.from_float(5.0)},
		{"uid": 3, "id": "round_shield", "value": StatMath.from_float(4.0)}]})
	t.check(panel.stacks().has(CombatantPanel.BLOCK_CHIP), "有格挡格")
	t.eq(panel.block_value(), 5, "取最高 5")
	t.eq(panel.chip_text(CombatantPanel.BLOCK_CHIP), "格 5", "格上写「格 5」")
	panel.set_axis(String(StatAxes.BLOCK), 8)
	t.eq(panel.block_value(), 13, "加固 8：13")
	t.check(not panel.stacks().has(CombatantPanel.AXIS_PREFIX + String(StatAxes.BLOCK)), "格挡轴不另画一格")
	var marked: BuffDef = ContentLibrary.buffs().get(&"marked", null)
	if marked != null:
		panel.buff_defs = {&"marked": marked}
		panel.set_stacks("marked", 1)
		t.eq(panel.block_value(), 10, "再中标记（破绽 3）：10")
	var text := Glossary.strip_bbcode(BattleView.block_tip(panel))
	t.check(text.contains("塔盾 5") and text.contains("生效") and text.contains("圆盾 4") and text.contains("备用"), "悬浮窗列各层：%s" % text)
	t.check(text.contains("加固 ×8"), "悬浮窗列修正：%s" % text)
	var empty := CombatantPanel.new()
	root.add_child(empty)
	empty.reset({"resources": {}})
	t.check(not empty.stacks().has(CombatantPanel.BLOCK_CHIP), "没盾也没修正：不画")
	panel.queue_free()
	empty.queue_free()


static func run_armor_rename(t: TestCase) -> void:
	t.begin("153 补充一 · 防具给的那层「护盾」改名【护甲】：armor / max_armor；旧名 max_shield、shield_absorbable、food_shield 认并提醒")
	t.eq(BattleStats.RES_ARMOR, &"armor", "资源键 armor")
	t.eq(BattleStats.MAX_ARMOR, &"max_armor", "上限属性 max_armor")
	t.eq(BattleStats.resource_of_max(BattleStats.MAX_ARMOR), BattleStats.RES_ARMOR, "max_armor 派生出 armor 资源池")
	t.eq(Glossary.stat_name(BattleStats.MAX_ARMOR), "护甲上限", "属性名护甲上限")
	t.eq(Glossary.resource_name(BattleStats.RES_ARMOR), "护甲", "资源名护甲")
	t.check(Glossary.term_text("护甲").contains("先于生命"), "词条「护甲」")
	t.eq(Glossary.term_text("护盾"), "", "词条「护盾」没了")

	var r := ImportReport.new()
	var vest := ContentImporter.import_item({"id": "t_vest", "shape": ["11"], "tags": ["armor"], "combat": {"base_stats": {"max_shield": 6}}}, ContentImporter.Context.new(), r)
	t.check(r.ok() and r.to_text().contains("max_armor"), "旧键 max_shield：提醒改名（%s）" % r.to_text())
	t.check(vest != null and vest.combat.base_stats.has("max_armor") and not vest.combat.base_stats.has("max_shield"), "读成了 max_armor")
	var m := ImportReport.new()
	var buff := ContentImporter.import_buff({"id": "t_guard", "mods": [{"stat": "max_shield", "amount": 5.0}]}, ContentImporter.Context.new(), m)
	t.check(m.ok() and buff.mods.size() == 1 and buff.mods[0].stat == &"max_armor", "buff 修饰的 stat: max_shield → max_armor（%s）" % m.to_text())
	var dt := ImportReport.new()
	var def := ContentImporter.import_damage_type({"id": "t_dt", "display_name": "测试", "shield_absorbable": false}, ContentImporter.Context.new(), dt)
	t.check(dt.ok() and def != null and not def.armor_absorbable and dt.to_text().contains("armor_absorbable"), "shield_absorbable → armor_absorbable（%s）" % dt.to_text())

	var nature: FaithDef = load(ContentPaths.asset_file("faiths", "nature"))
	var has_food := false
	if nature != null:
		for p in nature.perks:
			if p is FoodArmorPerk:
				has_food = true
	t.check(has_food, "自然的「按食物给护甲」是 food_armor")
	for id in ["leather_armor", "plate_cuirass"]:
		var item: ItemDef = TestSupport.content().items.get_def(StringName(id))
		t.check(item != null and item.combat != null and item.combat.base_stats.has("max_armor"), "%s 给护甲上限" % id)

