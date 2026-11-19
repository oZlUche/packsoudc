## 数值在常见位数内变化时，顶栏保持热区和相邻读数的位置。
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const MapScreen := preload("res://ui/game/map_screen.gd")


static func frame_stable_readouts(t: TestCase, root: Window) -> void:
	t.begin("顶栏分槽：五心及布鲁图斯八心、四位钱包与三位信力不推移按钮；两行状态不压日晷")
	var content := CS._content()
	for character in [&"andreus", &"marcus", &"brutus"]:
		var run := CS._start(content, CS._character(content, character))
		run.faith_defs = FaithDef.load_all()
		CS.Support.activate(run, &"charm_sun")
		var map := MapScreen.new()
		map._run = run
		map.flow = GameFlow.new()
		root.add_child(map)
		map._build_parts()
		map._build_drawer()
		map._refresh_skills()
		run.meta_buffs.append(&"survey_supplies")
		run.travel.erosion = ErosionField.new()
		run.travel.erosion.setup(run, ErosionMechanic.new())
		var host := HudHost.new()
		root.add_child(host)
		host.size = Vector2(1600, 1000)
		var layout := HudLayout.default_for("map")
		layout.entry_of(&"skills")["visible"] = true
		host.setup(run, map, layout)
		host.arrange()
		var skills := host.widget(&"skills") as HudPartWidget
		t.eq(skills.visible, not run.skills.active_skills().is_empty(), "%s：实际主动技能有槽，被动不占位" % character)
		var slots: Array[StringName] = [&"vitality", &"wallet", &"faith", &"countdown", &"dev_drawer", &"buffs", &"erosion"]
		if skills.visible:
			slots.append(&"skills")
		var before := {}
		for id in slots:
			before[id] = host.widget(id).get_rect()
		var maximum := run.vitality.maximum
		t.eq(maximum, {&"andreus": 3, &"marcus": 5, &"brutus": 8}[character], "%s：实测角色体力上限" % character)
		run.vitality.spend(1, &"test")
		run.wallet.earn(1250 - run.wallet.balance)
		run.faith_power.add_points(&"sun", 248 - run.faith_power.points_of(&"sun"))
		host.arrange()
		for id in slots:
			t.eq(host.widget(id).get_rect(), before[id], "%s 的 %s：高低读数同一槽" % [character, id])
		var stone := host.widget(&"countdown").get_rect()
		t.eq(stone.size.x, float(UiTheme.art_cached("hud/topbar/dial_base").get_width()), "留出整块日晷及阴影宽")
		for id in [&"vitality", &"wallet", &"faith", &"buffs", &"erosion"]:
			t.check(host.widget(id).get_rect().end.x <= stone.position.x - HudHost.GAP, "%s：%s 在日晷左侧" % [character, id])
		t.check(host.widget(&"dev_drawer").position.x >= stone.end.x + HudHost.GAP, "%s：调试台在日晷右侧" % character)
		if skills.visible:
			t.check(skills.position.x >= stone.end.x + HudHost.GAP, "主动技能与晷盘分开")
		var arrow := map._drawer.arrow
		t.check(not map._drawer.is_open() and arrow.mouse_filter == Control.MOUSE_FILTER_STOP, "开发箭头接鼠标")
		arrow.pressed.emit()
		t.check(map._drawer.is_open(), "点按箭头打开抽屉")
		# 钱超过四位时读数应按实长放大，缩窄时整件换行。
		var standard_width := host.widget(&"wallet").size.x
		run.wallet.earn(1234567)
		host.size.x = 1000
		host.arrange()
		t.check(host.widget(&"wallet").size.x > standard_width, "超出四位的金币仍完整")
		var pivot: Vector2 = host.widget(&"hud_bar").call("dial_pivot")
		t.eq(pivot.y, 6.0 + host.bar_height() - 100.0, "多行时日晷相对直栏下沿的位置稳定")
		t.eq(host.overhang(), host.bar_height() + 24.0, "多行时告示仍避开半圆外沿")
		stone = host.widget(&"countdown").get_rect()
		for id in [&"vitality", &"wallet", &"faith", &"buffs", &"erosion"]:
			var rect := host.widget(id).get_rect()
			var texture_top := pivot.y - float(HudHost.HudBarScript.skin()["dial"]["pivot"][1])
			t.check(rect.end.x + HudHost.GAP <= stone.position.x or rect.end.y + HudHost.GAP <= texture_top, "窄布局的 %s 离整块盘与阴影至少一个间隙" % id)
		host.queue_free()
		run.dispose()
		map.queue_free()
