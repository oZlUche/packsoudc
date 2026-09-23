## 常规事件（M6-1 的最小版，6.5）：三种占位结果（给东西 / 回体力 / 什么也没发生），一句话，继续。
extends GameScreen


func open(payload: Dictionary) -> void:
	var outcome: StringName = payload.get("outcome", &"story")
	var detail: Dictionary = payload.get("detail", {})
	var panel := _centered_panel(Vector2(480, 0))
	var col := _vbox(12)
	panel.add_child(col)
	col.add_child(_label("事件", 18, UiPalette.FG))
	var text := ""
	match outcome:
		&"item":
			var names: Array[String] = []
			for id in detail.get("items", []):
				var def := flow.items.get_def(StringName(String(id)))
				names.append(def.display_name if def != null else String(id))
			text = "在角落里翻出了：%s。已放进暂存区" % "、".join(names) if not names.is_empty() else "翻了半天什么都没有"
		&"restore":
			text = "歇了口气，体力 +%d" % int(detail.get("restored", 0))
		_:
			text = "这里曾经发生过什么，现在只剩下痕迹（占位：常规事件的内容还没写）"
	col.add_child(_wrapped(text, 14, UiPalette.FG, 440))
	col.add_child(_button("继续", proceed, 14))


func proceed() -> void:
	flow.resume()
