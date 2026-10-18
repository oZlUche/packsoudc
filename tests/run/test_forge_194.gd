## 194（作者「触发界面应该和其他选项并列」「应该实时显示每个字段的效果」）：铸炉是休息点事件的一个选项（神坛后、继续赶路前），
## 不算用掉休息那一份、铸过就藏；铸炉屏每槽放进一件立刻写三行，两槽满时按空槽的 default 行试算一枚
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const F175 := preload("res://tests/run/test_forge_175.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func _index_of(def: EventDef, head: String) -> int:
	for i in def.options.size():
		if (def.options[i] as EventOption).label.begins_with(head):
			return i
	return -1


static func _open_labels(f: GameFlow) -> Array[String]:
	var out: Array[String] = []
	var here := f.run.current_node()
	var ectx := f.run.events._event_ctx(here)
	var def: EventDef = f.run.events.pending_event()
	if def == null:
		return out
	for opt in def.options:
		if (opt as EventOption).locked_reason(ectx) == "":
			out.append((opt as EventOption).label)
	return out


static func run_entry(t: TestCase) -> void:
	t.begin("194 §1 · 休息点事件里有「铸炉」，排在神坛后、继续赶路前；选它进铸炉屏、休息那一份没动；铸过再来选项藏起；休息屏没有铸炉一栏")
	var c = NodeScreens._content()
	var rest: EventDef = c.events.get(&"rest_default", null)
	t.not_null(rest, "有默认休息事件")
	if rest == null:
		return
	var forge_at := _index_of(rest, "铸炉")
	t.check(forge_at > _index_of(rest, "神坛") and forge_at < _index_of(rest, "继续赶路"), "神坛后、继续赶路前（第 %d 项）" % forge_at)
	var opt := rest.options[forge_at] as EventOption
	t.check(opt.hide_when_locked, "用过就藏")
	t.check(not FileAccess.get_file_as_string("res://ui/game/rest_screen.gd").contains("open_forge"), "休息屏不再开铸炉")
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "forge194")
	var node := F175._rest_next_to_spawn(f, c, kit)
	t.check(node != null and f.step_to(node.id), "走上休息点")
	if node == null:
		Support.cleanup("forge194")
		return
	t.eq(f.screen, GameFlow.Screen.EVENT, "先是休息点的事件")
	t.check(_open_labels(f).any(func(l): return l.begins_with("铸炉")), "选项里有铸炉（%s）" % str(_open_labels(f)))
	t.check(f.choose_event(forge_at), "选铸炉")
	t.eq(f.screen, GameFlow.Screen.FORGE, "→ 铸炉屏")
	t.check(not NodeEvents.rest_part_used(node, &"rest") and not node.is_visited(), "休息那一份没用、点不灰")
	var picks: Array = []
	for id in [&"knife", &"antler", &"cleaver"]:
		var inst := F175._inst(c.items, id)
		f.run.storage.admit(inst)
		picks.append(inst)
	t.not_null(f.forge_token(node, picks[0], picks[1], picks[2], [f.run.storage, f.run.storage, f.run.storage]), "铸成")
	t.check(f.leave_forge(), "离开铸炉")
	t.check(f.can_reopen() and f.reopen_node(), "站着再打开休息点")
	t.eq(f.screen, GameFlow.Screen.EVENT, "→ 休息点的事件")
	var labels := _open_labels(f)
	t.check(not labels.any(func(l): return l.begins_with("铸炉")) and labels.any(func(l): return l.begins_with("歇一会儿")), "铸过：铸炉藏了、歇一会儿还在（%s）" % str(labels))
	Support.cleanup("forge194")


