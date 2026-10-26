## 170（作者定）：道具悬浮窗 —— 深底白字、版式 A（头 / 正文 / 脚注分块）、名字粗体、说明斜体、行内图标；定稿（2026-10-14）：只有名字和稀有度名描边，字号各大一号；
## 武器写「每 X 秒造成 Y 点伤害，消耗 Z 耐力」，不写冷却 / DPS / 格数；十字军之王式的固定悬浮窗（钉住、关键词开子窗）。
extends RefCounted


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func run_item_layout(t: TestCase) -> void:
	t.begin("170 · 道具说明分块：名字粗体 19 在最前、副行稀有度 · 标签、说明斜体；正文武器句；脚注金币与秤砣图标；只有名字和稀有度名描边；关键词是 url")
	var db := _db()
	var knife := ItemInstance.create(db.get_def(&"knife"))
	var full := ItemTooltip.describe_full(knife)
	var head := String(full["head"])
	var body := String(full["body"])
	var foot := String(full["foot"])
	t.check(head.begins_with("[outline_size="), "头从名字开始（名字描边）")
	t.check(head.contains("[font_size=%d][b]" % ItemTooltip.NAME_SIZE) and head.contains(Names.of_item(knife)), "名字粗体 %d" % ItemTooltip.NAME_SIZE)
	t.eq([ItemTooltip.NAME_SIZE, ItemTooltip.SUB_SIZE, ItemTooltip.DESC_SIZE, ItemTooltip.BODY_SIZE, ItemTooltip.FOOT_SIZE], [20, 14, 15, 16, 14], "定稿字号：名字 20、副行 14、说明 15、正文 16、脚注 14")
	t.eq(HoverTip.MAX_WIDTH, 360.0, "定稿宽 360")
	var name_at := head.find(Names.of_item(knife))
	var rarity_at := head.find(ItemTooltip.rarity_name(knife.def.rarity))
	t.check(name_at >= 0 and rarity_at > name_at, "名字 → 副行（稀有度）")
	if Names.description_of(knife.def) != "":
		t.check(head.contains("[i]"), "说明是斜体")
	var plain := Glossary.strip_bbcode(body)
	var re := RegEx.create_from_string("每 [0-9.]+ 秒造成 [0-9.]+ 点伤害，消耗 [0-9.]+ 耐力")
	t.check(re.search(plain) != null, "武器句：每 X 秒造成 Y 点伤害，消耗 Z 耐力（%s）" % plain)
	var all := Glossary.strip_bbcode(String(full["text"]))
	for word in ["冷却", "DPS", "格　", " 格"]:
		t.check(not all.contains(word), "不写「%s」" % word.strip_edges())
	t.eq(foot.count("[img="), 2, "脚注两个图标（金币、秤砣）")
	t.check(foot.contains("coin.png") and foot.contains("weight.png"), "金币与秤砣")
	t.eq(head.count("[outline_size=%d]" % UiTheme.OUTLINE_SIZE), 2, "头里只有名字和稀有度名两处描边")
	t.check(not body.contains("[outline_size=") and not foot.contains("[outline_size="), "正文、脚注不描边")
	t.check(body.begins_with("[font_size=%d][color=@tip_fg]" % ItemTooltip.BODY_SIZE), "正文白（tip_fg）")
	t.check(foot.contains("[color=@tip_meta]"), "脚注 tip_meta")
	t.check(head.contains("[url=term:tag:weapon][img=%d]" % ItemTooltip.TAG_ICON_SIZE), "193 补充三：副行的标签是图标，链到词条")
	if Names.description_of(knife.def) != "":
		t.check(head.contains("[i][color=@tip_desc]"), "说明 tip_desc")


static func run_keywords(t: TestCase) -> void:
	t.begin("170 · 关键词：词条是 [url=term:<id>][u]…；terms 是 {id: {name, text}}；标签名不弹的不带下划线")
	var db := _db()
	var bow := ItemInstance.create(db.get_def(&"poison_arrows"))
	var full := ItemTooltip.describe_full(bow)
	var terms: Dictionary = full["terms"]
	t.check(not terms.is_empty(), "有词条（%s）" % str(terms.keys()))
	for id in terms:
		var e: Dictionary = terms[id]
		t.check(e.has("name") and e.has("text"), "「%s」有名字与说明" % id)
		t.check(String(full["text"]).contains("[url=term:%s]" % id), "「%s」在文字里是关键词链接" % id)
	t.check(String(full["text"]).contains("[u]"), "关键词有下划线")


