## 220 E（作者 219 E）：词条小窗底部一行「百科 >」，点了开百科的对应页 —— 局内局外一个样：导演盖一层在最上面，
## 「返回」/ Esc 关掉回原处，底下哪一屏都不动；没挂导演（测试里单独造的悬浮窗）就不画那一行
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "codex_link_220"


static func frame_codex_link(t: TestCase, root: Window) -> void:
	t.begin("220 E · 词条小窗「百科 >」开对应页；Esc 关掉回原处；导演走了钩子也撤")
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	var base = game.base()
	var page := flow.encyclopedia().page_for("格挡")
	t.check(page != "", "「格挡」在百科里有一页（%s）" % page)
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var tip := HoverTip.new()
	host.add_child(tip)
	tip.show_text("一面盾", Vector2(400, 400))
	tip.pin(tip._panel)
	tip._panel.terms = {"block": {"name": "格挡", "text": "固定减少直接伤害"}, "probe": {"name": "没这一页的词", "text": "说明"}}
	var child := tip.open_child(tip._panel, "term:block")
	t.not_null(child, "开了词条小窗")
	if child != null:
		t.check(child.foot_row.visible and child.foot.get_parsed_text().contains(HoverTip.CODEX_LINK), "底部一行「%s」" % HoverTip.CODEX_LINK)
		t.eq(child.codex(), page, "链到那一页")
		HoverTip.follow_codex(child, HoverTip.CODEX_META + child.codex())
		t.check(not tip.is_showing(), "点了：悬浮窗整串收掉")
		var book = game.codex()
		t.not_null(book, "开了百科")
		if book != null:
			t.eq(book.current_page(), page, "翻到对应页")
			t.check(book.z_index > GameDirector.OVERLAY_Z + GameDirector.GROUND_Z, "盖在叠层与地上之上（z %d）" % book.z_index)
			t.eq(game.base(), base, "底下那一屏没换")
			t.check(game.escape(), "Esc 有人接")
			t.is_null(game.codex(), "Esc：关掉回原处")
			t.eq(flow.screen, GameFlow.Screen.MAIN_MENU, "流程还在原来那一屏")
	tip.show_text("一面盾", Vector2(400, 400))
	tip.pin(tip._panel)
	tip._panel.terms = {"probe": {"name": "没这一页的词", "text": "说明"}}
	var none := tip.open_child(tip._panel, "term:probe")
	t.check(none != null and not none.foot_row.visible and none.codex() == "", "百科里没这一页：不画那一行")
	root.remove_child(game)
	t.check(not HoverTip.open_codex.is_valid() and not HoverTip.codex_page.is_valid(), "导演走了：钩子撤掉")
	tip.show_text("一面盾", Vector2(400, 400))
	tip.pin(tip._panel)
	tip._panel.terms = {"block": {"name": "格挡", "text": "固定减少直接伤害"}}
	var bare := tip.open_child(tip._panel, "term:block")
	t.check(bare != null and bare.codex() == "", "没挂导演：不画那一行")
	game.free()
	host.queue_free()
	Support.cleanup(PREFIX)
