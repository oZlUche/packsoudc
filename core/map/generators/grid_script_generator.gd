## 手绘地图：把一份网格脚本读成图（架构文档 5.4.1）。
##
## 它也是一个 [MapGenerator] —— 走同一个注册表、同一套校验与存档。
## 5.1 说的「可插拔」在这里第一次兑现：第二种生成器不是第二章的事，第一章就有了。
##
## 图是写死的，所以种子只影响节点的内容种子（同一张手绘图，每局刷出来的东西不同）。
class_name GridScriptGenerator
extends MapGenerator

const DEFAULT_MAP := "res://data/authoring/maps/chapter01_v0.1.txt"


func default_config() -> Resource:
	var cfg := GridScriptConfig.new()
	cfg.path = DEFAULT_MAP
	return cfg


func build(cfg: Resource, rng: RandomNumberGenerator) -> MapGraph:
	var script_cfg := cfg as GridScriptConfig
	if script_cfg == null:
		build_note = "配置不是 GridScriptConfig"
		return null
	var text := script_cfg.read()
	if text == "":
		build_note = "读不到网格脚本：%s" % script_cfg.path
		return null
	var graph := MapGridText.parse(text)
	if graph == null:
		build_note = "网格脚本解析失败：%s" % MapGridText.last_error
		return null
	for id in graph.node_ids():
		graph.get_node(id).content_seed = rng.randi()
	return graph


## 手绘的图只多问一件事：高危区长得对不对。别的形态规矩（槽位、边长、出生点间隔）
## 是给随机生成器的，作者画成什么样就是什么样。
func validate(graph: MapGraph, v: MapValidation) -> void:
	super(graph, v)
	if graph != null and graph.node_count() > 0:
		ZoneRules.validate(graph, v)
