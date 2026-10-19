## 206（音效第二批，待定按推荐）：背包拖放 / 落地、战利品翻牌 / 全部拾取、战斗回放 37 个 cue；
## 表里加别名（不许链）与每秒上限；拿放按材质分三类；战斗跳转全不响、4 倍速只放行暴击 / 反应 / 倒下 / 胜负
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const G := preload("res://tests/inventory/test_ground.gd")
const B := preload("res://tests/inventory/test_ground_bump_180.gd")
const CELL := InventoryView.CELL
const TMP_CUES := "user://test_audio206_cues.json"
const NEW_CUES := [
	"bag.pick.metal", "bag.pick.leather", "bag.pick.cloth", "bag.place.metal", "bag.place.leather", "bag.place.cloth",
	"bag.invalid", "bag.rotate", "bag.bump", "bag.land.light", "bag.land.heavy",
	"loot.flip.r0", "loot.flip.r1", "loot.flip.r2", "loot.flip.r3", "loot.flip.r4", "loot.flip.r5", "loot.flip_done", "loot.take_all",
	"battle.hit.physical", "battle.hit.fire", "battle.hit.ice", "battle.hit.lightning", "battle.hit.poison", "battle.hit.bleed",
	"battle.crit", "battle.block", "battle.armor_break",
	"battle.reaction.1", "battle.reaction.2", "battle.reaction.3", "battle.reaction.4",
	"battle.buff_up", "battle.buff_down", "battle.fall", "battle.win", "battle.lose",
]


static func _audio(root: Node) -> AudioHub:
	return root.get_node_or_null("/root/Audio") as AudioHub


## 清掉冷却、限频与记录，钟拨到 [param at]（之后每一步用 [method _tick] 往前拨，冷却挡不住下一步）
static func _fresh(audio: AudioHub, at: float = 100.0) -> void:
	audio._last_at.clear()
	audio._window.clear()
	audio.recent.clear()
	audio.clock_override = at


static func _tick(audio: AudioHub) -> void:
	audio.clock_override += 2.0


static func _done(audio: AudioHub) -> void:
	_fresh(audio)
	audio.clock_override = -1.0


## 记录里以 [param prefix] 开头的（按钮钩子的 ui.* 不算）
static func _got(audio: AudioHub, prefix: String) -> Array:
	return (audio.recent as Array).filter(func(c: StringName) -> bool: return String(c).begins_with(prefix))


static func _def(id: String, tags: Array = [], rarity: int = 0, weight: int = 0) -> ItemDef:
	var d := ItemDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.shape = ItemShape.from_ascii(["1"])
	var t: Array[StringName] = []
	for tag in tags:
		t.append(StringName(tag))
	d.tags = t
	d.rarity = rarity
	d.weight = weight
	return d


static func run_table(t: TestCase) -> void:
	t.begin("206 · ① 表：37 个新 cue 都在、文件是 .ogg；别名解到真名；每种伤害、每个反应都有声；别名指向不在的、带 files、链起来都报")
	var table := CueTable.load_default()
	t.eq(table.errors, [], "默认表没有问题")
	var bad_files: Array[String] = []
	for name in NEW_CUES:
		var files := table.files_of(StringName(name))
		if files.is_empty():
			bad_files.append(name)
		for f in files:
			if not f.ends_with(".ogg") or not ResourceLoader.exists(f):
				bad_files.append(f)
	t.eq(bad_files, [], "37 个 cue 都有文件、都是 .ogg（%s）" % [bad_files])
	t.eq(table.resolve(&"battle.hit.drain"), &"battle.hit.physical", "吸血 = 物理那一声")
	t.eq(table.resolve(&"battle.reaction.ice_poison"), &"battle.reaction.3", "凝毒 = 第 3 声")
	t.eq(table.resolve(&"battle.hit.fire"), &"battle.hit.fire", "不是别名的解到自己")
	t.eq(table.cue(&"battle.hit.reflect"), table.cue(&"battle.hit.physical"), "别名取到的是真名那一条")
	t.eq(int(table.cue(&"battle.hit.fire")["max_per_sec"]), 8, "命中每秒最多 8")
	var no_type: Array[String] = []
	for f in DirAccess.get_files_at("res://data/authoring/damage_types"):
		if f.ends_with(".json") and table.cue(StringName("battle.hit." + f.get_basename())).is_empty():
			no_type.append(f.get_basename())
	t.eq(no_type, [], "每种伤害都有命中声（%s）" % [no_type])
	var no_reaction: Array[String] = []
	for r in ReactionResolver.all():
		if table.cue(StringName("battle.reaction." + String(r.id))).is_empty():
			no_reaction.append(String(r.id))
	t.check(ReactionResolver.all().size() >= 10 and no_reaction.is_empty(), "十个反应都有声（%s）" % [no_reaction])
	var f := FileAccess.open(TMP_CUES, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"a.real": {"files": ["x.ogg"]},
		"a.ok": {"alias": "a.real"},
		"a.lost": {"alias": "a.nowhere"},
		"a.fat": {"alias": "a.real", "files": ["y.ogg"]},
		"a.chain": {"alias": "a.ok"},
	}))
	f.close()
	var bad := CueTable.new()
	bad.load_files(TMP_CUES, "user://test_audio206_none.json")
	t.eq(bad.errors.size(), 3, "指向不在的、别名带 files、别名链：三条（%s）" % [bad.errors])
	t.eq(bad.resolve(&"a.ok"), &"a.real", "好的别名照常")
	t.check(bad.cue(&"a.lost").is_empty() and bad.cue(&"a.chain").is_empty(), "坏别名去掉了（取到空）")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_CUES))


