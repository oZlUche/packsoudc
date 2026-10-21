## 作者 2026-10-21：只有最后点中的那件画增益槽 / 受益槽；按住 Alt 藏悬浮窗；游戏测试：英文计数分单复数
extends RefCounted

const TT := preload("res://tests/ui/test_tooltip_193.gd")


static func frame_focus_by_click(t: TestCase, root: Window) -> void:
	t.begin("作者 10-21 · 点中一件才画它的格位：点道具 = 点中它，点空格 = 都收起")
	var f := TT._board_tip(root)
	var view: InventoryView = f["view"]
	InventoryView.set_focused(null, null)
	t.check(InventoryView.focused == null, "开局谁都没点中")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(4, 4)
	view._gui_input(click)
	t.check(InventoryView.focused == f["inst"], "点在道具上：点中它")
	var empty := InputEventMouseButton.new()
	empty.button_index = MOUSE_BUTTON_LEFT
	empty.pressed = true
	empty.position = view.size - Vector2(4, 4)
	view._gui_input(empty)
	t.check(InventoryView.focused == null, "点空格：收起")
	(f["host"] as Control).queue_free()


static func frame_alt_hides_tip(t: TestCase, root: Window) -> void:
	t.begin("作者 10-21 · 按住 Alt 悬浮窗藏起来，松开回来")
	var f := TT._board_tip(root)
	var tip: HoverTip = f["tip"]
	t.check(tip.is_showing() and tip.is_visible_in_tree(), "停在道具上：看得见")
	tip.hold_alt(true)
	t.check(not tip.is_visible_in_tree(), "按住 Alt：藏起来")
	t.check(tip.is_showing(), "只是藏着，窗没收")
	tip.hold_alt(false)
	t.check(tip.is_visible_in_tree(), "松开：回来")
	(f["host"] as Control).queue_free()


static func run_english_counts(t: TestCase) -> void:
	t.begin("游戏测试 10-21 · 英文计数分单复数：1 page / 2 pages，中文照旧")
	var lang0 := UiText.lang
	UiText.lang = "en"
	t.eq(UiText.count(1, "unit.page"), "1 page", "一页单数")
	t.eq(UiText.count(2, "unit.page"), "2 pages", "两页复数")
	t.eq(UiText.t("meta.shelf_title") % [UiText.count(0, "unit.item"), UiText.count(1, "unit.page")], "Warehouse · 0 items · 1 page", "仓库标题")
	t.eq(UiText.t("notice.safe_closed") % UiText.count(1, "unit.item"), "The safe has closed: 1 item sent home", "保险箱告示一件单数")
	UiText.lang = "zh"
	t.eq(UiText.t("notice.safe_closed") % UiText.count(1, "unit.item"), "保险箱关上了：1 件送回基地", "保险箱告示中文不变")
	t.eq(UiText.t("meta.shelf_title") % [UiText.count(3, "unit.item"), UiText.count(1, "unit.page")], "仓库　3 件　1 页", "中文不变")
	UiText.lang = lang0