static func run_italic_theme(t: TestCase) -> void:
	t.begin("170 · 主题：富文本的斜体是正文字体斜切；悬浮窗底是深底（定稿：深皮革平铺 + 黄铜边框九宫格两层，tone: dark）")
	var th := UiTheme.build()
	var it := th.get_font("italics_font", "RichTextLabel")
	t.check(it is FontVariation and absf((it as FontVariation).variation_transform.x.y - UiTheme.ITALIC_SLANT) < 0.001, "斜体 = 斜切 %.1f" % UiTheme.ITALIC_SLANT)
	t.eq(UiTheme.tone_of(UiTheme.PANEL_TOOLTIP), UiTheme.TONE_DARK, "悬浮窗是深底")
	t.not_null(UiTheme.art(UiTheme.ART_TOOLTIP), "黄铜边框在")
	t.not_null(UiTheme.art(UiTheme.ART_TOOLTIP_BODY), "皮革板身在")
	var box := th.get_stylebox("panel", UiTheme.PANEL_TOOLTIP)
	t.check(box is SlabStyle and (box as SlabStyle).body != null and (box as SlabStyle).edge != null, "两层画（板身 + 边框）")
	if box is SlabStyle:
		t.eq((box as SlabStyle).body.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE, "板身平铺不拉伸")
	for c in ["tip_fg", "tip_meta", "tip_desc"]:
		t.check((UiPalette.text_colors()["styles"] as Dictionary).has(c), "字色模板有 %s" % c)


static func run_ring(t: TestCase) -> void:
	t.begin("170 · 钉住进度线：从左上角起顺时针沿外框走 —— 走到四分之一周长在上边，一半到右下角，走满回到起点")
	var r := Rect2(Vector2.ZERO, Vector2(100, 50))
	t.eq(HoverTip.ring_points(r, 0.0).size(), 2, "起点")
	var q := HoverTip.ring_points(r, 1.0 / 6.0)     # 周长 300，走 50：在上边中点
	t.check(q[q.size() - 1].distance_to(Vector2(50, 0)) < 0.01, "先沿上边往右")
	var half := HoverTip.ring_points(r, 0.5)
	t.check(half[half.size() - 1].distance_to(Vector2(100, 50)) < 0.01, "一半到右下角（顺时针）")
	var full := HoverTip.ring_points(r, 1.0)
	t.check(full[full.size() - 1].distance_to(Vector2.ZERO) < 0.01, "走满回到左上角")


static func frame_pin(t: TestCase, root: Window) -> void:
	t.begin("170 · 固定式悬浮窗：离开道具有 0.15 秒宽限；停在窗里 0.6 秒钉住、中途移出归零；钉住后关键词停 0.25 秒开子窗（封顶 3 层）；Esc / 点外面 / 离开 0.4 秒收")
	var db := _db()
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var board := GridInventory.new(Vector2i(4, 3), 1)
	var arrows := ItemInstance.create(db.get_def(&"poison_arrows"))
	board.place(arrows, Vector2i(0, 0), 0)
	var view := InventoryView.new()
	view.inventory = board
	view.position = Vector2(20, 20)
	view.size = Vector2(board.size) * InventoryView.CELL
	host.add_child(view)
	var tip := HoverTip.new()
	host.add_child(tip)
	tip.watch(view)
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(24, 24)
	view.gui_input.emit(mm)
	t.check(tip.is_showing(), "停在道具上：出现")
	var inside := tip._panel.global_position + tip._panel.size * 0.5
	var outside := Vector2(5, 880)
	# 宽限：离开道具（移到空格）后 0.15 秒内进了窗就留下
	var empty := InputEventMouseMotion.new()
	empty.position = Vector2(200, 160)
	view.gui_input.emit(empty)
	t.check(tip.is_showing(), "刚离开：还在（宽限）")
	tip.tick(0.1, inside)
	t.check(tip.is_showing(), "宽限内进了窗：留下")
	# 钉住：中途移出归零
	tip.tick(0.3, inside)
	t.check(not tip.is_pinned(), "停了 0.4 秒：还没钉")
	tip.tick(0.05, outside)
	t.eq(tip._panel.dwell, 0.0, "中途移出：进度归零")
	t.check(tip.is_showing(), "移出时没在离开道具（宽限已经结束）—— 还开着")
	tip.tick(0.3, inside)
	tip.tick(0.31 + HoverTip.PIN_DELAY_SEC, inside)
	t.check(tip.is_pinned(), "停满 0.5 + 0.6 秒：钉住（193 先等半秒）")
	# 关键词开子窗
	var terms: Dictionary = tip._panel.terms
	t.check(not terms.is_empty(), "主窗有词条")
	var first := String(terms.keys()[0])
	tip._panel.hover("term:" + first)
	tip.tick(0.1, inside)
	t.eq(tip.windows().size(), 1, "停 0.1 秒：还没开子窗")
	tip.tick(0.2, inside)
	t.eq(tip.windows().size(), 2, "停满 0.25 秒：开子窗")
	var child: HoverTip.TipWindow = tip.windows()[1]
	t.check(child.text().contains(String(terms[first]["name"])), "子窗写的是这个词条（%s）" % first)
	t.check(child.position.x >= tip._panel.position.x + tip._panel.size.x - 0.5 or child.position.y >= tip._panel.position.y + tip._panel.size.y - 0.5, "子窗在主窗右边或下面")
	# 子窗钉住、再开、封顶
	var child_in := child.global_position + child.size * 0.5
	tip.tick(0.61 + HoverTip.PIN_DELAY_SEC, child_in)
	t.check(child.pinned, "子窗也能钉")
	child.terms["probe"] = {"name": "探针", "text": "说明"}
	var grand := tip.open_child(child, "term:probe")
	t.not_null(grand, "子窗还能开子窗")
	if grand != null:
		tip.pin(grand)
		grand.terms["probe2"] = {"name": "探针二", "text": "说明"}
		t.check(tip.open_child(grand, "term:probe2") == null, "第 4 层开不出来（封顶 %d）" % HoverTip.MAX_DEPTH)
	# 离开 0.4 秒收
	tip.tick(0.2, outside)
	t.check(tip.is_showing(), "离开 0.2 秒：还在")
	tip.tick(0.25, outside)
	t.check(not tip.is_showing(), "离开 0.4 秒：整串收掉")
	# Esc
	view.gui_input.emit(mm)
	inside = tip._panel.global_position + tip._panel.size * 0.5
	tip.tick(0.7 + HoverTip.PIN_DELAY_SEC, inside)
	t.check(tip.is_pinned(), "又钉住")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	tip._input(esc)
	t.check(not tip.is_showing(), "Esc 收掉")
	# 点外面（开始拖拽也是先点下去）
	view.gui_input.emit(mm)
	inside = tip._panel.global_position + tip._panel.size * 0.5
	tip.tick(0.7 + HoverTip.PIN_DELAY_SEC, inside)
	tip.click_at(inside)
	t.check(tip.is_showing(), "点在窗里：不收")
	tip.click_at(outside)
	t.check(not tip.is_showing(), "点窗外：收掉")
	# 宽限过了没进窗：收
	view.gui_input.emit(mm)
	view.gui_input.emit(empty)
	tip.tick(0.2, outside)
	t.check(not tip.is_showing(), "宽限过了还没进窗：收起")
	host.queue_free()


