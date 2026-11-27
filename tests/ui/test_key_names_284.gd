## 284 §3.4 / 3.5（作者 2026-11-07 14:57）：三句通用提示（R 旋转 / Alt 藏说明 / Ctrl 整包拖）三位 NPC 都会说；
## 按键走动作（rotate_ccw / rotate_cw / hide_tip / whole_bag；作者 11-27 旋转由 R 改成 Q 逆 / E 顺），字里写 `[key=动作]`，显示时换成现在绑的键名，改键跟着变
extends RefCounted


static func run_actions(t: TestCase) -> void:
	t.begin("284 §3.5 · 旋转两个动作（作者 11-27：Q 逆时针 / E 顺时针）与藏说明、整包有默认键（Alt / Ctrl + Cmd），能改键（存档的 key_bindings 盖上去），键名跟着变；没绑写「未绑定」")
	InputKeys.apply(null)
	for a in [InputKeys.ROTATE_CCW, InputKeys.ROTATE_CW, InputKeys.HIDE_TIP, InputKeys.WHOLE_BAG]:
		t.check(InputMap.has_action(a) and InputKeys.ACTIONS.has(a), "%s 登记了、能改" % a)
	t.eq(InputKeys.keys_of(InputKeys.ROTATE_CCW), [KEY_Q] as Array[Key], "逆时针默认 Q")
	t.eq(InputKeys.keys_of(InputKeys.ROTATE_CW), [KEY_E] as Array[Key], "顺时针默认 E")
	t.eq(InputKeys.keys_of(InputKeys.HIDE_TIP), [KEY_ALT] as Array[Key], "藏说明默认 Alt")
	t.eq(InputKeys.keys_of(InputKeys.WHOLE_BAG), [KEY_CTRL, KEY_META] as Array[Key], "整包默认 Ctrl，mac 加 Cmd")
	t.eq(KeyNames.expand("按 [key=rotate_ccw] / [key=rotate_cw] 转"), "按 Q / E 转", "[key=rotate_ccw] → Q，[key=rotate_cw] → E")
	t.eq(KeyNames.expand("[key=hide_tip]"), OS.get_keycode_string(KEY_ALT), "[key=hide_tip] → Alt")
	t.eq(KeyNames.expand("没有记号"), "没有记号", "没有记号原样")
	t.eq(KeyNames.of(&"no_such_action"), UiText.t("key.unbound"), "没这个动作：未绑定")
	var r := InputEventKey.new()
	r.keycode = KEY_Q
	r.pressed = true
	t.check(InputKeys.is_key_of(r, InputKeys.ROTATE_CCW) and not InputKeys.is_key_of(r, InputKeys.ROTATE_CW), "按 Q 是逆时针、不是顺时针")
	var e := InputEventKey.new()
	e.keycode = KEY_E
	t.check(InputKeys.is_key_of(e, InputKeys.ROTATE_CW) and not InputKeys.is_key_of(e, InputKeys.ROTATE_CCW), "按 E 是顺时针")
	var old_r := InputEventKey.new()
	old_r.keycode = KEY_R
	t.check(not InputKeys.is_key_of(old_r, InputKeys.ROTATE_CW) and not InputKeys.is_key_of(old_r, InputKeys.ROTATE_CCW), "R 不再转")
	var click := InputEventMouseButton.new()
	click.ctrl_pressed = true
	t.check(InputKeys.held_with(click, InputKeys.WHOLE_BAG), "按着 Ctrl 点：整包")
	click.ctrl_pressed = false
	click.meta_pressed = true
	t.check(InputKeys.held_with(click, InputKeys.WHOLE_BAG), "按着 Cmd 点：也是整包")
	var settings := GameSettings.new()
	settings.key_bindings = {"rotate_ccw": ["T"], "whole_bag": ["Shift"]}
	InputKeys.apply(settings)
	t.eq(KeyNames.expand("[key=rotate_ccw]"), "T", "改成 T：键名跟着变")
	t.check(not InputKeys.is_key_of(r, InputKeys.ROTATE_CCW), "改键后 Q 不再转")
	t.eq(KeyNames.expand("[key=rotate_cw]"), "E", "没改的顺时针照旧 E")
	var shift_click := InputEventMouseButton.new()
	shift_click.shift_pressed = true
	t.check(InputKeys.held_with(shift_click, InputKeys.WHOLE_BAG) and not InputKeys.held_with(click, InputKeys.WHOLE_BAG), "整包改成 Shift：Shift 点算、Cmd 点不算")
	InputKeys.apply(null)
	t.eq(KeyNames.expand("[key=rotate_ccw]"), "Q", "回默认")


static func run_common_lines(t: TestCase) -> void:
	t.begin("284 §3.4 · 通用三句：一份 common，三位 NPC 的池子都并进来（别的 def 不并）；每句引用一个动作、不写死键")
	var common := NpcChatter.get_def(NpcDef.COMMON)
	t.not_null(common, "有通用句")
	if common == null:
		return
	t.eq(common.lines.size(), 3, "三句")
	var refs := {}
	for l in common.lines:
		t.check(String(l.id).begins_with(NpcDef.COMMON_PREFIX) and l.kind == NpcLine.GUIDE, "%s：id 前缀、指引" % l.id)
		for a in [InputKeys.ROTATE_CCW, InputKeys.ROTATE_CW, InputKeys.HIDE_TIP, InputKeys.WHOLE_BAG]:
			if l.text.contains("[key=%s]" % a) and String(l.texts.get("en", "")).contains("[key=%s]" % a):
				refs[a] = true
		var shown := KeyNames.expand(l.text)
		t.check(not shown.contains("[key="), "显示时换掉记号（%s）" % shown)
	t.eq(refs.size(), 4, "旋转一句引用 Q / E 两个动作，另两句各一个，中英都引用")
	var meta := MetaState.new()
	for id in NpcDef.IDS:
		var open := NpcChatter.open_lines(NpcChatter.get_def(id), meta)
		var ids := open.map(func(l: NpcLine) -> String: return String(l.id))
		t.check(ids.has("common_rotate") and ids.has("common_hide_tip") and ids.has("common_whole_bag"), "%s 的池子里有通用三句" % id)
	var fake := NpcDef.new()
	fake.id = &"fake"
	t.eq(NpcChatter.open_lines(fake, meta).size(), 0, "别的 def 不并")
