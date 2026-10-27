## 258（作者 2026-10-27 定）：设置里的字号三档 小 / 中 / 大 = ×1.0 / 1.125 / 1.25（中档至少 +1、大档至少 +2），默认中；
## 主题、造控件的入口、富文本里的 [font_size=N] 都按档放大，主菜单不跟
extends RefCounted


static func run_tier_table(t: TestCase) -> void:
	t.begin("258 · 三档各建一次主题：默认字号与几个变体照表 2.1；主菜单的字三档一样；富文本 [font_size=16] 大档 20")
	var saved := UiTheme.text_size
	var pinned := UiTheme.pinned_text_size     # 按某一档整套跑时先松开，量完钉回去
	UiTheme.pinned_text_size = &""
	var table := {
		&"small": {"default": 14, "display": 40, "body": 20, "small": 13, "cap": 28, "rich16": 16},
		&"medium": {"default": 16, "display": 45, "body": 23, "small": 15, "cap": 32, "rich16": 18},
		&"large": {"default": 18, "display": 50, "body": 25, "small": 16, "cap": 35, "rich16": 20},
	}
	var menu := {}
	for tier in GameSettings.TEXT_SIZES:
		UiTheme.set_text_size(tier)
		var th := UiTheme.build()
		var want: Dictionary = table[tier]
		t.eq(th.default_font_size, int(want["default"]), "%s：默认字号" % tier)
		t.eq(th.get_font_size("font_size", UiTheme.LABEL_DISPLAY), int(want["display"]), "%s：大标题" % tier)
		t.eq(th.get_font_size("normal_font_size", UiTheme.RICH_BODY), int(want["body"]), "%s：事件正文" % tier)
		t.eq(th.get_font_size("normal_font_size", UiTheme.RICH_SMALL), int(want["small"]), "%s：悬浮窗小字" % tier)
		t.eq(th.get_font_size("font_size", UiTheme.LABEL_CAP_VALUE), int(want["cap"]), "%s：图标牌数字" % tier)
		t.eq(UiPalette.sized("[font_size=16]x[/font_size]"), "[font_size=%d]x[/font_size]" % int(want["rich16"]), "%s：富文本 16 号" % tier)
		t.eq(UiPalette.sized("[font_size=1]x"), "[font_size=1]x", "%s：1 号撑宽行不放大" % tier)
		var m := [th.get_font_size("font_size", UiTheme.BUTTON_MENU_LINE), th.get_font_size("font_size", UiTheme.BUTTON_MENU_FOOT),
			th.get_font_size("font_size", UiTheme.LABEL_HERO_TITLE)]
		menu[tier] = m
		var l := UiTheme.make_label("x", 20)
		t.eq(l.get_theme_font_size("font_size"), UiTheme.sz(20), "%s：make_label 传 20 按档放大" % tier)
		var plain := UiTheme.make_label("x", 20, UiPalette.FG, false)
		t.eq(plain.get_theme_font_size("font_size"), 20, "%s：不跟档的标签（主菜单）照原字号" % tier)
		l.free()
		plain.free()
	t.check(menu[&"small"] == menu[&"medium"] and menu[&"small"] == menu[&"large"] and menu[&"small"] == [UiTheme.MENU_PRIMARY_SIZE, UiTheme.MENU_FOOT_SIZE, UiTheme.HERO_TITLE_SIZE],
		"主菜单的字三档相同：%s" % str(menu))
	UiTheme.set_text_size(saved)
	UiTheme.pinned_text_size = pinned


static func run_settings_field(t: TestCase) -> void:
	t.begin("258 · GameSettings.text_size：默认中；老设置文件没这项按中；认不出的按中；大档存读一圈不变；不升版本")
	t.eq(GameSettings.new().text_size, &"medium", "默认中")
	var old := GameSettings.new().to_dict()
	old.erase("text_size")
	t.eq(GameSettings.from_dict(old).text_size, &"medium", "老文件按中")
	var bad := GameSettings.new().to_dict()
	bad["text_size"] = "huge"
	t.eq(GameSettings.from_dict(bad).text_size, &"medium", "认不出的按中")
	var s := GameSettings.new()
	s.text_size = &"large"
	t.eq(GameSettings.from_dict(s.to_dict()).text_size, &"large", "大档存读一圈")
	t.eq(GameSettings.SAVE_VERSION, 1, "不升版本")


static func run_sz(t: TestCase) -> void:
	t.begin("258 · UiTheme.sz：中档 13 → 15、14 → 16；大档 13 → 16、28 → 35；小档原样；8 号以下只乘倍率")
	var saved := UiTheme.text_size
	var pinned := UiTheme.pinned_text_size     # 按某一档整套跑时先松开，量完钉回去
	UiTheme.pinned_text_size = &""
	UiTheme.set_text_size(&"small")
	t.eq([UiTheme.sz(13), UiTheme.sz(360)], [13, 360], "小档原样")
	UiTheme.set_text_size(&"medium")
	t.eq([UiTheme.sz(13), UiTheme.sz(14), UiTheme.sz(360), UiTheme.sz(1)], [15, 16, 405, 1], "中档")
	UiTheme.set_text_size(&"large")
	t.eq([UiTheme.sz(13), UiTheme.sz(28), UiTheme.sz(360)], [16, 35, 450], "大档")
	t.eq(Glossary.text_scale, 1.25, "core 那边的倍率跟着改")
	UiTheme.set_text_size(saved)
	UiTheme.pinned_text_size = pinned


## 游戏测试 v4.58：中、大档两处出框 —— 选人页蜡板小字压到数字上；英文开局书页的章节名撑宽右页
static func run_fixed_boxes(t: TestCase) -> void:
	t.begin("258 · 三档下：蜡板小字与数字不叠；开局书页章节名（英文最长那句）不宽过右页")
	var saved := UiTheme.text_size
	var pinned := UiTheme.pinned_text_size
	UiTheme.pinned_text_size = &""
	var event_screen: GDScript = load("res://ui/game/event_screen.gd")
	var page_w := float((OverlayFrame.book_meta().get("text_rect", [704, 44, 560, 672]) as Array)[2])
	for tier in GameSettings.TEXT_SIZES:
		UiTheme.set_text_size(tier)
		UiTheme.refresh(GameSettings.new())
		t.eq(StatPlaque.font_sizes(), [StatPlaque.LABEL_SIZE, StatPlaque.VALUE_SIZE] as Array[int], "%s：蜡板定高，小字与数字照小档（不叠）" % tier)
		var h: Label = event_screen._heading_label("Prologue: Edge of the Ruins", page_w)
		t.check(h.get_minimum_size().x <= page_w, "%s：章节名宽 %d ≤ 右页 %d" % [tier, int(h.get_minimum_size().x), int(page_w)])
		h.free()
	UiTheme.set_text_size(saved)
	UiTheme.pinned_text_size = pinned
	UiTheme.refresh(GameSettings.new())
