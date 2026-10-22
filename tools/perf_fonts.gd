## 237：量「每次新建系统字体」的成本 —— 修复前（每次 SystemFont.new + FontVariation.new）对修复后（UiPalette 缓存），
## 以及一个大字体文件 load_dynamic_font 一次要多久（给「Windows 上每帧读微软雅黑」做参照）：
##
##     godot --headless --path . --script res://tools/perf_fonts.gd -- /usr/share/fonts/truetype/wqy/wqy-zenhei.ttc
extends CliTool


func run() -> void:
	var big := ""
	for cand in OS.get_cmdline_user_args():
		if FileAccess.file_exists(cand):
			big = cand
	# 1. 修复前的做法：每次 SystemFont.new() + font_names + FontVariation.new()
	var t0 := Time.get_ticks_usec()
	for i in 50:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif"])
		f.font_weight = 700
		var v := FontVariation.new()
		v.base_font = UiPalette.font_file(UiPalette.FONT_BOLD)
		v.fallbacks = [f]
	print("修复前：新建 SystemFont+FontVariation ×50：%.2f ms（每次 %.3f ms；本机 sans-serif 落到 %s）" % [(Time.get_ticks_usec() - t0) / 1000.0, (Time.get_ticks_usec() - t0) / 50000.0, OS.get_system_font_path("sans-serif")])
	# 2. 修复后：缓存命中
	UiPalette.cjk_font_bold()
	t0 = Time.get_ticks_usec()
	for i in 50:
		UiPalette.cjk_font_bold()
	print("修复后：UiPalette.cjk_font_bold() ×50：%.3f ms" % [(Time.get_ticks_usec() - t0) / 1000.0])
	# 3. 文件大小对成本的影响：直接 load_dynamic_font 一个大字体文件
	if big != "":
		var size_mb := float(FileAccess.get_file_as_bytes(big).size()) / 1048576.0
		t0 = Time.get_ticks_usec()
		for i in 5:
			var ff := FontFile.new()
			ff.load_dynamic_font(big)
			ff.get_face_count()
		print("load_dynamic_font(%s，%.1f MB) ×5：%.1f ms（每次 %.1f ms）" % [big.get_file(), size_mb, (Time.get_ticks_usec() - t0) / 1000.0, (Time.get_ticks_usec() - t0) / 5000.0])
	# 4. 新字体对象首次画字（字形缓存从零开始）vs 同一对象再画
	var lbl := Label.new()
	root.add_child(lbl)
	var text := "生命 36/36 护甲 12 格挡 3"
	t0 = Time.get_ticks_usec()
	for i in 20:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["sans-serif"])
		var v := FontVariation.new()
		v.base_font = UiPalette.font_file(UiPalette.FONT_BOLD)
		v.fallbacks = [f]
		v.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
		v.draw_string_outline(lbl.get_canvas_item(), Vector2(0, 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5)
		v.draw_string(lbl.get_canvas_item(), Vector2(0, 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	print("每次新字体对象排版 + 描边画一行 ×20：%.1f ms（每次 %.2f ms）" % [(Time.get_ticks_usec() - t0) / 1000.0, (Time.get_ticks_usec() - t0) / 20000.0])
	var same := UiPalette.cjk_font_bold()
	same.draw_string_outline(lbl.get_canvas_item(), Vector2(0, 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5)
	t0 = Time.get_ticks_usec()
	for i in 20:
		same.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
		same.draw_string_outline(lbl.get_canvas_item(), Vector2(0, 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5)
		same.draw_string(lbl.get_canvas_item(), Vector2(0, 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	print("同一字体对象再画 ×20：%.2f ms（每次 %.3f ms）" % [(Time.get_ticks_usec() - t0) / 1000.0, (Time.get_ticks_usec() - t0) / 20000.0])
	finish(0)