static func run_material(t: TestCase) -> void:
	t.begin("206 · ② 材质：秘银剑 金属、皮甲 皮、绷带 布、包 皮；拿起 / 放下的 cue 名跟着材质")
	var db := ItemDatabase.new()
	db.load_dir()
	t.eq(SfxMaterial.of(db.get_def(&"mithril_sword")), SfxMaterial.METAL, "秘银剑：金属")
	t.eq(SfxMaterial.of(db.get_def(&"leather_armor")), SfxMaterial.LEATHER, "皮甲：皮")
	t.eq(SfxMaterial.of(db.get_def(&"bandage_roll")), SfxMaterial.CLOTH, "绷带：布")
	var bag := _def("t_bag")
	bag.is_bag = true
	t.eq(SfxMaterial.of(bag), SfxMaterial.LEATHER, "没标签的包：皮")
	t.eq(SfxMaterial.of(_def("t_x", ["leather", "metal"])), SfxMaterial.METAL, "两组都中：金属那组在前")
	t.eq(SfxMaterial.of(null), SfxMaterial.CLOTH, "空：布")
	t.eq(SfxMaterial.pick_cue(db.get_def(&"mithril_sword")), &"bag.pick.metal", "拿起秘银剑")
	t.eq(SfxMaterial.place_cue(db.get_def(&"bandage_roll")), &"bag.place.cloth", "放下绷带")


static func _view(inv: GridInventory, at: Vector2) -> InventoryView:
	var v := InventoryView.new()
	v.inventory = inv
	v.position = at
	v.size = Vector2(inv.size) * CELL
	return v


