## 道具编辑器的草稿缓存（架构文档 10.5）。
##
## 这一组用 `frame_` 前缀：编辑器要进场景树才活得起来，
## 而 `_ready` 得等进入帧循环才派发 —— 在 `_initialize` 里 add_child 之后立刻用，
## 控件全是 null（踩过一次）。
extends RefCounted

const SCENE := "res://ui/editor/content_editor.tscn"


static func frame_run_drafts(t: TestCase, root: Window) -> void:
	t.begin("编辑器 · 草稿缓存")

	var ed = load(SCENE).instantiate()
	root.add_child(ed)

	# 盘上得有东西可切，否则这组用例没有意义
	if ed._ids.size() < 2:
		t.check(false, "data/authoring/items 里至少要有两件道具才能测切换")
		ed.queue_free()
		return

	# --- 刚打开的不该算改过 ---
	ed._open("mag")
	t.eq(ed._def.display_name, "弹匣", "打开 mag")
	t.eq(ed._drafts.size(), 0,
		"刚从盘上读进来不算改过 —— 基准必须在 _bind 之前写好，否则一打开就是脏的")

	# --- 改了就进草稿，列表上有标记 ---
	ed._def.display_name = "改过的弹匣"
	ed._refresh()
	t.eq(ed._drafts.size(), 1, "改动进了草稿")
	t.check(ed._list.get_item_text(ed._ids.find("mag")).begins_with("●"),
		"列表上打了标记，作者不必靠记忆")

	# --- 切走再切回来，改动还在。这是这套机制存在的全部理由 ---
	ed._open("pistol")
	t.eq(ed._def.display_name, "手枪", "切到别的道具")
	t.eq(ed._drafts.size(), 1, "切走之后草稿仍在")
	ed._open("mag")
	t.eq(ed._def.display_name, "改过的弹匣", "**切回来改动还在**")

	# --- 改回原样，草稿自动撤掉 ---
	ed._def.display_name = "弹匣"
	ed._refresh()
	t.eq(ed._drafts.size(), 0, "改回去就不算改过了，标记也该消失")
	ed._open("pistol")
	ed._open("mag")
	t.eq(ed._def.display_name, "弹匣", "没有草稿时从盘上读")

	# --- 放弃改动 ---
	ed._def.display_name = "又改了"
	ed._refresh()
	t.eq(ed._drafts.size(), 1, "又改了一次")
	ed._on_discard()
	t.eq(ed._drafts.size(), 0, "放弃改动清掉了草稿")
	t.eq(ed._def.display_name, "弹匣", "并从盘上重读")

	ed.queue_free()


static func frame_run_editor_smoke(t: TestCase, root: Window) -> void:
	t.begin("编辑器 · 基本可用")

	var ed = load(SCENE).instantiate()
	root.add_child(ed)

	t.check(ed._ids.size() > 0, "列出了作者数据目录里的道具")
	t.check(ed._def != null, "开场自动打开了一件")

	# 校验走的就是导入器 —— 界面说没问题，命令行就一定过得去
	ed._open("mag")
	t.check(ed._validate().ok(), "现有资产在编辑器里校验通过")

	# 画板真的拿到了邻接标记
	t.eq(ed._shape.grant_cells().size(), 2, "弹匣的两个增益格画在了网格上")

	# 存出来的 JSON 与导出器一致
	t.eq(ed._preview.text, ContentExporter.to_json(ContentExporter.export_item(ed._def)),
		"JSON 预览就是将要写盘的内容")

	ed.queue_free()
