## 检查仓库里的作者 JSON 与导入产出的 `.tres` 一致（100 第 1 步）。
##
##     "E:/Godot/..._console.exe" --headless --path . --script res://tools/check_content.gd
##
## 一致退 0，对不上退 1（内容的问题）。逻辑在 [ContentCheck]，测试调的是同一段
## （`tests/test_content_pipeline.gd`），所以命令行红的时候测试也红。
## `tools/test.sh` 每次都跑它 —— 改了 JSON 忘跑导入，当场就知道，而不是等「游戏里怎么没变化」。
extends CliTool


func run() -> void:
	var problems := ContentCheck.run_all()
	problems.append_array(GodsTable.check())     # 104：神明总表是信仰的核心配置，表与 JSON 对不上同样算不一致
	# 104 第十节：说明文本里写死的数字。TextLint.STRICT（2026-10-02 起为 true）= 算不一致；false 时只列出警告
	var bare := TextLint.scan_all()
	if TextLint.STRICT:
		problems.append_array(bare)
	elif not bare.is_empty():
		print("警告：说明文本里有 %d 处写死的数字：" % bare.size())
		for w in bare:
			print("  ! %s" % w)
	if problems.is_empty():
		print("内容一致：%d 种都对得上" % ContentPaths.ORDER.size())
		finish(0)
		return
	print("内容不一致，%d 处：" % problems.size())
	for p in problems:
		print("  ✗ %s" % p)
	finish(1)
