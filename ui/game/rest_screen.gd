## 休息区（M6-1 的最小版，7.1）：回多少体力由节点规则定，这里只说一句。
extends GameScreen


func open(payload: Dictionary) -> void:
	var restored := int(payload.get("restored", 0))
	var v := flow.run.vitality
	var panel := _centered_panel(Vector2(480, 0))
	var col := _vbox(12)
	panel.add_child(col)
	col.add_child(_label("休息区", 18, UiPalette.FG))
	col.add_child(_wrapped("歇了一会儿。体力 +%d，现在 %d / %d%s" % [restored, v.current, v.maximum, "（本来就是满的）" if restored == 0 and v.is_full() else ""],
		14, UiPalette.FG, 440))
	col.add_child(_button("继续", proceed, 14, UiPalette.Tier.PRIMARY))


func proceed() -> void:
	flow.resume()


## 090：Esc = 继续
func escape() -> bool:
	proceed()
	return true
