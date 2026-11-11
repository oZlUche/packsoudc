## 121（作者定）：界面样式收进一个代码生成的 [Theme]（[UiTheme]）—— 变体齐全、换底色重建跟着变、
## 屏幕脚本选变体而不是逐个贴样式；棘轮挡住 `add_theme_*` 回潮
extends RefCounted

## 棘轮：游戏屏（ui/game、ui/inventory、ui/battle、ui/launcher*）**与六个编辑器**（ui/editor、ui/*_editor）里 `add_theme_` 出现的次数上限
## = 现在的实际数：游戏屏 64（121 改完时的数，没涨）+ 编辑器 71（精简 12 删掉编辑器里 31 处无效的字体覆写后一并扫进来）。
## 剩下的是布局常量（separation / margin）、编辑器里字号 13 / 12 与颜色的覆写、注了「121 特例」的那几处。
## 要加覆写先想清楚为什么不是变体；真要加就改这个数，并在那行注一句为什么。
## 150：读数组件（ui/hud）也扫进来；地图屏那条 HUD 的窄底变成主题变体 PanelHud，倒计时的两处特例搬进组件 —— 135 → 134
## 157：悬浮窗的词条小窗改走主题变体 PanelTooltip（术语色边那处特例没了）—— 134 → 133
## 游戏测试 10-21：科技树节点长名字收字号（+1），节点字色三处并成一处（-4）—— 133 → 130
## 精简批次二：两个沙盒、回放浏览器、回放、悬浮窗里 18 处盒子间距与 3 处四边边距改走 UiTheme.vbox / hbox / margins —— 130 → 109
## 精简批次四：七个编辑器的外壳（边距、三栏、校验框、JSON 框）收进 AuthoringEditor，各写一份的覆写只剩一份 —— 109 → 81
## 精简批次三：科技树节点收字号那处改走 TextFit.shrink_button_to（覆写在 ui/widgets 里那一份）—— 81 → 80
const RATCHET := 80
const SCANNED := ["res://ui/game", "res://ui/inventory", "res://ui/battle", "res://ui/hud",
	"res://ui/editor", "res://ui/event_editor", "res://ui/buff_editor", "res://ui/set_editor", "res://ui/map_editor", "res://ui/part_editor"]


