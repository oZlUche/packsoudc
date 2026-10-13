## 169（作者定：「设计一个模板配置文件，固定在亮色背景下指用暗色字体，在暗色背景下指用亮色字体」）：
## 字色模板 `data/authoring/ui/text_colors.json` —— 每个颜色名写深底版 / 浅底版；容器打 tone 元数据，富文本与语义色标签按所在的底取版
extends RefCounted

const LIGHT := &"light"
const DARK := &"dark"


static func run_template_file(t: TestCase) -> void:
	t.begin("169 · 模板文件读得到；样式名、术语、暴击、六档稀有度、每种伤害类型都有两版；浅版在纸上够清楚、和深版不一样")
	var problems := UiPalette.load_text_colors(UiPalette.TEXT_COLORS_PATH)
	t.eq(problems, [] as Array[String], "用的是文件")
	t.eq(TextColorCheck.problems(), [] as Array[String], "校验没问题（浅版对比够）")
	var tc := UiPalette.text_colors()
	for name in TextTemplate.STYLE_NAMES + UiPalette.EXTRA_STYLES:
		t.check((tc["styles"] as Dictionary).has(name), "有 %s" % name)
	t.eq((tc["rarity"] as Array).size(), ItemPainter.RARITY_COLORS.size(), "稀有度六档")
	for type in UiPalette.damage_types():
		t.check((tc["damage"] as Dictionary).has(type), "伤害 %s 有两版" % type)
	var dark := UiPalette.style_color("stamina", DARK)
	var light := UiPalette.style_color("stamina", LIGHT)
	t.eq(dark, UiPalette.STAMINA, "深版 = 原来的代码常量（行为不变）")
	t.check(light != dark and UiTheme.contrast(light, UiTheme.PAPER) >= UiTheme.MIN_CONTRAST, "体力橙的浅版是另一个色、在纸上够清楚（#%s）" % light.to_html(false))
	t.eq(UiPalette.rarity_color(0, DARK), ItemPainter.RARITY_COLORS[0], "稀有度深版 = 棋盘格的颜色")
	t.eq(UiPalette.damage_color(&"fire", DARK), UiPalette.DAMAGE_COLORS["fire"], "伤害深版 = 原来的")
	t.eq(UiPalette.resource_color(&"hp", LIGHT), UiPalette.style_color("hp", LIGHT), "资源条颜色复用同名样式")
	t.eq(UiTheme.INK, UiPalette.style_color("fg", LIGHT), "墨色读模板 fg 的浅版")
	t.eq(UiTheme.INK_WARN, UiPalette.style_color("warn", LIGHT), "警示墨色读模板 warn 的浅版")


static func run_resolve_by_tone(t: TestCase) -> void:
	t.begin("169 · 颜色名按底取版；浅底上写死的十六进制：模板里的深版换浅版、浅版不动、别的按算法压暗兜底")
	UiPalette.load_text_colors(UiPalette.TEXT_COLORS_PATH)
	var src := "[color=@stamina]体力[/color][color=@rarity5]神话[/color]"
	var on_dark := UiPalette.resolve_styles(src, DARK)
	var on_light := UiPalette.resolve_styles(src, LIGHT)
	t.check(on_dark != on_light, "两种底产出不一样")
	t.check(on_light.contains(UiPalette.style_color("stamina", LIGHT).to_html(false)) and not on_light.contains(UiPalette.STAMINA.to_html(false)), "浅底：没有亮橙")
	t.eq(UiPalette.resolve_styles(src), on_dark, "不给底 = 深")
	t.eq(UiPalette.for_tone(UiPalette.HP, LIGHT), UiPalette.style_color("hp", LIGHT), "写死的生命红 → 模板浅版")
	var ink := UiPalette.style_color("heal", LIGHT)
	t.eq(UiPalette.for_tone(ink, LIGHT), ink, "已经是浅版的不再压")
	var odd := Color("33ccaa")
	t.eq(UiPalette.for_tone(odd, LIGHT), UiTheme.ink_color(odd), "模板里没有的：算法压暗兜底")
	t.eq(UiPalette.for_tone(odd, DARK), odd, "深底原样")
	var hex := "[color=#%s]x[/color][color=@good]y[/color]" % UiPalette.GRANT.to_html(false)
	var toned := UiPalette.toned(hex, LIGHT)
	t.check(toned.contains(UiPalette.style_color("grant", LIGHT).to_html(false)) and toned.contains(UiPalette.style_color("good", LIGHT).to_html(false)), "统一入口：十六进制和颜色名一起换（%s）" % toned)
	t.eq(UiPalette.toned(hex, DARK), UiPalette.resolve_styles(hex), "深底：只换颜色名")


