## 204（作者 2026-10-19「先加一些最常规最不容易出错的按钮点击、窗口关闭/打开音效」，待定按推荐）：
## 自动加载 `Audio` + cue 表 + 两个音量；按钮音一处钩子（meta `sfx`），叠层与浮窗开 / 关
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const SAVE := "user://test_audio204_run.json"
const META := "user://test_audio204_meta.json"
const SETTINGS := "user://test_audio204_settings.json"
const TMP_CUES := "user://test_audio204_cues.json"


static func _audio(root: Node) -> AudioHub:
	var a := root.get_node_or_null("/root/Audio") as AudioHub
	return a


## 清掉冷却与记录：用例之间互不挡
static func _fresh(audio: AudioHub) -> void:
	audio._last_at.clear()
	audio.recent.clear()


static func run_cue_table(t: TestCase) -> void:
	t.begin("204 · cue 表：三个界面 cue 都在、字段齐、文件都在且是 .ogg；配乐表先空；不认识的字段、坏类型报出来")
	var table := CueTable.load_default()
	t.eq(table.errors, [], "默认表没有问题")
	for name in [&"ui.press", &"ui.open", &"ui.close"]:
		var c := table.cue(name)
		t.check(not c.is_empty(), "%s 在表里" % name)
		var files := table.files_of(name)
		t.check(not files.is_empty(), "%s 有素材" % name)
		for f in files:
			t.check(f.ends_with(".ogg") and ResourceLoader.exists(f), "%s 的 %s 在、是 .ogg" % [name, f])
	t.check(table.files_of(&"ui.press").size() >= 2, "按钮音有几个变体")
	t.eq(table.music, {}, "配乐表先空着")
	t.eq(table.cue(&"nope"), {}, "不在表里的是空")
	var f := FileAccess.open(TMP_CUES, FileAccess.WRITE)
	f.store_string(JSON.stringify({"a.b": {"files": ["x.ogg"], "loud": 3}, "a.c": {"files": "x.ogg", "volume_db": "大"}}))
	f.close()
	var bad := CueTable.new()
	bad.load_files(TMP_CUES, "user://test_audio204_none.json")
	t.eq(bad.errors.size(), 3, "不认识的字段、files 不是数组、音量不是数：都报（%s）" % [bad.errors])
	t.eq(float(bad.cue(&"a.b")["cooldown"]), CueTable.DEFAULT_COOLDOWN, "没写的冷却用默认")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_CUES))


static func run_autoload(t: TestCase) -> void:
	t.begin("204 · 自动加载：project.godot 里有 Audio；cue 表的纯类住 core、不认识 ui")
	t.eq(String(ProjectSettings.get_setting("autoload/Audio", "")), "*res://ui/audio.gd", "Audio = ui/audio.gd")
	var src := FileAccess.get_file_as_string("res://core/audio/cue_table.gd")
	t.check(src.contains("extends RefCounted") and not src.contains("res://ui/"), "CueTable 是 RefCounted、不碰 ui")


static func run_settings(t: TestCase) -> void:
	t.begin("204 · 设置：音效 / 音乐音量存取往返，缺键用默认（0.8 / 0.6），越界夹到 0～1")
	var s := GameSettings.new()
	t.eq(s.sfx_volume, 0.8, "音效默认 80%")
	t.eq(s.music_volume, 0.6, "音乐默认 60%")
	s.sfx_volume = 0.3
	s.music_volume = 0.0
	var back := GameSettings.from_dict(s.to_dict())
	t.eq(back.sfx_volume, 0.3, "音效往返")
	t.eq(back.music_volume, 0.0, "音乐往返")
	var d := s.to_dict()
	d.erase("sfx_volume")
	d.erase("music_volume")
	t.eq(GameSettings.from_dict(d).sfx_volume, 0.8, "缺键用默认")
	d["sfx_volume"] = 3.0
	d["music_volume"] = -1.0
	var clamped := GameSettings.from_dict(d)
	t.eq(clamped.sfx_volume, 1.0, "大了夹到 1")
	t.eq(clamped.music_volume, 0.0, "小了夹到 0")


