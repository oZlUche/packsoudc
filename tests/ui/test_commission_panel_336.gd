## 336 W1：基地「委托」页 —— 左列三方的键、右边任务卡；按「接下」接单、卡上换成「暂缓」「放弃」；字都在羊皮纸条上不裸；
## 结算屏的委托段落写一句
extends RefCounted

const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const Bare := preload("res://tests/ui/test_no_bare_text_226.gd")
const ResultScreenScript := preload("res://ui/game/result_screen.gd")


static func _keys_text(n: Node, out: Array[String]) -> Array[String]:
	if n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_keys_text(c, out)
	return out


static func frame_commission_tab(t: TestCase, root: Window) -> void:
	t.begin("336 W1 · 委托页：三方三颗键；军团页有《两条回路》的卡，按「接下」后卡上是「暂缓」「放弃」；字不裸")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	t.check(f.commissions_visible(), "没有教程章：委托页露出来")
	var s: Control = W178._screen(f, root)
	t.check((s._tab_btns as Dictionary).has("commissions"), "有「委托」页签")
	s.show_tab("commissions")
	var p = s.commission_panel()
	t.not_null(p, "委托页建好了")
	if p == null:
		s.queue_free()
		W178._cleanup()
		return
	t.eq((p._key_btns as Dictionary).size(), 3, "三方三颗键（使者、猎人不列）")
	p.show_faction(&"legion")
	var card: Node = p.find_child("Card_legion_two_routes", true, false)
	t.not_null(card, "军团页有《两条回路》")
	t.eq(p.take(&"legion_two_routes"), "", "按「接下」接了")
	card = p.find_child("Card_legion_two_routes", true, false)
	var keys := _keys_text(card, [] as Array[String]) if card != null else [] as Array[String]
	t.check(keys.has(UiText.t("commission.pause")) and keys.has(UiText.t("commission.abandon")), "卡上换成「暂缓」「放弃」")
	p.show_faction(&"society")
	var take: Button = p.find_child("Take_society_copy_recipe", true, false) as Button
	t.check(take != null and take.disabled, "配方实验没选配方：「接下」灰着")
	t.eq(Bare.audit(p, "commission336"), [] as Array[String], "字不裸")
	s.queue_free()
	W178._cleanup()


static func frame_result_section(t: TestCase, _root: Window) -> void:
	t.begin("336 W1 · 结算屏：这一局委托有动静就多一段，写谁办成了、还差几处；没动静不加")
	var m := MetaState.new()
	t.is_null(ResultScreenScript.commission_panel({}, m), "没动静：不加段落")
	m.commissions.entries["greylamp_unsigned_letter"] = {"state": CommissionBook.DONE, "times": 1}
	var got := {"tracked": [{"id": "greylamp_unsigned_letter", "stage": 0}], "rows": [{"id": "greylamp_unsigned_letter", "stage": 0, "key": "1/uid:3"}]}
	var lines: Array[String] = ResultScreenScript.commission_lines(got, m)
	t.eq(lines, [UiText.t("commission.rcpt_done") % Names.of(Commissions.def(&"greylamp_unsigned_letter"))] as Array[String], "写「……办成了」")
	var box: PanelContainer = ResultScreenScript.commission_panel(got, m)
	t.not_null(box, "有段落")
	if box != null:
		t.eq(Bare.audit(box, "result336"), [] as Array[String], "字不裸")
		box.free()
