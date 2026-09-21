## 预设地图：一张存成 JSON 的 [MapGraph]（架构文档 5.3.1）。
##
## 文件内容就是 `MapGraph.to_dict()` 外加一个名字 —— 不另发明格式。
## 编辑器存、[MapSource] 读；生成出来的图与手改过的图在这里没有区别。
class_name MapPreset
extends RefCounted

## 预设地图放在哪。编辑器的「载入」列表扫的就是这个目录
const DIR := "res://data/maps"


static func path_for(preset_name: String) -> String:
	return "%s/%s.json" % [DIR, preset_name]


## 目录里全部预设的名字（不带扩展名），升序。
static func list() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			out.append(f.get_basename())
	out.sort()
	return out


static func save(graph: MapGraph, path: String) -> Error:
	if graph == null:
		return ERR_INVALID_PARAMETER
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(graph.to_dict(), "\t") + "\n")
	f.close()
	return OK


## 读一张预设。文件不在、不是 JSON、或者不是一张图，都返回 null 并说明是哪一种。
static func load_graph(path: String) -> MapGraph:
	if not FileAccess.file_exists(path):
		push_error("MapPreset: 找不到预设地图 %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("nodes"):
		push_error("MapPreset: %s 不是一张地图（要一个带 nodes 的 JSON 对象）" % path)
		return null
	return MapGraph.from_dict(parsed)
