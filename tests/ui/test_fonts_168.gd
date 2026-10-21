## 168（作者定）：打包字体 —— 正文思源宋体（Regular / Bold，170 定稿换掉霞鹜文楷）、标题朱雀仿宋、大标题马善政；按文案裁字，缺字走后备
extends RefCounted


static func run_files(t: TestCase) -> void:
	t.begin("168 · 四个字体子集都在、读得出；常用字和读数符号都有；授权与字集随包")
	for f in [UiPalette.FONT_BODY, UiPalette.FONT_BOLD, UiPalette.FONT_TITLE, UiPalette.FONT_DISPLAY]:
		var file := UiPalette.font_file(f)
		t.check(file is FontFile, "%s 读得出" % f)
		if file != null:
			t.check(file.has_char("的".unicode_at(0)) and file.has_char("撤".unicode_at(0)), "%s 有「的」「撤」" % f)
	var body := UiPalette.font_file(UiPalette.FONT_BODY)
	if body != null:
		for ch in ["Ⅳ", "♥", "×", "…"]:
			t.check(body.has_char(ch.unicode_at(0)), "正文字体有「%s」" % ch)
	# 224：账单数字 Cinzel Bold —— 只裁了数字与罗马数字那几个；缺的（汉字）落到思源宋体
	var num := UiPalette.font_file(UiPalette.FONT_NUMERAL)
	t.check(num is FontFile and num.has_char("7".unicode_at(0)) and num.has_char("X".unicode_at(0)) and not num.has_char("件".unicode_at(0)), "Cinzel 子集：有数字和 X，没有汉字")
	var nf := UiPalette.numeral_font()
	t.check(nf is FontVariation and (nf as FontVariation).base_font == num and (nf.fallbacks[0] as FontVariation).base_font == body, "账单数字：Cinzel 打底、汉字走思源宋体")
	for lic in ["OFL_NotoSerifCJK.txt", "OFL_ZhuqueFangsong.txt", "OFL_MaShanZheng.txt", "OFL_Cinzel.txt"]:
		t.check(FileAccess.file_exists("res://assets/fonts/LICENSES/" + lic), "授权 %s 随包" % lic)
	t.check(FontCoverage.charset().size() > 1000, "字集 %d 个字" % FontCoverage.charset().size())


static func run_palette(t: TestCase) -> void:
	t.begin("168 · 字体链：正文 = 思源宋体 Regular（后备系统字体）、粗体 = 思源宋体 Bold、标题 = 朱雀仿宋（后备思源宋体 Bold）、大标题 = 马善政（后备标题）")
	var body := UiPalette.cjk_font()
	t.check(body is FontVariation and (body as FontVariation).base_font == UiPalette.font_file(UiPalette.FONT_BODY), "正文打底是思源宋体 Regular")
	t.check(body.fallbacks.size() == 1 and body.fallbacks[0] is SystemFont, "缺字走系统字体（不出方块）")
	var bold := UiPalette.cjk_font_bold()
	t.check(bold is FontVariation and (bold as FontVariation).base_font == UiPalette.font_file(UiPalette.FONT_BOLD), "粗体是真 Medium 文件")
	t.check(bold.fallbacks[0] is SystemFont and (bold.fallbacks[0] as SystemFont).font_weight == 700, "粗体的后备是字重 700 的系统字体")
	var title := UiPalette.title_font()
	t.check(title is FontVariation and (title as FontVariation).base_font == UiPalette.font_file(UiPalette.FONT_TITLE), "标题是朱雀仿宋")
	var title_back: Font = title.fallbacks[0]
	t.check(title_back is FontVariation and (title_back as FontVariation).base_font == UiPalette.font_file(UiPalette.FONT_BOLD), "朱雀仿宋缺字混进思源宋体 Bold")
	var display := UiPalette.display_font()
	t.check(display is FontVariation and (display as FontVariation).base_font == UiPalette.font_file(UiPalette.FONT_DISPLAY), "大标题是马善政")
	var display_back: Font = display.fallbacks[0]
	t.check(display_back is FontVariation and (display_back as FontVariation).base_font == UiPalette.font_file(UiPalette.FONT_TITLE), "马善政缺字走标题字体")
	t.is_null(UiPalette.font_file("no_such_font.ttf"), "文件不在：null（各函数退回后备，不崩）")


