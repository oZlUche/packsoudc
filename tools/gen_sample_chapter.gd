## 把 RingMapConfig.sample() 倒成第一章的作者数据（架构文档 10.1）。
##
##     godot --headless --path . --script res://tools/gen_sample_chapter.gd
##
## 数值全是占位。作者之后直接改 data/authoring/chapters/chapter_01.json，
## 或者在地图编辑器里改完存回来 —— 这个脚本只负责给一份起点，不是数值的来源。
extends CliTool


func run() -> void:
	var chapter := ChapterDef.new()
	chapter.id = &"chapter_01"
	chapter.display_name = "第一章（占位）"
	chapter.map_source = MapSource.new()
	chapter.map_source.mode = MapSource.Mode.RANDOM
	chapter.map_source.generator_id = &"ring"
	chapter.map_source.generator_config = RingMapConfig.sample(6)

	var path := ContentPaths.authoring_file("chapters", "chapter_01")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ContentExporter.save(ContentExporter.export_chapter(chapter), path)
	if err != OK:
		push_error("写不了 " + path)
		finish(1)
		return
	print("已写 " + path)
	finish(0)
