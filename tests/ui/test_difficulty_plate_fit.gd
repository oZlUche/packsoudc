## 测试 v5.26 反馈：英文大号的「Start challenge」比难度铜牌宽，两头被铜扣切掉 —— 字放不下就缩字号，牌子不动
extends RefCounted


static func frame_plate_text_fits(t: TestCase, root: Window) -> void:
	t.begin("难度铜牌：长字缩到铜扣之间放得下；短字不缩")
	var block := DifficultyBlock.new()
	block.open_btn.set_meta(TextFit.BASE_META, 40)     # 大号字的起点
	block.open_btn.text = "Start challenge"
	root.add_child(block)
	block._layout()
	var b := block.open_btn
	var px := b.get_theme_font_size("font_size")
	var room := block.face_rect().size.x * DifficultyBlock.PLATE_TEXT_FRAC
	t.check(px < 40, "缩了（%d 号）" % px)
	t.check(b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= room, "放得下（字区 %.0f）" % room)
	b.text = "Go"
	block._layout()
	t.eq(b.get_theme_font_size("font_size"), 40, "短字回到原字号")
	block.free()
