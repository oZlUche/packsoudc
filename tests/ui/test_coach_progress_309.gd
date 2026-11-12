## 309（v5.85 体验 E04）：多步教程写进度，一步的不写
extends RefCounted


static func run_progress(t: TestCase) -> void:
	t.begin("309 · 教程纸条：多步的在字后写「　2/4」，一步的不写")
	var o := CoachOverlay.new()
	o.start([{"target": "a", "text": "A"}, {"target": "b", "text": "B"}])
	t.eq(o.line_text(), "A　1/2", "第一步")
	o.next()
	t.eq(o.line_text(), "B　2/2", "第二步")
	o.free()
	var one := CoachOverlay.new()
	one.start([{"target": "a", "text": "A"}])
	t.eq(one.line_text(), "A", "一步：不写进度")
	one.free()
