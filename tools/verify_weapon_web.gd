## 304（武器、合成与铸造升级现状调查）§8 最小验证：只在内存里建棋盘与实例，走正式的 [Fusion] / [Anvil] 函数，不读写存档。
##
##     godot --headless --path . --script res://tools/verify_weapon_web.gd
extends CliTool

var _fails := 0


func run() -> void:
	var items := ItemDatabase.new()
	items.load_dir()
	var recipes := RecipeDef.load_all()
	var pool := Anvil.recipes()
	_fusion(items, recipes)
	_anvil(items, pool)
	_multi_source(items, pool)
	_jimie_second()
	print("验证结束：%s" % ("全部符合" if _fails == 0 else "%d 处与预期不符" % _fails))
	finish(0 if _fails == 0 else 1)


func _check(ok: bool, what: String) -> void:
	print(("  [符合] " if ok else "  [不符] ") + what)
	if not ok:
		_fails += 1


## 一：拼接 —— 两把匕首配得上 → 双刀；成品落在两件原来的格里（314 起触发是拖到另一件上、先确认，这里只验配方和落点）
func _fusion(items: ItemDatabase, recipes: Array) -> void:
	print("一、拼接 fuse_twin_blades（knife + knife → twin_blades）")
	var knife := items.get_def(&"knife")
	var r := RecipeDef.find(recipes, &"knife", &"knife")
	_check(r != null and r.output == &"twin_blades", "两把匕首配得上，产物 twin_blades")
	var board := GridInventory.new(Vector2i(6, 4))
	var a := ItemInstance.create(knife)
	var b := ItemInstance.create(knife)
	board.place(a, Vector2i(0, 0))
	board.place(b, Vector2i(1, 0))
	board.remove(a.uid)
	board.remove(b.uid)
	var spot := Fusion.landing(board, [b, a], items.get_def(&"twin_blades"))
	_check(not spot.is_empty(), "成品落得进两件原来的格（%s）" % [spot])
	_check(ItemInstance.create(items.get_def(&"twin_blades")).quality() == 0, "拼接成品品质 = 0（ItemInstance.create 新建，不继承）")


## 二：按材质升级 —— 短矛 + 骨材 → 骨矛；材料比门槛高一档 → 品质 1；门槛以下 → 配不上
func _anvil(items: ItemDatabase, pool: Array) -> void:
	print("二、砧升级 anvil_bone_spear（short_spear + 骨≥绿 → bone_spear）")
	var spear := ItemInstance.create(items.get_def(&"short_spear"))
	var picks := _materials(items, "bone")
	var low: ItemDef = null
	var exact: ItemDef = null
	var high: ItemDef = null
	for d in picks:
		if d.rarity == 0 and low == null:
			low = d
		elif d.rarity == 1 and exact == null:
			exact = d
		elif d.rarity == 2 and high == null:
			high = d
	print("  候选骨材：白 %s / 绿 %s / 蓝 %s" % [String(low.id) if low else "无", String(exact.id) if exact else "无", String(high.id) if high else "无"])
	if low != null:
		_check(Anvil.recipe_for(spear.def, low, pool) == null, "白色骨材达不到「骨≥绿」，配不上")
	if exact != null:
		var r := Anvil.result(spear, ItemInstance.create(exact), pool, items)
		_check(r != null and r.def.id == &"bone_spear" and r.quality() == 0, "绿色骨材 → bone_spear，品质 0（%s）" % [String(r.def.id) if r else "<null>"])
	if high != null:
		var r2 := Anvil.result(spear, ItemInstance.create(high), pool, items)
		_check(r2 != null and r2.def.id == &"bone_spear" and r2.quality() == 1, "蓝色骨材 → bone_spear，品质 1（材料高门槛一档）")


## 三：同一成品多张配方 —— 噬血骨刺可由骨牙匕首 + 金属、或钢刺 + 骨材升成；同一把输入只取第一张配得上的
func _multi_source(items: ItemDatabase, pool: Array) -> void:
	print("三、多来源成品 bloodbone_spike（anvil_bloodbone_spike / _2）")
	var outs := pool.filter(func(r): return (r as SmithRecipeDef).output == &"bloodbone_spike")
	_check(outs.size() == 2, "bloodbone_spike 有 %d 张配方" % outs.size())
	var fang := items.get_def(&"bonefang_dagger")
	var stiletto := items.get_def(&"steel_stiletto")
	_check(Anvil.upgrades_for(fang, pool).size() >= 1 and Anvil.upgrades_for(stiletto, pool).size() >= 1, "两条前驱各自有升级配方（骨牙匕首 %d 张，钢刺 %d 张）" % [Anvil.upgrades_for(fang, pool).size(), Anvil.upgrades_for(stiletto, pool).size()])
	for w in [fang, stiletto]:
		var names: Array = Anvil.upgrades_for(w, pool).map(func(r): return "%s→%s %s" % [r.id, r.output, r.material_inputs])
		print("  %s 的全部升级：%s" % [w.id, names])


func _materials(items: ItemDatabase, mat: String) -> Array:
	var out: Array = []
	var ids: Array = items.all_ids()
	Ids.sort(ids)
	for id in ids:
		var d := items.get_def(StringName(String(id)))
		if d != null and d.tags.has(&"material") and d.material == mat and not d.is_blessed():
			out.append(d)
	return out


## 四：红武唯一性的一个静态推断（附表 red_lifecycle.md §六 R1）—— 已有一把寂灭放在本局地上时，神坛献祭条件还认不认。
## 正式条件 [JimiePath.sacrifice_ready] 由事件条件 jimie_ready 以 (ctx.board, ctx.meta) 调用；本局地上不在这两个参数里
func _jimie_second() -> void:
	print("四、寂灭已在本局地上时的献祭条件（JimiePath.sacrifice_ready）")
	var rs: RunState = Altar._run()
	var red := rs.items.get_def(JimiePath.RED)
	_check(JimiePath.sacrifice_ready(rs.board, rs.meta), "基线：法杖 + 四颗核在包里、哪儿都没有寂灭 → 可献祭")
	rs.storage.admit(ItemInstance.create(red))
	print("  地上放一把寂灭后：UniqueItems.owned(meta+run) = %s，sacrifice_ready(board, meta) = %s" % [UniqueItems.owned(JimiePath.RED, rs.meta, rs), JimiePath.sacrifice_ready(rs.board, rs.meta)])
	_check(UniqueItems.owned(JimiePath.RED, rs.meta, rs), "全局唯一性扫描能看到地上的寂灭")
	_check(not JimiePath.sacrifice_ready(rs.board, rs.meta), "按用户规则应拒绝献出第二把（若此行「不符」即复现了漏洞）")


const Altar := preload("res://tests/run/test_jimie_altar_281.gd")