static func run(t: TestCase) -> void:
	t.begin("121 · UiTheme.build：默认字体与字号、按钮三档 / 标签 / 面板 / 富文本变体齐全；换底色重建，没有美术图的平面底（树、输入框）跟着变")
	var s := GameSettings.new()
	s.bg_theme = "graphite"
	# 缺图：变体照样登记，面板的底是空的（不画替代的平面底）
	var saved_root := UiTheme.asset_root
	UiTheme.asset_root = "res://tests/fixtures/no_such_ui/"
	var bare := UiTheme.build(s)
	UiTheme.asset_root = saved_root
	for v in UiTheme.VARIATIONS:
		t.check(bare.get_type_variation_base(v) != &"", "缺图：变体 %s 还在" % v)
	t.check(bare.get_stylebox("panel", UiTheme.PANEL_DARK) is StyleBoxEmpty, "缺图：PanelDark 的底是空的")
	var th := UiTheme.build(s)
	t.not_null(th.default_font, "默认字体是 CJK 字体")
	t.eq(th.default_font_size, UiTheme.sz(UiTheme.FONT_SIZE), "默认字号 14（258：按档）")
	for v in UiTheme.VARIATIONS:
		t.check(th.is_type_variation(v, th.get_type_variation_base(v)) and th.get_type_variation_base(v) != &"", "变体 %s 在" % v)
	t.eq(th.get_type_variation_base(UiTheme.BUTTON_PRIMARY), &"Button", "按钮变体基于 Button")
	t.eq(th.get_type_variation_base(UiTheme.PANEL_DARK), &"PanelContainer", "面板变体基于 PanelContainer")
	t.eq((th.get_stylebox("normal", UiTheme.BUTTON_PRIMARY) as StyleBoxFlat).bg_color, UiPalette.BTN_PRIMARY, "主按钮琥珀底")
	t.eq(th.get_color("font_color", UiTheme.LABEL_DIM), UiPalette.DIM, "LabelDim 暗色字")
	t.check(th.get_stylebox("panel", UiTheme.PANEL_DARK) is StyleBoxTexture, "157 补充三：PanelDark 是凹槽九宫格")
	var graphite := (th.get_stylebox("panel", "Tree") as StyleBoxFlat).bg_color
	t.check(absf(graphite.r - UiPalette.PANEL.r) + absf(graphite.g - UiPalette.PANEL.g) + absf(graphite.b - UiPalette.PANEL.b) < 0.02, "默认底色下面板 ≈ 原来的 PANEL：%s" % graphite.to_html(false))
	# 作者 2026-10-12：事件正文的粗体糊 —— [b] 换真粗体（字重 700），正文 20 号、行距 8
	var bold := th.get_font("bold_font", "RichTextLabel")
	t.check(bold is FontVariation and (bold as FontVariation).base_font == UiPalette.font_file(UiPalette.FONT_BOLD), "168：富文本粗体是另一份字体文件（思源宋体 Bold）")
	t.check(bold != th.default_font, "粗体不是默认字体")
	t.eq(th.get_font_size("normal_font_size", UiTheme.RICH_BODY), UiTheme.sz(20), "正文 20 号")
	t.eq(th.get_constant("line_separation", UiTheme.RICH_BODY), 8, "正文行距 8")
	s.bg_theme = "moss"
	var mossy := UiTheme.build(s)
	var moss := (mossy.get_stylebox("panel", "Tree") as StyleBoxFlat).bg_color
	t.check(moss != graphite, "换成苔绿底：树的底色跟着变")
	t.eq((mossy.get_stylebox("normal", "LineEdit") as StyleBoxFlat).bg_color, moss.darkened(0.2), "输入框的底跟着面板色")

	t.begin("121 · 装上的主题原地重填：UiPalette.apply 换底色，当前那一份和默认主题都跟着变")
	var cur := UiTheme.current()
	var saved := UiPalette.bg_theme
	UiPalette.apply(s)
	t.eq((cur.get_stylebox("panel", "Tree") as StyleBoxFlat).bg_color, moss, "同一个 Theme 对象，底色变成苔绿的")
	t.eq((ThemeDB.get_default_theme().get_stylebox("panel", "Tree") as StyleBoxFlat).bg_color, moss, "默认主题里也换了")
	var back := GameSettings.new()
	back.bg_theme = saved
	UiPalette.apply(back)
	t.eq(UiTheme.current(), cur, "还是那一份")
	t.check(cur.get_stylebox("panel", UiTheme.PANEL_DARK) is StyleBoxTexture, "157 补充三：原地重填后 PanelDark 还是凹槽九宫格")

	t.begin("121 · 小工具先选变体：前景色 / 14 号的标签零覆写、暗色走 LabelDim、语义色才覆写；按钮只设变体")
	var l := UiTheme.label(Label.new(), 14, UiPalette.FG)
	t.check(not l.has_theme_color_override("font_color") and not l.has_theme_font_size_override("font_size"), "前景色 14 号：零覆写")
	var d := UiTheme.label(Label.new(), 14, UiPalette.DIM)
	t.eq(d.theme_type_variation, UiTheme.LABEL_DIM, "暗色：LabelDim")
	t.check(not d.has_theme_color_override("font_color"), "暗色：不覆写颜色")
	var hp := UiTheme.label(Label.new(), 20, UiPalette.HP)
	t.check(hp.has_theme_color_override("font_color") and hp.has_theme_font_size_override("font_size"), "生命红 20 号：语义色和字号才覆写")
	var b := Button.new()
	UiPalette.style_button(b, UiPalette.Tier.PRIMARY, UiPalette.button_font_size(14, UiPalette.Tier.PRIMARY))
	t.eq(b.theme_type_variation, UiTheme.BUTTON_PRIMARY, "主按钮：变体 ButtonPrimary")
	t.check(not b.has_theme_stylebox_override("normal") and not b.has_theme_font_size_override("font_size"), "默认字号的主按钮：零覆写")
	for c in [l, d, hp, b]:
		c.free()

	t.begin("121 · 棘轮：游戏屏与编辑器里 add_theme_ 不超过 %d 处（要加先想清楚为什么不是变体）" % RATCHET)
	var count := 0
	var files: Array[String] = []
	for dir in SCANNED:
		files.append_array(_scripts(dir))
	for f in DirAccess.get_files_at("res://ui"):
		if f.begins_with("launcher") and f.ends_with(".gd"):
			files.append("res://ui/" + f)
	for path in files:
		count += FileAccess.get_file_as_string(path).count("add_theme_")
	t.check(count <= RATCHET, "现在 %d 处（上限 %d）" % [count, RATCHET])
	t.check(files.size() > 20, "扫到了 %d 个脚本" % files.size())


static func frame_installed(t: TestCase, root: Window) -> void:
	t.begin("121 · 主题装进默认主题：进树的控件继承默认字体与变体，不用逐个贴")
	t.check(UiTheme.installed(), "装上了")
	t.eq(ThemeDB.get_default_theme().get_type_variation_base(UiTheme.LABEL_DIM), &"Label", "默认主题里有 LabelDim 变体")
	var l := Label.new()
	l.theme_type_variation = UiTheme.LABEL_DIM
	root.add_child(l)
	t.eq(l.get_theme_color("font_color"), UiPalette.DIM, "LabelDim 取到暗色")
	t.eq(l.get_theme_font("font"), UiTheme.current().default_font, "默认字体是主题里的 CJK 字体")
	l.queue_free()


static func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	return out
