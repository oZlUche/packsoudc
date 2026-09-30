## 一局游戏的地图从哪来：**随机生成**，还是**载入预设**（架构文档 5.3.1）。
##
## 章节 / 对局配置里放一个它，开局时调 [method resolve] 拿图 ——
## 调用方不必知道这张图是算出来的还是读出来的。
class_name MapSource
extends Resource

enum Mode {
	RANDOM,   ## 用 generator_id 指的生成器 + generator_config 现场生成
	PRESET,   ## 载入 preset_path 指的那张图（编辑器存出来的）
}

@export var mode: Mode = Mode.RANDOM

@export_group("随机生成")
## [MapGeneratorRegistry] 里登记的 id
@export var generator_id: StringName = &"ring"
## 交给生成器的配置。类型由生成器自己认（环形图是 [RingMapConfig]）
@export var generator_config: Resource = null

@export_group("载入预设")
@export_file("*.json") var preset_path: String = ""
## 预设图定死的是**地形**（点、路、类型）。节点里具体刷出什么由 content_seed 决定 ——
## true = 每局按对局种子重掷，同一张图每次打法不同；false = 连内容也原样照搬
@export var reroll_content_seeds: bool = true

## 上一次 [method resolve] 失败的原因；成功则为空
var last_error: String = ""


## 拿到这一局的地图。失败返回 null，原因在 [member last_error]。
## [param scale_id]（085）：随机图按这个规模生成（配置里 `scales` 的 id，环数取那一档的最少环 —— 作者要更多可再给一个环数参数）；空 = 配置里现成的
func resolve(run_seed: int, scale_id: StringName = &"") -> MapGraph:
	last_error = ""
	match mode:
		Mode.PRESET:
			return _resolve_preset(run_seed)
		_:
			return _resolve_random(run_seed, scale_id)


## 配置里有哪些规模可选（给开局屏）：[{id, display_name}]；不是环形生成器 / 没配就空
func scale_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if mode == Mode.PRESET or generator_config == null or not ("scales" in generator_config):
		return out
	for p in generator_config.get("scales"):
		if p != null:
			out.append({"id": p.id, "display_name": p.display_name if p.display_name != "" else String(p.id), "step_limit": int(p.get("step_limit")) if "step_limit" in p else 0})
	return out


func _resolve_random(run_seed: int, scale_id: StringName = &"") -> MapGraph:
	var gen := MapGeneratorRegistry.create(generator_id)
	if gen == null:
		last_error = "没有登记过的生成器 '%s'" % generator_id
		return null
	var cfg := generator_config
	if scale_id != &"" and cfg != null and cfg.has_method("apply_scale") and cfg.has_method("scale_by_id"):
		var p = cfg.call("scale_by_id", scale_id)
		if p != null:
			cfg = cfg.duplicate(true)     # 别改章节资产本身
			cfg.call("apply_scale", scale_id, int(p.rings.x))
	var graph := gen.generate(cfg, run_seed)
	if graph == null:
		last_error = "生成器 '%s' 连试 %d 次都没生成出合法地图" % [generator_id, gen.attempts_used]
	return graph


func _resolve_preset(run_seed: int) -> MapGraph:
	var graph := MapPreset.load_graph(preset_path)
	if graph == null:
		last_error = "预设地图载入失败：%s" % preset_path
		return null
	# 只问通用的那几条（连得上、有入口、到得了终点）。形态自己的规矩（环形图的配额、
	# 高危区单入口……）是给生成器的约束，不是给作者的 —— 手绘的图有权不守
	var v := MapValidation.new()
	MapGenerator.validate_common(graph, v)
	if not v.ok():
		last_error = "预设地图 %s 没通过校验：\n%s" % [preset_path, v.to_text()]
		push_error("MapSource: " + last_error)
		return null
	if reroll_content_seeds:
		for id in graph.node_ids():
			graph.get_node(id).content_seed = hash("%d:%d" % [run_seed, id])
	return graph