static func _center(view: InventoryView, cell: Vector2i) -> Vector2:
	return view.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func frame_drag(t: TestCase, root: Window) -> void:
	t.begin("206 · ③ 拖拽：上手 pick、放进棋盘 place、放不下退回 invalid、Esc 取消不响、旋转 rotate、顶出一批一声 bump")
	var audio := _audio(root)
	if audio == null:
		t.check(false, "没有 Audio")
		return
	ItemInstance.reset_uid_counter()
	var src := GridInventory.new(Vector2i(4, 4), 1)
	var dst := GridInventory.new(Vector2i(4, 4), 2)
	var view_a := _view(src, Vector2.ZERO)
	var view_b := _view(dst, Vector2(400, 0))
	var drag := DragLayer.new()
	drag.register_view(view_a)
	drag.register_view(view_b)
	var sword := ItemInstance.create(_def("t_sword", ["metal"]))
	src.place(sword, Vector2i(0, 0), 0)
	_fresh(audio)
	view_a.grab_requested.emit(view_a, sword.uid, Vector2(24, 24))
	t.eq(_got(audio, "bag."), [&"bag.pick.metal"], "上手：金属")
	_tick(audio)
	drag.rotate_dragged()
	t.eq(_got(audio, "bag."), [&"bag.pick.metal", &"bag.rotate"], "旋转一下")
	_tick(audio)
	t.check(drag.drop_at(_center(view_b, Vector2i(1, 1))), "放进去了")
	t.eq(_got(audio, "bag.").back(), &"bag.place.metal", "放进棋盘：金属")
	_fresh(audio)
	view_b.grab_requested.emit(view_b, sword.uid, Vector2(24, 24))
	_tick(audio)
	t.check(not drag.drop_at(Vector2(-900, -900)), "放到哪儿都不是：退回")
	t.eq(_got(audio, "bag."), [&"bag.pick.metal", &"bag.invalid"], "放不下：invalid（不响 place）")
	t.check(dst.has_item(sword.uid), "退回原处")
	_fresh(audio)
	view_b.grab_requested.emit(view_b, sword.uid, Vector2(24, 24))
	_tick(audio)
	drag.cancel()
	t.eq(_got(audio, "bag."), [&"bag.pick.metal"], "Esc 取消：只有上手那一声")
	# 顶替：一件压在另一件上，被顶的上手 —— 一批一声 bump
	var cloth := ItemInstance.create(_def("t_cloth"))
	src.place(cloth, Vector2i(2, 2), 0)
	_fresh(audio)
	view_a.grab_requested.emit(view_a, cloth.uid, _center(view_a, Vector2i(2, 2)))
	_tick(audio)
	t.check(drag.drop_at(_center(view_b, Vector2i(1, 1))), "压着放手：顶替成功")
	t.eq(_got(audio, "bag."), [&"bag.pick.cloth", &"bag.place.cloth", &"bag.pick.metal", &"bag.bump"], "上手、放下；被顶的那件自动上手、顶出一声")
	t.check(dst.has_item(cloth.uid) and cloth.origin == Vector2i(1, 1) and drag.is_dragging(), "顶到了：被顶的在手上")
	t.check(drag.drop_at(_center(view_a, Vector2i(0, 0))), "被顶的那件放回左边")
	for v in [view_a, view_b]:
		v.free()
	drag.free()
	_done(audio)


static func frame_landing(t: TestCase, root: Window) -> void:
	t.begin("206 · ④ 落地：一重一轻同一帧落稳，只响一声 heavy；只有轻的落稳响 light")
	var audio := _audio(root)
	if audio == null:
		t.check(false, "没有 Audio")
		return
	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := B._ground(stash)
	var heavy := _drop(stash, ground, _def("t_heavy", [], 0, 10), Vector2(200, 100))
	var light := _drop(stash, ground, _def("t_light", [], 0, 1), Vector2(600, 100))
	t.check(GroundLayer.land_profile(heavy.def)["sink"] and not GroundLayer.land_profile(light.def)["sink"], "一件沉、一件不沉")
	_fresh(audio)
	ground.advance_landing(maxf(ground.landing_sec(heavy.uid), ground.landing_sec(light.uid)) + 0.01)
	t.eq(_got(audio, "bag.land"), [&"bag.land.heavy"], "同一帧落稳两件：一声 heavy")
	var feather := _drop(stash, ground, _def("t_feather", [], 0, 1), Vector2(1000, 100))
	_tick(audio)
	ground.advance_landing(ground.landing_sec(feather.uid) + 0.01)
	t.eq(_got(audio, "bag.land"), [&"bag.land.heavy", &"bag.land.light"], "只有轻的：light")
	ground.free()
	_done(audio)


static func _drop(stash: ItemStash, ground: GroundLayer, def: ItemDef, top_left: Vector2) -> ItemInstance:
	var inst := ItemInstance.create(def)
	stash.insert(inst, -1, Vector2(0.1, 0.1))
	stash.landing_from[inst.uid] = ground.global_position + top_left
	ground._scan()
	return inst


static func _loot(rarities: Array) -> LootView:
	var inv := GridInventory.new(Vector2i(6, 2), 3)
	for i in rarities.size():
		inv.place(ItemInstance.create(_def("t_r%d" % i, [], int(rarities[i]))), Vector2i(i, 0), 0)
	var v := LootView.new()
	v.set_inventory(inv)
	return v


