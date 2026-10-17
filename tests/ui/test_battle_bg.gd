## 战斗界面背景（作者 2026-10-17 定 A：沙地竞技场 · 白天）：垫在 [BattleView] 最底层、铺满裁边；
## 浅底 —— 直接写在背景上的字（顶上计时 / 胜负、战报、播报）用墨字；对阵面板自带深底，不跟着变
extends RefCounted


static func frame_battle_backdrop(t: TestCase, root: Window) -> void:
	t.begin("战斗背景：沙地竞技场铺满裁边垫在最底层；图旁 json 标浅底；顶上一行、战报、播报是墨字；对阵面板照旧深底")
	t.not_null(UiTheme.art(UiTheme.ART_BATTLE_BG), "背景图在（%s）" % UiTheme.ART_BATTLE_BG)
	t.eq(String(UiTheme.art_meta(UiTheme.ART_BATTLE_BG).get("tone", "")), "light", "json 标了浅底")
	t.eq(UiTheme.art_tone(UiTheme.ART_BATTLE_BG), UiTheme.TONE_LIGHT, "art_tone 读出浅")
	t.eq(UiTheme.art_tone("battle/no_such_bg"), UiTheme.TONE_DARK, "没图 = 纯色底，深")

	var view := BattleView.new()
	view.show_ticker = true
	root.add_child(view)
	var pics := view.find_children("BattleBackdrop", "TextureRect", true, false)
	t.eq(pics.size(), 1, "一张背景")
	if pics.size() == 1:
		var pic := pics[0] as TextureRect
		t.eq(pic.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "按比例铺满、多的裁掉")
		t.eq(pic.mouse_filter, Control.MOUSE_FILTER_IGNORE, "不挡鼠标")
		var bg := pic.get_parent() as ColorRect
		t.not_null(bg, "垫在底色那块上")
		if bg != null:
			t.eq(bg.get_index(), 0, "最底层（第一个孩子）")
	t.eq(UiTheme.tone_at(view._clock), UiTheme.TONE_LIGHT, "计时那行压在浅底上")
	t.eq(view._clock.get_theme_color("font_color"), UiTheme.INK_SOFT, "计时：褐墨")
	t.eq(view._verdict.get_theme_color("font_color"), UiTheme.INK, "胜负：墨字")
	t.eq(UiTheme.tone_at(view._report), UiTheme.TONE_LIGHT, "战报浅底")
	t.eq(view._report.get_theme_color("default_color"), UiTheme.INK, "战报：墨字")
	t.eq(UiTheme.tone_at(view._ticker), UiTheme.TONE_LIGHT, "播报浅底")
	t.eq(view._ticker.get_theme_color("default_color"), UiTheme.INK, "播报：墨字")
	for p in view._panels:
		t.eq(UiTheme.tone_at(p), UiTheme.TONE_DARK, "对阵面板不在浅底主题下（自带深底）")
		t.is_null((p as Control).theme, "对阵面板没挂墨字主题")
	view.queue_free()
