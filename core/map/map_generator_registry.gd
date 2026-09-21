## 生成器 id → 脚本路径（架构文档 5.3）。
##
## 照 [EffectRegistry] 的样子来：**一张常量表，新增一种地图形态只登记一行**，
## 章节定义里写 `generator_id`，别处一个字不改。这套在效果系统上已经验证过，
## 不再另发明一种。
##
## 章节通过 `ChapterDef.generator_id` 声明自己用哪个生成器，
## 所以「第二章换一种拓扑」是内容改动，不是代码改动。
class_name MapGeneratorRegistry
extends RefCounted

## id → 脚本路径。**加一种形态就在这里加一行。**
##
## `grid_script`（手绘网格脚本）在 M3-3b 登记。
## 测试会检查表里每一条都指向一个真实存在、且确实是 [MapGenerator] 子类的脚本 ——
## 登记了一个打错的路径，要在这里就红，而不是等某一章跑不起来。
const GENERATORS := {
	&"ring": "res://core/map/generators/ring_map_generator.gd",
}


static func has(id: StringName) -> bool:
	return GENERATORS.has(id)


## 全部已登记的 id，升序。
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in GENERATORS:
		out.append(k)
	out.sort()
	return out


## 造一个生成器实例。id 没登记、脚本加载不了、或那个脚本根本不是生成器，
## 都返回 null 并告警 —— 章节配置写错一个字，报错要说得出是哪个字。
static func create(id: StringName) -> MapGenerator:
	if not GENERATORS.has(id):
		push_warning("MapGeneratorRegistry: 没有登记过的生成器 '%s'，已登记的是 %s"
			% [id, str(ids())])
		return null
	var path: String = GENERATORS[id]
	var script := load(path) as GDScript
	if script == null:
		push_error("MapGeneratorRegistry: '%s' 登记的脚本加载不了：%s" % [id, path])
		return null
	var inst = script.new()
	if not (inst is MapGenerator):
		push_error("MapGeneratorRegistry: '%s' 登记的 %s 不是 MapGenerator 的子类" % [id, path])
		return null
	return inst
