## 336 W1（阵营与委托，报告 335 第五节）：地图左上角（顶端栏下面）的委托小牌 —— 带进这一局的委托各一行：
## 名字 + 这一步做到几 / 要几；这一局里整份做完写「已办成」。没带委托不显示。
## 摆在左上：右边那一条会把地图往左让（[HudHost]），悬停浮窗跟着节点走，两边不打架
extends HudWidget

## 名字最多几个字，长了截断加「…」：英文大字号下长名字会把小牌撑宽、进度被窗盖住（测试报告 v8.81–v8.82）
const NAME_MAX := 16


## 截短的名字（不超过 [constant NAME_MAX] 个字，含「…」）
static func short_name(n: String) -> String:
	return n if n.length() <= NAME_MAX else n.left(NAME_MAX - 1).strip_edges() + "…"


func title() -> String:
	return "委托"


func _mod() -> CommissionModule:
	return CommissionModule.of(run)


func watch() -> Array[Signal]:
	var mod := _mod()
	return [mod.progressed] as Array[Signal] if mod != null else [] as Array[Signal]


func text_of() -> String:
	var mod := _mod()
	if mod == null or not mod.is_active():
		return ""
	var out: PackedStringArray = []
	for row in mod.lines():
		var state := UiText.t("commission.state_done") if bool(row["finished"]) else UiText.t("commission.progress") % [int(row["done"]), int(row["need"])]
		out.append("%s　%s" % [short_name(String(row["name"])), state])
	return "\n".join(out)