static func frame_apply_and_buttons(t: TestCase, root: Window) -> void:
	t.begin("204 · 音量套到总线；按钮进树就响 ui.press，meta 空串不响，同一下只响一次；不认识的 cue 静默记下")
	var audio := _audio(root)
	t.not_null(audio, "Audio 是自动加载，跑什么都在")
	if audio == null:
		return
	var s := GameSettings.new()
	s.sfx_volume = 0.5
	audio.apply_settings(s)
	var sfx := AudioServer.get_bus_index(&"SFX")
	t.check(sfx >= 0 and AudioServer.get_bus_index(&"Music") >= 0, "两条总线")
	t.check(absf(AudioServer.get_bus_volume_db(sfx) - linear_to_db(0.5)) < 0.001 and not AudioServer.is_bus_mute(sfx), "音效 50%% = %.2f dB" % linear_to_db(0.5))
	s.sfx_volume = 0.0
	audio.apply_settings(s)
	t.check(AudioServer.is_bus_mute(sfx), "0 = 静音")
	audio.apply_settings(GameSettings.new())
	_fresh(audio)
	var b := Button.new()
	root.add_child(b)
	b.pressed.emit()
	t.eq(audio.recent, [&"ui.press"], "按一下：ui.press")
	b.pressed.emit()
	t.eq(audio.recent.size(), 1, "同一下连发两次只响一次")
	_fresh(audio)
	b.set_meta(&"sfx", &"")
	b.pressed.emit()
	t.eq(audio.recent, [], "meta 空串：不响")
	b.set_meta(&"sfx", &"ui.open")
	b.pressed.emit()
	t.eq(audio.recent, [&"ui.open"], "meta 给了专属 cue 就播它")
	root.remove_child(b)
	root.add_child(b)     # 挪了一下再进树：不重复接
	t.eq(b.pressed.get_connections().size(), 1, "再进树也只接一次")
	b.free()
	audio.play_cue(&"nope.never")
	t.check(audio.missing.has(&"nope.never"), "不认识的 cue 记进 missing、不报错")
	_fresh(audio)


static func frame_floating_window(t: TestCase, root: Window) -> void:
	t.begin("204 · 浮窗：进树响 ui.open，出树响 ui.close")
	var audio := _audio(root)
	if audio == null:
		t.check(false, "没有 Audio")
		return
	_fresh(audio)
	var win := FloatingWindow.new()
	win.setup("test_audio204", "测试")
	root.add_child(win)
	t.eq(audio.recent, [&"ui.open"], "开：ui.open")
	root.remove_child(win)
	t.eq(audio.recent, [&"ui.open", &"ui.close"], "关：ui.close")
	win.free()
	_fresh(audio)


static func frame_overlays(t: TestCase, root: Window) -> void:
	t.begin("204 · 叠层：开 = ui.open，收起 = ui.close，恢复 = ui.open，叠层换叠层只响 ui.open，回底屏撤叠层 = ui.close；底屏换底屏不响")
	var audio := _audio(root)
	if audio == null:
		t.check(false, "没有 Audio")
		return
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)
	var game = load(GAME).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	game.settings_path = SETTINGS
	root.add_child(game)
	var flow: GameFlow = game.flow
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	_fresh(audio)
	t.check(setup.depart(), "出发")
	game.base().pick_spawn(flow.run.map.entry_ids[0])
	t.eq(_window_cues(audio), [], "底屏换底屏（开局 → 地图）不响")
	var steps := [
		[GameFlow.Screen.SHOP, {}, [&"ui.open"], "开商店"],
		[GameFlow.Screen.MAP, {"minimized": true}, [&"ui.close"], "收起"],
		[GameFlow.Screen.SHOP, {"restore": true}, [&"ui.open"], "恢复"],
		[GameFlow.Screen.ALTAR, {}, [&"ui.open"], "叠层换叠层"],
		[GameFlow.Screen.MAP, {}, [&"ui.close"], "回地图"],
	]
	for st in steps:
		_fresh(audio)
		game._switch_screen(st[0], st[1])
		t.eq(_window_cues(audio), st[2], String(st[3]))
	game.queue_free()
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)
	_fresh(audio)


static func _window_cues(audio: AudioHub) -> Array:
	return (audio.recent as Array).filter(func(c: StringName) -> bool: return c == &"ui.open" or c == &"ui.close")
