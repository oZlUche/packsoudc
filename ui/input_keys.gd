## 玩家能改的键（154 补充一）：动作走 Godot 的 InputMap，默认键写在 `project.godot` 的 `[input]` 里，
## 玩家改过的存在 [member GameSettings.key_bindings]，启动时（导演 `_ready`）[method apply] 盖上去。
##
## 现在三个动作：`confirm`（确认，默认回车 / 小键盘回车 / 空格；宝箱屏按住开锁）、`cancel`（取消，默认 Esc；
## 只是先定义，各处的 Esc 判断还没换过来）、`toggle_fullscreen`（172：窗口 ↔ 全屏，默认 F11）。改键界面等下一个要改键的动作出现再做（补充一待定 1 = A），手柄不绑（待定 2 = A）。
class_name InputKeys
extends RefCounted

const CONFIRM := &"confirm"
const CANCEL := &"cancel"
## 172：窗口 ↔ 全屏，默认 F11（待定 2 A）
const TOGGLE_FULLSCREEN := &"toggle_fullscreen"
## 玩家能改的动作
const ACTIONS: Array[StringName] = [CONFIRM, CANCEL, TOGGLE_FULLSCREEN]


## 先回到 `project.godot` 里的默认，再把设置里改过的动作整组换掉（一个动作写了就整组替换，不是追加）。
## 键码认不出来的跳过；一个都认不出来的动作留默认
static func apply(settings: GameSettings) -> void:
	InputMap.load_from_project_settings()
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
			key.keycode = GameSettings.keycode_of(code)
			events.append(key)
		if events.is_empty():
			continue
		InputMap.action_erase_events(name)
		for e in events:
			InputMap.action_add_event(name, e)

