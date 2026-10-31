## 选人页改版 B（作者 2026-10-31 11:56）：角色卡头像右边的铭牌 —— 基地小木牌底（[constant UiTheme.PANEL_HOME_PLAQUE_SMALL]，浅底墨字），
## 名字（粗体）→ 一道细线 → 两列网格，每格一枚火漆印 + 粗体数，项名只在悬停里（补充一 13:20「图像能说明的不加文字」）。不再写「角色」和角色说明。
## 生命 / 耐力 / 耐力回复 / 体力各有专属火漆（`stats_strip/seal_*`）；角色在 base_stats 里改过的别的面板项接着往后排，没有专属火漆的写项名小字 + 数
class_name StatSealPlate
extends PanelContainer

const NAME_SIZE := 26
const CAPTION_SIZE := 15
const VALUE_SIZE := 24
const SEAL := 40.0
const SEAL_GAP := 10
const COL_GAP := 18
const ROW_GAP := 8
const RULE_INK := Color(0.29, 0.21, 0.13, 0.4)

var name_label: Label = null
## 每格 [格子, 数字标签]（测试看；项名在格子的 tooltip_text）
var cells: Array = []


## [param stats] = [[项名, 数, 火漆图名（空 = 没有）], …]
func setup(title: String, stats: Array) -> StatSealPlate:
	UiTheme.panel_margins(self, UiTheme.PANEL_HOME_PLAQUE_SMALL, 22, 16, 22, 18)
	var col := UiTheme.vbox(8)
	add_child(col)
	name_label = UiTheme.make_label(title, NAME_SIZE, UiTheme.INK)
	name_label.add_theme_font_override("font", UiPalette.cjk_font_bold())
	col.add_child(name_label)
	var rule := ColorRect.new()
	rule.color = RULE_INK
	rule.custom_minimum_size.y = 2
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", COL_GAP)
	grid.add_theme_constant_override("v_separation", ROW_GAP)
	col.add_child(grid)
	for spec in stats:
		var cell := UiTheme.hbox(SEAL_GAP)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.tooltip_text = String(spec[0])
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		grid.add_child(cell)
		var tex: Texture2D = UiTheme.art_cached("stats_strip/" + String(spec[2])) if String(spec[2]) != "" else null
		if tex != null:
			var seal := TextureRect.new()
			seal.texture = tex
			seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			seal.custom_minimum_size = Vector2(SEAL, SEAL)
			seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.add_child(seal)
		else:     # 没有专属火漆：写项名，不然只剩一个光数字
			var cap := UiTheme.make_label(String(spec[0]), CAPTION_SIZE, UiTheme.INK_SOFT)
			cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.add_child(cap)
		var val := UiTheme.make_label(String(spec[1]), VALUE_SIZE, UiTheme.INK)
		val.add_theme_font_override("font", UiPalette.cjk_font_bold())
		val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(val)
		cells.append([cell, val])
	return self


func captions() -> Array:
	return cells.map(func(c: Array) -> String: return (c[0] as Control).tooltip_text)


func values() -> Array:
	return cells.map(func(c: Array) -> String: return (c[1] as Label).text)
