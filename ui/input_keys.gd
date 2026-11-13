## 玩家能改的键（154 补充一）：动作走 Godot 的 InputMap，默认键写在 `project.godot` 的 `[input]` 里，
## 玩家改过的存在 [member GameSettings.key_bindings]，启动时（导演 `_ready`）[method apply] 盖上去。
##
## 现在六个动作：`confirm`（确认，默认回车 / 小键盘回车 / 空格；宝箱屏按住开锁）、`cancel`（取消，默认 Esc；
## 只是先定义，各处的 Esc 判断还没换过来）、`toggle_fullscreen`（172：窗口 ↔ 全屏，默认 F11）。改键界面等下一个要改键的动作出现再做（补充一待定 1 = A），手柄不绑（待定 2 = A）。
## 284 §3.5（作者 11-07 14:57：按键引用而非写死）：`rotate_item`（拖着转向，默认 R）、`hide_tip`（按住藏说明，默认 Alt）、`whole_bag`（按住点包里的 = 点整个包，默认 Ctrl，mac 加 Cmd）。
## 这三个的默认键登记在代码里（[constant CODE_DEFAULTS]，[method ensure]），不写进 `project.godot`；台词里写 `[key=动作]`，显示时换成现在绑的键名（[KeyNames]）
class_name InputKeys
extends RefCounted

const CONFIRM := &"confirm"
const CANCEL := &"cancel"
## 172：窗口 ↔ 全屏，默认 F11（待定 2 A）
const TOGGLE_FULLSCREEN := &"toggle_fullscreen"
## 284 §3.5：拖着时转向
const ROTATE_ITEM := &"rotate_item"
## 284 §3.5：按住时道具说明先藏起来
const HIDE_TIP := &"hide_tip"
## 284 §3.5：按住时点包里的道具 = 点这个包（274）
const WHOLE_BAG := &"whole_bag"
## 切片 v6.14 D：地图屏看全图（原来写死 F）
const MAP_FIT := &"map_fit"
## 玩家能改的动作
const ACTIONS: Array[StringName] = [CONFIRM, CANCEL, TOGGLE_FULLSCREEN, ROTATE_ITEM, HIDE_TIP, WHOLE_BAG, MAP_FIT]
## 284 §3.5：代码里登记默认键的动作（动作 → 键码）
const CODE_DEFAULTS := {ROTATE_ITEM: [KEY_R], HIDE_TIP: [KEY_ALT], WHOLE_BAG: [KEY_CTRL, KEY_META], MAP_FIT: [KEY_F]}


## 284 §3.5：[constant CODE_DEFAULTS] 里的动作没登记就按默认键登记（可以反复叫）
static func ensure() -> void:
	for action in CODE_DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code in CODE_DEFAULTS[action]:
			var key := InputEventKey.new()
			key.keycode = code as Key
			InputMap.action_add_event(action, key)


## 这个动作现在绑的键码（键盘的；没绑空）
static func keys_of(action: StringName) -> Array[Key]:
	ensure()
	var out: Array[Key] = []
	if not InputMap.has_action(action):
		return out
	for e in InputMap.action_get_events(action):
		var k := e as InputEventKey
		if k != null:
			out.append(k.keycode if k.keycode != KEY_NONE else k.physical_keycode)
	return out


## 这个动作绑的键有没有一个正按着
static func held(action: StringName) -> bool:
	for code in keys_of(action):
		if Input.is_key_pressed(code):
			return true
	return false


## 鼠标点下那一刻这个动作的键按没按着：修饰键看这次点击自带的标记，别的键看现在的键盘
static func held_with(event: InputEventWithModifiers, action: StringName) -> bool:
	for code in keys_of(action):
		var on := false
		match code:
			KEY_CTRL:
				on = event.ctrl_pressed
			KEY_META:
				on = event.meta_pressed
			KEY_ALT:
				on = event.alt_pressed
			KEY_SHIFT:
				on = event.shift_pressed
			_:
				on = Input.is_key_pressed(code)
		if on:
			return true
	return false


## 这个键事件是不是这个动作的键（按下、松开都算）
static func is_key_of(event: InputEventKey, action: StringName) -> bool:
	if event == null:
		return false
	var code := event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	return keys_of(action).has(code)


## 先回到 `project.godot` 里的默认，再把设置里改过的动作整组换掉（一个动作写了就整组替换，不是追加）。
## 键码认不出来的跳过；一个都认不出来的动作留默认
static func apply(settings: GameSettings) -> void:
	InputMap.load_from_project_settings()
	ensure()     # 284：代码里登记的那几个回到默认
	if settings == null:
		return
	for action in settings.key_bindings:
		var name := StringName(String(action))
		if not ACTIONS.has(name) or not InputMap.has_action(name):
			continue
		var events: Array[InputEventKey] = []
		for code in settings.key_bindings[action]:
			if GameSettings.keycode_of(code) <= 0:
				continue
			var key := InputEventKey.new()
			key.keycode = GameSettings.keycode_of(code) as Key
			events.append(key)
		if events.is_empty():
			continue
		InputMap.action_erase_events(name)
		for e in events:
			InputMap.action_add_event(name, e)