## 作者 10-26：道具悬浮窗贴着被指那件的外框摆，不贴鼠标；右边放不下换左边，再不行下、上 —— 四个方向都适配
static func run_beside_rect(t: TestCase) -> void:
	t.begin("作者 10-26 · 悬浮窗贴物品外框：右 → 左 → 下 → 上，先用整块放得下的那边，都在屏内")
	var screen := Rect2(0, 0, 1600, 1000)
	var s := Vector2(360, 300)
	var item := Rect2(400, 300, 120, 60)
	t.eq(HoverTip.beside_rect(item, s, screen), Vector2(item.end.x + HoverTip.ANCHOR_GAP, 300), "右边放得下：贴右沿，顶对齐")
	var right := Rect2(1400, 300, 120, 60)
	t.eq(HoverTip.beside_rect(right, s, screen), Vector2(1400 - 360 - HoverTip.ANCHOR_GAP, 300), "右边放不下：贴左沿，不压着物品")
	var wide := Rect2(200, 100, 1200, 60)     # 左右都放不下
	t.eq(HoverTip.beside_rect(wide, s, screen), Vector2(200, 160 + HoverTip.ANCHOR_GAP), "左右都放不下：贴下沿")
	var low := Rect2(200, 900, 1200, 60)
	t.eq(HoverTip.beside_rect(low, s, screen), Vector2(200, 900 - 300 - HoverTip.ANCHOR_GAP), "下面也放不下：贴上沿")
	var bottom_right := Rect2(1400, 900, 120, 60)
	var p := HoverTip.beside_rect(bottom_right, s, screen)
	t.check(screen.encloses(Rect2(p, s)), "靠右下角的物品：窗夹回屏内（%s）" % p)
	t.check(not Rect2(p, s).intersects(bottom_right), "也不压着物品")


static func frame_anchor_item(t: TestCase, root: Window) -> void:
	t.begin("作者 10-26 · 棋盘上停在道具上：窗贴着这件的外框，鼠标停在这件的哪一格都一样")
	var db := _db()
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var board := GridInventory.new(Vector2i(4, 3), 1)
	var arrows := ItemInstance.create(db.get_def(&"poison_arrows"))
	board.place(arrows, Vector2i(1, 0), 0)
	var view := InventoryView.new()
	view.inventory = board
	view.position = Vector2(20, 20)
	view.size = Vector2(board.size) * InventoryView.CELL
	host.add_child(view)
	var tip := HoverTip.new()
	host.add_child(tip)
	tip.watch(view)
	var r := view.item_rect(arrows.uid)
	t.eq(r.position, view.cell_origin_px(Vector2i(1, 0)), "外框从落点那格起")
	var mm := InputEventMouseMotion.new()
	mm.position = r.position + Vector2(4, 4)
	view.gui_input.emit(mm)
	t.check(tip.is_showing(), "出现")
	tip._refit()
	var at1 := tip._panel.global_position
	t.eq(at1, Vector2(view.global_position.x + r.end.x + HoverTip.ANCHOR_GAP, view.global_position.y + r.position.y), "贴着这件的右沿、顶对齐（不是鼠标边上）")
	tip.hide_tip()
	mm.position = r.end - Vector2(4, 4)
	view.gui_input.emit(mm)
	tip._refit()
	t.eq(tip._panel.global_position, at1, "鼠标换到这件的另一角：窗不动")
	host.queue_free()