static func frame_loot(t: TestCase, root: Window) -> void:
	t.begin("206 · ⑤ 战利品：逐张揭开按稀有度响、翻完一声 flip_done；快速搜索只响 flip_done；空的不响；全部拾取搬走了才响")
	var audio := _audio(root)
	if audio == null:
		t.check(false, "没有 Audio")
		return
	ItemInstance.reset_uid_counter()
	var v := _loot([0, 3, 5])
	_fresh(audio)
	v.start_reveal()
	v.advance(1000.0)
	t.eq(_got(audio, "loot."), [&"loot.flip.r0", &"loot.flip.r3", &"loot.flip.r5", &"loot.flip_done"], "三张逐张响 + 翻完")
	v.free()
	var quick := _loot([1, 2])
	_fresh(audio)
	quick.skip()
	t.eq(_got(audio, "loot."), [&"loot.flip_done"], "快速搜索：只有翻完那一声")
	quick.free()
	var empty := _loot([])
	_fresh(audio)
	empty.start_reveal()
	t.eq(_got(audio, "loot."), [], "空容器：不响")
	empty.free()
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "audio206")
	f.begin(c.chapter, kit, 1)
	f.pick_spawn(f.run.map.entry_ids[0])
	var box := LootPacker.board_of([&"knife"] as Array[StringName], Vector2i(4, 3), f.run.items)
	var screen = load("res://ui/game/container_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.LOOT
	root.add_child(screen)
	screen.open({"container": box})
	t.eq(String(screen._take_btn.get_meta(AudioHub.META_KEY, "x")), "", "全部拾取不叠按钮音")
	_fresh(audio)
	screen.take_all()
	t.eq(_got(audio, "loot.take"), [&"loot.take_all"], "搬走了：take_all")
	_tick(audio)
	screen.take_all()
	t.eq(_got(audio, "loot.take"), [&"loot.take_all"], "空了再按：不再响")
	screen.queue_free()
	Support.cleanup("audio206")
	_done(audio)


static func _battle(root: Window) -> BattleView:
	var view := BattleView.new()
	var p0 := CombatantPanel.new()
	var p1 := CombatantPanel.new()
	root.add_child(p0)
	root.add_child(p1)
	view._panels = [p0, p1]
	var down := BuffDef.new()
	down.is_debuff = true
	p1.buff_defs[&"t_down"] = down
	p1.buff_defs[&"t_up"] = BuffDef.new()
	return view


static func _free_battle(view: BattleView) -> void:
	for p in view._panels:
		p.free()
	view.free()


static func _hit(type: String, amount: float, crit: bool = false, block: int = 0) -> BattleEvent:
	return BattleEvent.make(BattleEvent.DAMAGE, 0, 1, {"amount": StatMath.from_float(amount), "type": type, "crit": crit, "block": block})


static func frame_battle(t: TestCase, root: Window) -> void:
	t.begin("206 · ⑥ 战斗：火伤、吸血 = 物理、暴击叠在命中上、格挡、凝毒 = 第 3 声、减益首层（续层不响）、护甲打穿、倒下、胜负（平局不响）")
	var audio := _audio(root)
	if audio == null:
		t.check(false, "没有 Audio")
		return
	var view := _battle(root)
	var steps := [
		[_hit("fire", 5.0), [&"battle.hit.fire"], "火伤"],
		[_hit("drain", 5.0), [&"battle.hit.physical"], "吸血：物理那一声"],
		[_hit("physical", 9.0, true), [&"battle.hit.physical", &"battle.crit"], "暴击：命中 + 暴击两声"],
		[_hit("physical", 0.0, false, 2), [&"battle.block"], "全被格挡：只有格挡"],
		[_hit("physical", 0.0, false, -2), [], "破绽（格挡是负的）、没伤害：不响"],
		[_hit("physical", -3.0), [], "反转成治疗：不响"],
		[BattleEvent.make(BattleEvent.EFFECT_RESOLVED, 0, 1, {"effect": ReactionResolver.EFFECT, "reaction": "ice_poison", "elements": ["ice", "poison"]}), [&"battle.reaction.3"], "凝毒：第 3 声"],
		[BattleEvent.make(BattleEvent.STATUS_STACKED, 0, 1, {"buff": "t_down", "delta": 1, "stacks": 1}), [&"battle.buff_down"], "减益首层"],
		[BattleEvent.make(BattleEvent.STATUS_STACKED, 0, 1, {"buff": "t_down", "delta": 1, "stacks": 2}), [], "续层：不响"],
		[BattleEvent.make(BattleEvent.STATUS_STACKED, 0, 1, {"buff": "t_up", "delta": 1, "stacks": 1}), [&"battle.buff_up"], "增益首层"],
	]
	for st in steps:
		_fresh(audio)
		view._apply(st[0])
		t.eq(_got(audio, "battle."), st[1], String(st[2]))
	view._panels[1].set_resource("armor", 3, 3)
	_fresh(audio)
	view._apply(BattleEvent.make(BattleEvent.RESOURCE_CHANGED, 0, 1, {"key": "armor", "current": 0, "max": StatMath.from_float(3.0)}))
	t.eq(_got(audio, "battle."), [&"battle.armor_break"], "护甲 3 → 0：打穿")
	_tick(audio)
	view._apply(BattleEvent.make(BattleEvent.RESOURCE_CHANGED, 0, 1, {"key": "armor", "current": 0, "max": StatMath.from_float(3.0)}))
	t.eq(_got(audio, "battle."), [&"battle.armor_break"], "本来就 0：不再响")
	_fresh(audio)
	view._apply(BattleEvent.make(BattleEvent.DIED, 0, 1))
	t.eq(_got(audio, "battle."), [&"battle.fall"], "倒下")
	var r := BattleResult.new()
	r.winner = 0
	t.eq(BattleView.result_cue(r), &"battle.win", "玩家赢：win")
	r.winner = 1
	t.eq(BattleView.result_cue(r), &"battle.lose", "玩家输：lose")
	r.winner = -1
	t.eq(BattleView.result_cue(r), &"", "平局：不响")
	_free_battle(view)
	_done(audio)


static func frame_battle_gates(t: TestCase, root: Window) -> void:
	t.begin("206 · ⑦ 门：跳转（不弹字）时全不响；4 倍速火伤不响、暴击 / 反应 / 倒下照响；每秒上限 8：一秒里 20 下火伤只响 8 下")
	var audio := _audio(root)
	if audio == null:
		t.check(false, "没有 Audio")
		return
	var view := _battle(root)
	_fresh(audio)
	view._suppress_popups = true
	view._apply(_hit("fire", 5.0, true))
	view._apply(BattleEvent.make(BattleEvent.DIED, 0, 1))
	view._sfx(&"battle.win")
	t.eq(_got(audio, "battle."), [], "跳转：一声都没有")
	view._suppress_popups = false
	view._speed_idx = BattleView.SPEEDS.find(4.0)
	t.eq(view.speed(), 4.0, "4 倍速")
	_fresh(audio)
	view._apply(_hit("fire", 5.0))
	t.eq(_got(audio, "battle."), [], "4 倍速：火伤不响")
	_tick(audio)
	view._apply(_hit("fire", 5.0, true))
	t.eq(_got(audio, "battle."), [&"battle.crit"], "4 倍速：暴击照响（命中不响）")
	_tick(audio)
	view._apply(BattleEvent.make(BattleEvent.EFFECT_RESOLVED, 0, 1, {"effect": ReactionResolver.EFFECT, "reaction": "fire_poison", "elements": ["fire", "poison"]}))
	view._apply(BattleEvent.make(BattleEvent.DIED, 0, 0))
	t.eq(_got(audio, "battle."), [&"battle.crit", &"battle.reaction.1", &"battle.fall"], "4 倍速：反应、倒下照响")
	t.check(BattleView.fast_cue(&"battle.win") and BattleView.fast_cue(&"battle.lose") and not BattleView.fast_cue(&"battle.block"), "胜负放行、格挡不放")
	view._speed_idx = BattleView.SPEEDS.find(2.0)
	_fresh(audio)
	for i in 20:
		view._apply(_hit("fire", 5.0))
		audio.clock_override += 0.045
	t.eq(_got(audio, "battle.").size(), 8, "2 倍速、一秒里 20 下：只响 8 下")
	audio.clock_override += 1.0
	view._apply(_hit("fire", 5.0))
	t.eq(_got(audio, "battle.").size(), 9, "过了一秒又能响")
	_free_battle(view)
	_done(audio)
