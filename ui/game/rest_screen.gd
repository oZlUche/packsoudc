## 休息区（M6-1 的最小版，7.1）：回多少体力由节点规则定，这里只说一句。
## 175 补充二（作者定）：休息点里有一座铸炉 —— 下面一栏「铸炉」，没铸过就能开铸炉屏（用一次就熄；走开再回来站着也能开）
extends GameScreen

var _node: MapNode = null
var _forge_btn: Button


func open(payload: Dictionary) -> void:
	_node = payload.get("node", null)
	var restored := int(payload.get("restored", 0))
	var v := flow.run.vitality
	var panel := _centered_panel(Vector2(480, 0))
	var col := _vbox(12)
	panel.add_child(col)
	_frame_title("休息区")     # 157：标题在石板框的标题条上
	col.add_child(_wrapped("歇了一会儿。体力 +%d，现在 %d / %d%s" % [restored, v.current, v.maximum, "（本来就是满的）" if restored == 0 and v.is_full() else ""],
		14, UiPalette.FG, 440))
	col.add_child(_label("铸炉", 14, UiPalette.FG))
	var used := NodeEvents.forge_used(_node)
	col.add_child(_wrapped("这座铸炉已经用过了。" if used else "把三件道具熔铸成一枚铸牌，拖到武器上就是附魔。每座只能铸一次。", 12, UiPalette.DIM, 440))
	var row := _hbox(8)
	_forge_btn = _button("开铸炉", open_forge, 13)
	_forge_btn.disabled = used or _node == null
	row.add_child(_forge_btn)
	row.add_child(_button("继续", proceed, 14, UiPalette.Tier.PRIMARY))
	col.add_child(row)


## 175 补充二：开这座休息点的铸炉
func open_forge() -> bool:
	return flow.open_forge(_node)


func proceed() -> void:
	flow.resume()


## 090：Esc = 继续
func escape() -> bool:
	proceed()
	return true
