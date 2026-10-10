## 151（作者定）：道具编辑器右栏的「战斗力」面板 —— 总分、逐项贡献、推荐稀有度与推荐价值、「采用」。
##
## 数全来自 [PowerEstimate]（纯函数，表单一改就重算）。每条规则一行：规则句 + 贡献（正绿负红），
## 悬浮看 V × T × C × K × L 各是多少；估不出来的效果标灰「未估」。推荐只是推荐：按「采用」才写进稀有度与价值（待定 4）。
## 样式全走主题变体与富文本（121 棘轮已满，不新增主题覆写）
class_name PowerPanel
extends VBoxContainer

## 按了「采用」
signal adopt_requested()

const WIDTH := 320.0

var estimate: PowerEstimate.Breakdown = null
var _head: Label
var _body: RichTextLabel
var _rec: Label
var _adopt: Button


func _init() -> void:
	_head = UiTheme.make_label("", 16, UiPalette.FG)
	add_child(_head)
	_body = UiTheme.rich_block(WIDTH, 12)
	add_child(_body)
	var row := HBoxContainer.new()
	_rec = UiTheme.make_label("", 13, UiPalette.STAMINA)
	_rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_rec)
	_adopt = UiTheme.make_button("采用", func(): adopt_requested.emit(), UiTheme.TIER_PLAIN, 13)
	_adopt.tooltip_text = "把推荐的稀有度与价值写进道具（不按就不动）"
	row.add_child(_adopt)
	add_child(row)


func show_estimate(b: PowerEstimate.Breakdown) -> void:
	estimate = b
	_head.text = "战斗力 %.1f　（默认 %.1f，占 %d 格）" % [b.power, b.default_power, b.cells]
	var lines: Array[String] = []
	lines.append("基础（直接伤害）%s　%.1f 次/秒" % [_signed(b.base), b.hz])
	for r in b.rules:
		var tip := "T %.2f/秒 × C %.2f × K %.2f × L %.2f" % [r["rate"], r["cost"], r["cond"], r["cap"]]
		var what := String(r["text"]) if String(r["text"]) != "" else "规则 %d" % (int(r["index"]) + 1)
		var parts: Array[String] = []
		for e in r["effects"]:
			if bool(e["unestimated"]):
				parts.append("[color=#%s]%s 未估[/color]" % [UiPalette.DIM.to_html(false), e["type"]])
			else:
				parts.append("%s V %+.1f" % [e["type"], e["value"]])
		lines.append("[hint=%s]规则 %d %s[/hint]　%s\n　[color=#%s]%s　%s[/color]" % [
			tip, int(r["index"]) + 1, what, _signed(float(r["value"])), UiPalette.DIM.to_html(false), "，".join(parts), tip])
	lines.append("负重 %d：× %.2f" % [b.weight, b.weight_factor])
	lines.append("预算比 %.2f（战斗力 ÷ 默认）" % b.ratio)
	_body.text = "\n".join(lines)
	if b.rarity >= 0:
		_rec.text = "推荐：%s　价值 %d" % [ItemTooltip.rarity_name(b.rarity), b.value]
		_adopt.disabled = false
	else:
		_rec.text = "非武器：只看分数（推荐稀有度以后有数据再定）"
		_adopt.disabled = true


## 正绿负红的一个数
static func _signed(v: float) -> String:
	var col := UiPalette.HEAL if v > 0.0 else (UiPalette.HP if v < 0.0 else UiPalette.DIM)
	return "[color=#%s]%+.1f[/color]" % [col.to_html(false), v]


func text() -> String:
	return _head.text + "\n" + _body.get_parsed_text() + "\n" + _rec.text