static func run_fallback(t: TestCase) -> void:
	t.begin("169 · 文件缺一版：整份不用、回代码默认（深版 = 常量，浅版按算法压暗），问题记下来；文件不在也一样")
	var path := "user://text_colors_169_test.json"
	var d = JSON.parse_string(FileAccess.get_file_as_string(UiPalette.TEXT_COLORS_PATH))
	(d["styles"]["hp"] as Dictionary).erase("light")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var problems := UiPalette.load_text_colors(path)
	t.check(problems.size() == 1 and problems[0].contains("styles.hp"), "报出缺的那条（%s）" % str(problems))
	t.eq(UiPalette.style_color("stamina", LIGHT), UiTheme.ink_color(UiPalette.STAMINA), "整份回默认：没缺的那条也不用文件的")
	t.eq(UiPalette.style_color("hp", DARK), UiPalette.HP, "深版是常量")
	t.eq(UiTheme.INK, UiTheme.INK_DEFAULT, "墨色回默认")
	t.check(not UiPalette.load_text_colors("user://no_such_text_colors.json").is_empty(), "文件不在：有问题")
	t.eq(UiPalette.style_color("fg", LIGHT), UiTheme.INK_DEFAULT, "文件不在：前景浅版是默认墨色")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	t.eq(UiPalette.load_text_colors(UiPalette.TEXT_COLORS_PATH), [] as Array[String], "换回仓库里的文件")


static func frame_tone_from_container(t: TestCase, root: Window) -> void:
	t.begin("169 · 底的深浅由容器说：apply_tone 打 tone 元数据，tone_at 往上找；富文本块与语义色标签进树后按底取版，换底 refresh_tones 重算")
	UiPalette.load_text_colors(UiPalette.TEXT_COLORS_PATH)
	var paper := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_TOOLTIP)
	var col := VBoxContainer.new()
	paper.add_child(col)
	var tone := UiTheme.tone_of(UiTheme.PANEL_TOOLTIP)
	t.eq(paper.get_meta(&"tone"), tone, "面板记了自己的深浅")
	t.eq(UiTheme.tone_at(col), tone, "子节点往上找到它")
	t.eq(UiTheme.tone_at(Control.new()), UiTheme.TONE_DARK, "一路没有：深")
	# 强制一块浅底，看换色
	paper.set_meta(&"tone", UiTheme.TONE_LIGHT)
	var rich := UiTheme.rich_block(300, 13, "[color=@stamina]体力[/color] 与 [color=#%s]生命[/color]" % UiPalette.HP.to_html(false))
	var heal := UiTheme.make_label("治疗 +5", 13, UiPalette.HEAL)
	t.check(rich.text.contains(UiPalette.STAMINA.to_html(false)), "还没进树：按深底")
	col.add_child(rich)
	col.add_child(heal)
	root.add_child(paper)
	t.check(not rich.text.contains(UiPalette.STAMINA.to_html(false)) and not rich.text.contains(UiPalette.HP.to_html(false)), "进了浅底：没有深版颜色（%s）" % rich.text)
	t.check(rich.text.contains(UiPalette.style_color("stamina", LIGHT).to_html(false)), "体力是模板浅版")
	t.eq(heal.get_theme_color("font_color"), UiPalette.style_color("heal", LIGHT), "语义色标签：浅版")
	paper.set_meta(&"tone", UiTheme.TONE_DARK)
	UiTheme.refresh_tones(paper)
	t.check(rich.text.contains(UiPalette.STAMINA.to_html(false)), "换成深底重算：回深版")
	t.eq(heal.get_theme_color("font_color"), UiPalette.HEAL, "标签也回深版")
	paper.set_meta(&"tone", UiTheme.TONE_LIGHT)
	UiTheme.set_rich(rich, "[color=@hp]血[/color]")
	t.check(rich.text.contains(UiPalette.style_color("hp", LIGHT).to_html(false)), "进树后换字（set_rich）：按现在的底")
	paper.queue_free()


static func frame_palette_preview(t: TestCase, root: Window) -> void:
	t.begin("169 · 启动器有「配色」页：深底、浅底两列把模板全列出来；F5 重读")
	var found := false
	for e in load("res://ui/launcher.gd").ENTRIES:
		found = found or String(e["scene"]) == "res://ui/palette_preview/palette_preview.tscn"
	t.check(found, "启动器里有配色页")
	var page = load("res://ui/palette_preview/palette_preview.tscn").instantiate()
	root.add_child(page)
	var tc := UiPalette.text_colors()
	var rows := (tc["styles"] as Dictionary).size() + (tc["rarity"] as Array).size() + (tc["damage"] as Dictionary).size()
	t.eq(page.find_children("*", "RichTextLabel", true, false).size(), rows * 2, "每条深浅各一行")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_F5
	page._unhandled_key_input(ev)
	t.eq(page.find_children("*", "RichTextLabel", true, false).size(), rows * 2, "F5 重读后照样两列")
	page.queue_free()
