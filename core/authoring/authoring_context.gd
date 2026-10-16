## 176：一份带着整个库的导入上下文（编辑器、测试单独导入一件东西时用；原来是 ContentLibrary 的 `context()`）。
##
## 不放在 [ContentLibrary] 里：游戏侧要用 ContentLibrary（反应查 buff），它一写 `ContentImporter` 这个名字，
## 导入器、导出器、表格工具就全被拖进游戏启动时的编译图（`tests/tools/test_startup_graph.gd` 守着）。
## 不写 `class_name`，用的地方按路径 `preload`
extends RefCounted


static func context() -> ContentImporter.Context:
	var ctx := ContentImporter.Context.new()
	for b in ContentLibrary.buffs().values():
		ctx.register_buff(b)
	for p in ContentLibrary.parts().values():
		ctx.register_rule_part(p)
	return ctx
