## 304（武器、合成与铸造升级现状调查）§8 最小验证：只在内存里建棋盘与实例，走正式的 [Fusion] / [SmithRecipeDef] 函数，不读写存档。
##
##     godot --headless --path . --script res://tools/verify_weapon_web.gd
extends CliTool

var _fails := 0


func run() -> void:
	var items := ItemDatabase.new()
	items.load_dir()
	var recipes := RecipeDef.load_all()
	_fusion(items, recipes)
	_no_upgrades(items)
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


## 二：改造 D 批之后没有「吃一把武器升一档」的配方了 —— 铁匠铺的配方都不吃武器
func _no_upgrades(items: ItemDatabase) -> void:
	print("二、铁匠铺配方不吃武器（改造 D：砧升级拆了）")
	var eats: Array[String] = []
	for r in SmithRecipeDef.load_all():
		for key in r.inputs:
			var d := items.get_def(StringName(String(key)))
			if d != null and d.tags.has(&"weapon"):
				eats.append(String(r.id))
	_check(eats.is_empty(), "没有吃武器的配方（%s）" % [eats])


## 三：红武唯一性的一个静态推断（附表 red_lifecycle.md §六 R1）—— 已有一把寂灭放在本局地上时，神坛献祭条件还认不认。
## 正式条件 [JimiePath.sacrifice_ready] 由事件条件 jimie_ready 以 (ctx.board, ctx.meta) 调用；本局地上不在这两个参数里
func _jimie_second() -> void:
	print("三、寂灭已在本局地上时的献祭条件（JimiePath.sacrifice_ready）")
	var rs: RunState = Altar._run()
	var red := rs.items.get_def(JimiePath.RED)
	_check(JimiePath.sacrifice_ready(rs.board, rs.meta), "基线：法杖 + 四颗核在包里、哪儿都没有寂灭 → 可献祭")
	rs.storage.admit(ItemInstance.create(red))
	print("  地上放一把寂灭后：UniqueItems.owned(meta+run) = %s，sacrifice_ready(board, meta) = %s" % [UniqueItems.owned(JimiePath.RED, rs.meta, rs), JimiePath.sacrifice_ready(rs.board, rs.meta)])
	_check(UniqueItems.owned(JimiePath.RED, rs.meta, rs), "全局唯一性扫描能看到地上的寂灭")
	_check(not JimiePath.sacrifice_ready(rs.board, rs.meta), "按用户规则应拒绝献出第二把（若此行「不符」即复现了漏洞）")


const Altar := preload("res://tests/run/test_jimie_altar_281.gd")