static func run_theme(t: TestCase) -> void:
	t.begin("168 · 主题：默认字体思源宋体、标题与叠层标题条朱雀仿宋、LabelDisplay 马善政 40 号；按钮与正文照旧默认字体")
	var th := UiTheme.build()
	var file_of := func(f: Font) -> FontFile:
		return (f as FontVariation).base_font as FontFile if f is FontVariation else null
	t.eq(file_of.call(th.default_font), UiPalette.font_file(UiPalette.FONT_BODY), "默认字体：思源宋体 Regular")
	t.eq(file_of.call(th.get_font("bold_font", "RichTextLabel")), UiPalette.font_file(UiPalette.FONT_BOLD), "富文本 [b]：思源宋体 Bold")
	for v in [UiTheme.LABEL_TITLE, UiTheme.LABEL_OVERLAY_TITLE]:
		t.eq(file_of.call(th.get_font("font", v)), UiPalette.font_file(UiPalette.FONT_TITLE), "%s：朱雀仿宋" % v)
	t.eq(file_of.call(th.get_font("font", UiTheme.LABEL_DISPLAY)), UiPalette.font_file(UiPalette.FONT_DISPLAY), "LabelDisplay：马善政")
	t.eq(th.get_font_size("font_size", UiTheme.LABEL_DISPLAY), UiTheme.DISPLAY_SIZE, "大标题 %d 号" % UiTheme.DISPLAY_SIZE)
	t.check(not th.get_font_list(UiTheme.BUTTON_PRIMARY).has("font") and not th.get_font_list("Button").has("font"), "按钮不另设字体（= 默认思源宋体）")
	var big := UiTheme.make_display("背包搜打撤")
	t.check(big.theme_type_variation == UiTheme.LABEL_DISPLAY and not big.has_theme_font_size_override("font_size"), "make_display：走变体、默认字号零覆写")
	var mid := UiTheme.make_display("点击宝箱开锁", 28)
	t.check(mid.has_theme_font_size_override("font_size"), "换字号才覆写")
	big.free()
	mid.free()


static func run_coverage(t: TestCase) -> void:
	t.begin("168 · 覆盖：文案里用到的字都在字集里、用到的汉字思源宋体子集都有（红了 = 重跑 tools/font_charset.py 与 tools/subset_fonts.sh）")
	var used := FontCoverage.used_chars()
	t.check(used.size() > 1000, "扫到 %d 个非 ASCII 字" % used.size())
	var out := FontCoverage.not_in_charset(used)
	t.check(out.is_empty(), "都在字集里%s" % ("" if out.is_empty() else "；缺：" + "、".join(out.slice(0, 20))))
	var body := UiPalette.font_file(UiPalette.FONT_BODY)
	var bold := UiPalette.font_file(UiPalette.FONT_BOLD)
	if body != null and bold != null:
		var miss := FontCoverage.missing_hanzi(body, used)
		t.check(miss.is_empty(), "思源宋体 Regular 汉字齐%s" % ("" if miss.is_empty() else "；缺：" + "、".join(miss.slice(0, 20))))
		var miss_b := FontCoverage.missing_hanzi(bold, used)
		t.check(miss_b.is_empty(), "思源宋体 Bold 汉字齐%s" % ("" if miss_b.is_empty() else "；缺：" + "、".join(miss_b.slice(0, 20))))
	var title := UiPalette.font_file(UiPalette.FONT_TITLE)
	if title != null:
		var gaps := FontCoverage.missing_hanzi(title, used)
		if not gaps.is_empty():
			print("  ! 168：朱雀仿宋（技术预览）缺 %d 个汉字，标题里由思源宋体 Bold 补：%s" % [gaps.size(), "".join(gaps.map(func(s: String) -> String: return s.substr(0, 1)))])
	t.eq(FontCoverage.problems(), [] as Array[String], "内容校验那一条也是空的")
