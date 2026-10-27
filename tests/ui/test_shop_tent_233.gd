## 233（作者 21:42 选乙）：商店窗是集市帐篷 —— 篷面九宫格（三组 margin 照美术 tent.json）、尖顶和布招牌画在窗顶、标题字写在红布上；
## 窗离顶端栏留够尖顶的高；缺图退回石板
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "shop_tent_233"
const NOWHERE := "res://tests/fixtures/__no_such_art__/"


static func _shop(root: Window, f: GameFlow) -> Node:
	var screen = load("res://ui/game/shop_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open({})
	return screen


static func frame_tent(t: TestCase, root: Window) -> void:
	t.begin("233 · 商店帐篷：篷面九宫格三组 margin、尖顶与布招牌在窗顶正中、标题浅字居中写在布牌上、内容边距和石板一样")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, PREFIX)
	f.begin(c.chapter, kit, 1)
	f.pick_spawn(f.run.map.entry_ids[0])
	var screen = _shop(root, f)
	var frame: OverlayFrame = screen.overlay_frame()
	t.check(frame != null and frame.tent and frame.skin == OverlayFrame.SKIN_TENT, "帐篷皮")
	var box := frame.get_theme_stylebox("panel") as StyleBoxTexture
	t.check(box != null and box.texture == UiTheme.art_cached("shop/tent_front"), "篷面是 tent_front 的九宫格")
	if box != null:
		t.eq([box.texture_margin_left, box.texture_margin_top, box.texture_margin_right, box.texture_margin_bottom], [126.0, 94.0, 126.0, 80.0], "texture_margin")
		t.eq([box.expand_margin_left, box.expand_margin_top, box.expand_margin_right, box.expand_margin_bottom], [92.0, 30.0, 92.0, 40.0], "expand_margin（门帘、檐、地毯画在窗外）")
		t.eq([box.content_margin_left, box.content_margin_top, box.content_margin_right, box.content_margin_bottom], [24.0, 14.0, 24.0, 30.0], "content_margin（内容不挪）")
	t.eq(UiTheme.tone_at(frame), UiTheme.TONE_LIGHT, "浅底")
	t.eq(frame.title(), "商店", "标题照旧")
	t.eq(frame.title_label.theme_type_variation, UiTheme.LABEL_TENT_SIGN, "标题用布招牌的变体")
	t.eq(frame.title_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "字居中")
	t.eq(frame.title_label.get_theme_color("font_color"), UiTheme.TENT_SIGN_INK, "浅色字（红布上），不被浅底的墨字主题盖掉")
	frame.size = Vector2(1400, 800)     # 纸卷键比平板按钮宽，整扇最窄 1286；作者 10-27 左下加了钱袋，按内容还会更宽
	var half := frame.size.x * 0.5
	t.eq(frame.tent_peak_at(), Vector2(half - 210, -56), "尖顶左上 = (W/2 − 210, −56)")
	t.eq(frame.tent_sign_at(), Vector2(half - 138, -4), "布牌左上 = (W/2 − 138, −4)")
	t.eq(frame.outset_top(), 56.0, "窗顶上要让出 56")
	var body_top: float = box.content_margin_top + frame.title_bar.get_combined_minimum_size().y + OverlayFrame.GAP
	t.check(body_top >= 70.0 + OverlayFrame.TENT_SIGN_CLEAR - 0.01, "内容从布牌流苏下面开始（%.0f ≥ 76），第一行字不被流苏挡" % body_top)
	t.eq(frame.title_label.custom_minimum_size.y, float(OverlayFrame.TENT_TITLE_H), "标题字那行 36 高（14..50，字心对红布 y 32）")
	t.eq(frame.title_label.size_flags_vertical, Control.SIZE_SHRINK_BEGIN, "字贴标题条顶")
	t.eq(int(frame.content.get_theme_constant("margin_left")), OverlayFrame.TENT_SIDE_PAD, "左右再让门帘 12")
	# 顶端栏让位：居中区往下让，窗顶离栏底 ≥ 56
	var center := frame.get_parent() as Control
	screen.size = Vector2(1600, 900)
	frame.custom_minimum_size = Vector2(1200, 800)
	screen.resized.emit()
	var bar := HudHost.bar_height_in(root.get_tree())
	var fh := frame.get_combined_minimum_size().y
	var top: float = center.offset_top + (screen.size.y - center.offset_top - fh) * 0.5
	t.check(top - bar >= 56.0 - 0.01, "窗太高时整块往下挪：窗顶离栏 %.1f ≥ 56" % (top - bar))
	frame.custom_minimum_size = Vector2(600, 300)
	screen.size = Vector2(1600, 2000)     # 227 起货架、出售区都带框，内容本身就有七百多高 —— 屏高给足
	screen.resized.emit()
	t.eq(center.offset_top, bar, "空隙够了不挪")
	screen.free()
	Support.cleanup(PREFIX)


static func frame_tent_fallback(t: TestCase, root: Window) -> void:
	t.begin("233 · 帐篷缺图退回石板，标题照旧；别的叠层还是石板")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, PREFIX + "b")
	f.begin(c.chapter, kit, 1)
	f.pick_spawn(f.run.map.entry_ids[0])
	var saved := UiTheme.asset_root
	UiTheme.asset_root = NOWHERE
	var bare := OverlayFrame.new(16, OverlayFrame.SKIN_TENT)
	UiTheme.asset_root = saved
	t.check(not bare.tent and bare.skin == OverlayFrame.SKIN_SLAB and bare.outset_top() == 0.0, "没图：石板、不让位")
	bare.set_title("商店")
	t.eq(bare.title(), "商店", "标题照旧")
	t.eq(bare.title_label.theme_type_variation, UiTheme.LABEL_OVERLAY_TITLE, "石板的标题变体")
	bare.free()
	var slab := OverlayFrame.new()
	t.check(not slab.tent and slab.skin == OverlayFrame.SKIN_SLAB, "默认还是石板")
	slab.free()
	Support.cleanup(PREFIX + "b")


## 227 帐篷不出屏（UI替换美术 10-27 选 A：钱袋放在随身那几颗右边、【离开】正上方）：中英文商店开着货架与钱袋，
## 窗身不超 1600 宽，钱袋不把帐篷撑宽（藏起钱袋量一次，宽度一样）
static func frame_tent_on_screen(t: TestCase, root: Window) -> void:
	t.begin("227 · 帐篷不出屏：中英文商店（货架、随身币座、钱袋都在）窗身 ≤ 1600，钱袋不撑宽帐篷")
	var Keys := load("res://tests/ui/test_shop_keys.gd")
	var saved := UiText.lang
	for lang in ["zh", "en"]:
		UiText.lang = lang
		var opened: Dictionary = Keys._open(root)
		var screen = opened["screen"]
		var frame: OverlayFrame = screen.overlay_frame()
		var with_pouch := frame.get_combined_minimum_size().x
		t.check(with_pouch <= 1600.0, "%s：窗身 %.0f ≤ 1600" % [lang, with_pouch])
		var pouch: Control = screen._pouch
		t.not_null(pouch, "%s：有钱袋" % lang)
		if pouch != null:
			pouch.visible = false
			t.eq(frame.get_combined_minimum_size().x, with_pouch, "%s：钱袋不把帐篷撑宽" % lang)
			pouch.visible = true
		screen.free()
		Support.cleanup(Keys.PREFIX)
	UiText.lang = saved
