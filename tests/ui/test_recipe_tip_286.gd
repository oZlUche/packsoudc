## 286（作者 2026-11-07 15:02）：道具悬浮窗里的配方词 —— 停上去开配方子窗（出件整段悬浮窗 + 要什么），能一路往下开（改造 D 起只剩「可拼为」的合成配方词）；
## 带配方词的窗没钉住时鼠标从道具挪进窗里不收、接着走钉住进度（别的窗照作者 10-27 收）
extends RefCounted

const CS := preload("res://tests/run/test_characters_149.gd")


static func run_recipe_words(t: TestCase) -> void:
	t.begin("286 · 配方词：「可拼为」的出件是配方词；配方子窗写出件、要哪两件；改造 D：没有「可升为」")
	ItemTooltip.recipe_probe = Callable()
	var c := CS._content()
	var knife := c.items.get_def(&"knife")
	var line := ItemTooltip.fusions_line(knife)
	t.check(line.contains("[url=recipe:fuse_twin_blades]") and line.contains("[u]"), "匕首：双刀是配方词、下划线同关键词（%s）" % line)
	var full := ItemTooltip.recipe_full(&"fuse_twin_blades")
	t.check(String(full.get("head", "")).contains(Names.of(c.items.get_def(&"twin_blades"))), "子窗头是出件")
	t.check(String(full.get("body", "")).contains("[url=item:knife]"), "要　匕首 + 匕首")
	t.eq(ItemTooltip.recipe_full(&"no_such_recipe"), {}, "查不到配方：空")
	t.eq(ItemTooltip.recipe_full(&"anvil_bloodbone_spike"), {}, "旧砧配方：查不到")
	t.check(String(ItemTooltip.describe_full(ItemInstance.create(c.items.get_def(&"bonefang_dagger"))).get("body", "")).find("recipe:anvil_") < 0, "骨牙匕首不再写可升为")


static func _board(root: Window, id: StringName) -> Dictionary:
	ItemTooltip.recipe_probe = Callable()     # 305：单开面板 = 都知道（别的用例开着的局不算）
	ItemTooltip.item_probe = Callable()
	var c := CS._content()
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var board := GridInventory.new(Vector2i(4, 4), 1)
	var inst := ItemInstance.create(c.items.get_def(id))
	board.place(inst, Vector2i(0, 0), 0)
	var view := InventoryView.new()
	view.inventory = board
	view.position = Vector2(20, 20)
	view.size = Vector2(board.size) * InventoryView.CELL
	host.add_child(view)
	var tip := HoverTip.new()
	host.add_child(tip)
	tip.watch(view)
	var on := InputEventMouseMotion.new()
	on.position = Vector2(24, 24)
	view.gui_input.emit(on)
	return {"host": host, "view": view, "tip": tip, "src": view.global_position + on.position}


## 窗里、不在视图上的一点（窗开在鼠标右下）
static func _inside(tip: HoverTip, view: Control) -> Vector2:
	var r := tip._panel.global_rect()
	var p := r.end - Vector2(6, 6)
	return p if not view.get_global_rect().has_point(p) else Vector2(-1, -1)


static func frame_pin_exception(t: TestCase, root: Window) -> void:
	t.begin("286 · 带配方词的窗：鼠标从道具挪进窗里不收、走满钉住；停配方词开子窗、再开到 3 层停；别的窗照旧收")
	var f := _board(root, &"knife")
	var tip: HoverTip = f["tip"]
	t.check(tip.is_showing() and tip._panel.has_recipe, "匕首的窗有配方词")
	var inside := _inside(tip, f["view"])
	t.check(inside.x >= 0.0, "窗里有一点不在视图上")
	tip.tick(0.016, inside)
	t.check(tip.is_showing() and not tip.is_pinned(), "挪进窗里：不收")
	tip.tick(HoverTip.PIN_DELAY_SEC + HoverTip.PIN_SEC + 0.01, inside)
	t.check(tip.is_pinned(), "在窗里走满：钉住了")
	tip._panel.hover("recipe:fuse_twin_blades")
	tip.tick(HoverTip.TERM_SEC + 0.01, inside)
	var open := tip.windows()
	t.eq(open.size(), 2, "停在配方词上：开了子窗")
	if open.size() == 2:
		var child := open[1]
		t.check(child.item_mode and child.text().contains(Names.of(CS._content().items.get_def(&"twin_blades"))), "子窗是双刀的整段窗")
		t.check(child.has_recipe, "子窗里也有道具词")
		tip.pin(child)
		var grand := tip.open_child(child, "item:knife")
		t.not_null(grand, "再往下开一层（匕首）")
		if grand != null:
			tip.pin(grand)
			t.is_null(tip.open_child(grand, "recipe:fuse_twin_blades"), "到 %d 层就停" % HoverTip.MAX_DEPTH)
	(f["host"] as Control).queue_free()
	# 没有配方词的窗：挪进窗里照收
	f = _board(root, &"smoked_fish")
	tip = f["tip"]
	t.check(tip.is_showing() and not tip._panel.has_recipe, "熏鱼的窗没有配方词")
	inside = _inside(tip, f["view"])
	tip.tick(0.016, inside)
	t.check(not tip.is_showing(), "挪进窗里：当场收（作者 10-27）")
	(f["host"] as Control).queue_free()
	# 286 测试 11-07：格子边到窗边有一条几像素的缝 —— 鼠标停在缝上不收
	f = _board(root, &"knife")
	tip = f["tip"]
	var rr := tip._panel.global_rect()
	var gap := Vector2(rr.position.x - 6.0, rr.end.y - 6.0)
	if not (f["view"] as Control).get_global_rect().has_point(gap):
		tip.tick(0.016, gap)
		t.check(tip.is_showing(), "窗边外 6 像素（源和窗之间的缝）：不收")
		tip.tick(0.016, gap - Vector2(HoverTip.RECIPE_BRIDGE_PX + 4.0, 0))
		t.check(not tip.is_showing(), "再往外：收")
	(f["host"] as Control).queue_free()
	# 带配方词的窗：挪进窗里又挪出去（不回道具）→ 收
	f = _board(root, &"knife")
	tip = f["tip"]
	inside = _inside(tip, f["view"])
	tip.tick(0.016, inside)
	tip.tick(0.016, Vector2(1500, 880))
	t.check(not tip.is_showing(), "从窗里挪出去：收")
	(f["host"] as Control).queue_free()
