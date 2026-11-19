## 战前的两列读数、免疫简报、负重惩罚，以及空手与缺少待战的区别。
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const SCREEN := preload("res://ui/game/prebattle_screen.gd")


static func frame_briefs(t: TestCase, root: Window) -> void:
	t.begin("战前对照 · 四签同序、免疫展开、负重跨档、待战失效")
	var c := NodeScreens._content()
	var flow := Support.flow(c, "encounter_briefs")
	var run := flow.begin(c.chapter, NodeScreens._kit(c), 1)
	run.encumbrance = EncumbranceRules.standard()
	var character := CharacterDef.new()
	character.weight_capacity = 1
	run.set_character(character)
	var content := {"enemy": "clockwork_sentry", "board": [3, 3]}
	run.events.pending_battle = {"node": run.current_node().id if run.current_node() != null else -1, "content": content, "type": "battle"}
	var screen := SCREEN.new()
	screen.flow = flow
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open({"content": content})
	var order: Array[StringName] = [StatsStrip.HP, StatsStrip.VIGOR, StatsStrip.STAMINA, StatsStrip.DPS]
	t.eq(screen.enemy_strip().shown(), order, "敌方生命、耐力、耗气、DPS")
	t.eq(screen.player_strip().shown(), order, "己方同序")
	var key = screen._trait_key
	var spec := run.events.pending_battle_spec()
	t.check(spec.immune_buffs.has(&"bleed"), "实际机关哨卫免疫流血")
	var lines := StatsStrip.specials_of(spec)
	t.check(key.visible and key.text.contains(lines[0]) and key.text.contains(str(lines.size() - 1)), "简报列首项和余项数")
	key.pressed.emit()
	t.check(key.sheet.visible and key.body.text == "\n".join(lines), "展开读全体能力")
	key.sheet.hide()
	var level := run.encumbrance_level()
	t.check(level > 0 and screen._player_plate_node.sub_label.text.contains(run.encumbrance.name_of(level)), "当前装备触发负重惩罚")
	var effects := run.encumbrance.effect_text(level)
	t.check(not effects.is_empty() and screen._player_plate_node.sub_label.tooltip_text.contains(effects), "副行显示档位，完整影响可读")
	run.board.clear()
	t.eq(screen._player_plate_node.sub_label.text, UiText.t("battle.side_mine"), "移走装备，惩罚简报立即收起")
	t.check(not screen._start_btn.disabled and screen._why.text == UiText.t("pre.no_attacker"), "空手可开战")
	run.events.pending_battle["content"] = {"enemy": "ragpicker"}
	screen._refresh()
	t.check(not key.visible and screen._enemy_plate_node.sub_label.visible, "普通拾破烂的没有能力，保持名牌紧凑")
	run.events.pending_battle = {}
	screen._refresh()
	t.check(not key.visible and screen._enemy_plate_node.sub_label.visible, "没有能力时恢复阵营名")
	t.check(screen._start_btn.disabled and screen._why.text == UiText.t("pre.no_battle"), "没有待战时给禁用原因")
	screen.free()
	Support.cleanup("encounter_briefs")
