## Buff 制作器（085）：字段联动（可叠层 ⇄ 上限 / 永续）、校验走导入器、保存往返、界面语言跟设置走。
##
## 全是 `frame_` 用例：编辑器要进场景树才活得起来。往盘上写的探针 buff 用完收回。
extends RefCounted

const SCENE := "res://ui/buff_editor/buff_editor.tscn"
const PROBE := "zz_buff_probe"


static func _make(root: Window) -> Node:
	var ed: Node = load(SCENE).instantiate()
	root.add_child(ed)
	return ed


static func _remove(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


static func _cleanup_probe() -> void:
	_remove(ContentPaths.authoring_file("buffs", PROBE))
	_remove(ContentPaths.asset_file("buffs", PROBE))


static func run_ui_text(t: TestCase) -> void:
	t.begin("UiText · 两种语言与设置往返")
	var before := UiText.lang
	UiText.lang = "zh"
	t.eq(UiText.t("menu.new_run"), "新的一局", "中文")
	UiText.lang = "en"
	t.eq(UiText.t("menu.new_run"), "New run", "英文")
	t.eq(UiText.t("no.such.key"), "no.such.key", "没有的键原样返回")
	t.eq(UiText.next_lang("zh"), "en", "zh → en")
	t.eq(UiText.next_lang("en"), "zh", "en → zh 绕回来")
	t.eq(UiText.next_lang("??"), "zh", "不认识的值回到第一种")
	for key in UiText.TEXT:
		var entry: Dictionary = UiText.TEXT[key]
		t.check(entry.has("zh") and entry.has("en"), "%s 两种语言都有" % key)

	var s := GameSettings.new()
	s.language = "en"
	var back := GameSettings.from_dict(s.to_dict())
	t.eq(back.language, "en", "language 存取往返")
	var bad := GameSettings.from_dict({"version": GameSettings.SAVE_VERSION, "language": "fr"})
	t.eq(bad.language, "zh", "不认识的语言回落中文")
	UiText.apply(back)
	t.eq(UiText.lang, "en", "apply 读设置")
	UiText.lang = before


static func frame_run_fields(t: TestCase, root: Window) -> void:
	t.begin("Buff 制作器 · 叠层与永续的联动")
	_cleanup_probe()
	var before := UiText.lang
	UiText.lang = "zh"
	var ed := _make(root)
	ed._new_buff()
	var d: BuffDef = ed.def()
	t.eq(d.max_stacks, 0, "新建默认不限层")
	t.check(d.is_stackable() and d.is_permanent(), "新建：可叠层 → 永续")
	t.check(ed._stackable.button_pressed, "可叠层勾着")
	t.check(ed._permanent.disabled, "可叠层时永续锁死不能取消")
	t.check(not ed._seconds.editable, "可叠层时秒数不可编辑")
	t.check(ed.summary_text().contains("不限层"), "摘要写着不限层")

	ed.set_cap(3)
	t.eq(d.max_stacks, 3, "设上限 3")
	t.check(d.is_stackable() and d.is_permanent(), "有上限仍是可叠层、仍永续")
	t.check(ed.summary_text().contains("至多 3 层"), "摘要写着至多 3 层")

	ed.set_stackable(false)
	t.eq(d.max_stacks, 1, "取消可叠层 → 上限 1")
	t.check(d.is_permanent(), "不可叠层、没填时长 → 仍永续")
	t.check(not ed._permanent.disabled, "不可叠层时永续可以取消")
	ed.set_permanent(false)
	t.check(d.duration_sec > 0.0 and not d.is_permanent(), "取消永续给了一个默认时长")
	ed.set_seconds(8.0)
	t.eq(d.duration_sec, 8.0, "改秒数")
	t.check(ed._validate().ok(), "不可叠层 + 时长：导入器放行")
	t.check(ed.summary_text().contains("8.0"), "摘要写着秒数")

	ed.set_stackable(true)
	t.eq(d.max_stacks, 0, "重新勾上可叠层 → 上限回到不限")
	t.eq(d.duration_sec, 0.0, "重新勾上可叠层 → 时长清掉")
	# 绕过界面直接塞时长：导入器要拦
	d.duration_sec = 3.0
	t.check(not ed._validate().ok(), "可叠层 + 时长：导入器报错")
	t.check(ed._status_text(ed._validate()).contains("✗"), "校验栏里有错")
	d.duration_sec = 0.0
	ed.set_seconds(5.0)
	t.eq(d.duration_sec, 0.0, "可叠层时改秒数不生效")

	ed.queue_free()
	UiText.lang = before


static func frame_run_save_roundtrip(t: TestCase, root: Window) -> void:
	t.begin("Buff 制作器 · 保存往返与 JSON 编辑器")
	_cleanup_probe()
	var ed := _make(root)
	ed._new_buff()
	var d: BuffDef = ed.def()
	d.id = StringName(PROBE)
	d.display_name = "探针"
	d.is_debuff = true
	ed.set_cap(4)
	ed._refresh()
	t.check(ed._json.text.contains("\"max_stacks\": 4"), "JSON 预览里有上限")
	ed._save()
	var json_path := ContentPaths.authoring_file("buffs", PROBE)
	var tres_path := ContentPaths.asset_file("buffs", PROBE)
	t.check(FileAccess.file_exists(json_path), "保存写了 JSON")
	t.check(FileAccess.file_exists(tres_path), "保存产出了 .tres")
	t.check(ed._ids.has(PROBE), "列表里出现了")
	t.check(not ed.has_unsaved_changes(), "保存后没有草稿")

	# 重新从盘上读：字段一致
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	t.check(parsed is Dictionary and int(parsed.get("max_stacks", -1)) == 4, "盘上 JSON 的 max_stacks 是 4")
	var loaded: BuffDef = load(tres_path)
	t.check(loaded != null and loaded.max_stacks == 4 and loaded.is_debuff, ".tres 读回来一致")

	# JSON 编辑器：改文字再套用
	ed._json.text = ed._json.text.replace("\"max_stacks\": 4", "\"max_stacks\": 0")
	ed._apply_json()
	t.eq(ed.def().max_stacks, 0, "套用 JSON 改了上限")
	t.check(ed.has_unsaved_changes(), "套用后有草稿")
	ed._on_discard()
	t.eq(ed.def().max_stacks, 4, "放弃改动回到盘上的样子")

	# 空 id 不许存
	ed._new_buff()
	ed.def().id = &""
	ed._save()
	t.check(not FileAccess.file_exists(ContentPaths.authoring_file("buffs", "")), "空 id 没写文件")

	ed.queue_free()
	_cleanup_probe()
	t.check(not FileAccess.file_exists(json_path), "探针收回")


static func frame_run_language(t: TestCase, root: Window) -> void:
	t.begin("Buff 制作器 · 界面语言跟设置走")
	var before := UiText.lang
	UiText.lang = "en"
	var ed := _make(root)
	# _ready 会按 user://settings.json 重设语言；测试环境没有这个文件 → 默认中文
	var expect_zh := not FileAccess.file_exists(GameSettings.DEFAULT_PATH)
	if expect_zh:
		t.check(ed._stackable.text == "可叠层", "没有设置文件 → 中文界面")
	UiText.lang = "en"
	var ed2 := _make(root)
	t.check(ed2 != null, "英文下也能建起来")
	ed.queue_free()
	ed2.queue_free()
	UiText.lang = before
