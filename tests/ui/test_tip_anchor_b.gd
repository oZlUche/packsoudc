## 悬停小提示 B（作者 2026-10-31 16:05 选 B 木框小牌；游戏测试 v4.88 观察 1）：控件自带的 tooltip_text = 基地图例小签底、墨字 18 粗；
## 摆在被悬停那块正上方居中，上面放不下放下面，顶到屏边贴边，大块按鼠标摆；道具悬浮窗的深皮不动
extends RefCounted


static func run_style(t: TestCase) -> void:
	t.begin("悬停小提示 B：TooltipPanel 是木框小牌（plaque_chip）、内边距 18 / 9；TooltipLabel 墨字粗体 18（按字号档放大）；深浅小主题里也是墨字")
	var th := UiTheme.current()
	var box := th.get_stylebox("panel", "TooltipPanel")
	t.check(box is StyleBoxTexture and (box as StyleBoxTexture).texture == UiTheme.art_cached(UiTheme.ART_HOME_CHIP), "底是图例小签那张图")
	t.eq([box.content_margin_left, box.content_margin_right, box.content_margin_top, box.content_margin_bottom], [18.0, 18.0, 9.0, 9.0], "内边距")
	t.eq(th.get_color("font_color", "TooltipLabel"), UiTheme.INK, "墨字")
	t.check(th.get_font("font", "TooltipLabel") == UiPalette.cjk_font_bold() or th.get_font("font", "TooltipLabel").get_font_name() == UiPalette.cjk_font_bold().get_font_name(), "粗体")
	t.eq(th.get_font_size("font_size", "TooltipLabel"), UiTheme.sz(UiTheme.TIP_FONT_SIZE), "18 号（按档）")
	t.eq(UiTheme.text_theme(UiTheme.TONE_LIGHT).get_color("font_color", "TooltipLabel"), UiTheme.INK, "浅底小主题里的控件提示也是墨字（深底用全局主题，同上）")
	t.check(th.get_stylebox("panel", UiTheme.PANEL_TOOLTIP) != box, "道具悬浮窗的深皮不动")


static func run_spot(t: TestCase) -> void:
	t.begin("悬停小提示 B：TipAnchor.spot —— 正上方居中、留缝 4；上面放不下放下面；左右贴边；高过 240 的按鼠标")
	var vr := Rect2(0, 0, 1600, 1000)
	var size := Vector2(100, 40)
	t.eq(TipAnchor.spot(Rect2(500, 500, 60, 40), size, vr, Vector2.ZERO), Vector2(480, 456), "正上方居中")
	t.eq(TipAnchor.spot(Rect2(500, 20, 60, 40), size, vr, Vector2.ZERO), Vector2(480, 64), "顶上放不下：正下方")
	t.eq(TipAnchor.spot(Rect2(0, 500, 40, 40), size, vr, Vector2.ZERO), Vector2(0, 456), "左边贴边")
	t.eq(TipAnchor.spot(Rect2(1580, 500, 20, 40), size, vr, Vector2.ZERO), Vector2(1500, 456), "右边贴边")
	t.eq(TipAnchor.spot(Rect2(200, 100, 800, 600), size, vr, Vector2(600, 400)), Vector2(550, 356), "大块：鼠标正上方居中")
	t.eq(TipAnchor.spot(Rect2(500, 960, 60, 40), Vector2(100, 960), vr, Vector2.ZERO), Vector2(480, 40), "上下都放不下：贴着屏幕下沿")


static func frame_install(t: TestCase, root: Window) -> void:
	t.begin("悬停小提示 B：TipAnchor 接在树上（一次）；弹出来的 TooltipPanel 窗挪到主人正上方")
	var tree := root.get_tree()
	TipAnchor.install(tree)
	TipAnchor.install(tree)
	t.check(TipAnchor.installed(tree), "接上了")
	var host := Control.new()
	host.position = Vector2(300, 300)
	host.size = Vector2(80, 40)
	root.add_child(host)
	var w := PopupPanel.new()
	w.theme_type_variation = &"TooltipPanel"
	w.size = Vector2i(120, 36)
	host.add_child(w)
	w.popup(Rect2i(Vector2i(500, 500), w.size))
	var want := TipAnchor.spot(TipAnchor.owner_rect(host), Vector2(w.size), host.get_viewport().get_visible_rect(), host.get_viewport().get_mouse_position())
	t.eq(Vector2(w.position), want.round(), "挪到主人正上方（%s）" % want)
	host.queue_free()