static func run_slot_summary(t: TestCase) -> void:
	t.begin("194 §2 · 逐槽三行：时机槽的金属武器「出手时 / 造成 / 6 秒」，效果槽的骨制品「流血 / 嗜血的」，数值槽稀有度 2 的金属「×2 / ×1.25」；两槽满按 default 行试算")
	var db := F175._db()
	var timing := "\n".join(Forge.slot_summary(&"timing", db.get_def(&"knife")))
	t.check(timing.contains("出手时") and timing.contains("造成") and timing.contains("6 秒"), "时机：%s" % timing.replace("\n", " / "))
	t.eq(Forge.slot_summary(&"timing", db.get_def(&"knife")).size(), 3, "三行")
	var bone := "\n".join(Forge.slot_summary(&"timing", db.get_def(&"antler")))
	t.check(bone.contains("方向：受到") and not bone.contains("不分方向"), "骨的受伤时分方向：%s" % bone.replace("\n", " / "))
	var effect := "\n".join(Forge.slot_summary(&"effect", db.get_def(&"antler")))
	t.check(effect.contains("流血") and effect.contains("嗜血的"), "效果：%s" % effect.replace("\n", " / "))
	t.check(effect.contains("阶：基础"), "稀有度 1：基础阶")
	var high := "\n".join(Forge.slot_summary(&"effect", db.get_def(&"bone_dice")))
	t.check(high.contains("升阶：没有变化"), "骨没有升阶那一档：%s" % high.replace("\n", " / "))
	var value := "\n".join(Forge.slot_summary(&"value", db.get_def(&"brass_gear")))
	t.check(value.contains("×2") and value.contains("×1.25") and value.contains("合计 ×2.5"), "数值：%s" % value.replace("\n", " / "))
	t.eq(Forge.slot_summary(&"timing", null), [] as Array[String], "空槽：没有字")
	var g := Forge.forge(db.get_def(&"knife"), db.get_def(&"antler"), null, true)
	t.check(not g.is_empty() and String(g["from"][2]) == "", "试算：空槽按 default 补齐")
	t.check(Forge.forge(db.get_def(&"knife"), db.get_def(&"antler"), null).is_empty(), "不是试算：缺一件铸不出")


static func frame_forge_screen(t: TestCase, root: Window) -> void:
	t.begin("194 §2 · 铸炉屏：放进一件槽下立刻写三行、拿走清空；两槽满写「按空槽的默认行：将铸出 …」，三槽满换回「将铸出」")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	Support.cleanup("forge194_ui")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = String(Support.paths("forge194_ui")["run"])
	game.meta_path = String(Support.paths("forge194_ui")["meta"])
	game.settings_path = String(Support.paths("forge194_ui")["settings"])
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	var node := F175._rest_next_to_spawn(flow, c, kit)
	t.check(node != null and flow.step_to(node.id) and flow.open_forge(node), "走上休息点、开铸炉")
	var screen = game.overlay()
	if screen == null or not screen.has_method("summary_text"):
		t.check(false, "叠层是铸炉屏")
		game.queue_free()
		Support.cleanup("forge194_ui")
		return
	var uids: Array[int] = []
	for id in [&"knife", &"antler", &"brass_gear"]:
		var inst := F175._inst(c.items, id)
		flow.run.storage.admit(inst)
		uids.append(inst.uid)
	t.eq(screen.summary_text(0), "", "空槽没字")
	t.check(screen.put_in(0, uids[0]), "放进时机")
	t.check(screen.summary_text(0).contains("出手时"), "时机槽下立刻有字：%s" % screen.summary_text(0).replace("\n", " / "))
	t.eq(screen.guess_text(), "", "一槽：不试算")
	t.check(screen.put_in(1, uids[1]), "放进效果")
	t.check(screen.summary_text(1).contains("嗜血的"), "效果槽下：%s" % screen.summary_text(1).replace("\n", " / "))
	t.check(screen.guess_text().contains("默认") and screen.guess_text().contains("将铸出"), "两槽满：试算（%s）" % screen.guess_text())
	t.check(screen.put_in(2, uids[2]), "放进数值")
	t.eq(screen.guess_text(), "", "三槽满：不再试算")
	t.check(screen.preview_text().contains("将铸出"), "三槽满：正式预览")
	t.check(screen.take_back(0, uids[0]), "拿走时机")
	t.eq(screen.summary_text(0), "", "拿走就清")
	game.queue_free()
	Support.cleanup("forge194_ui")
