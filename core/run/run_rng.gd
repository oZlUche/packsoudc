## 分流随机源（架构文档 1.4）：按用途开独立的随机流，每个流的第 i 次抽用 hash(run_seed, 流名, i) 做种。
##
## 改动一个流里的一次随机调用，别的流一个数都不变 —— bug 才可复现。
## 节点里的内容（敌人、掉落、搜索、商店）已经各按节点自己的 `content_seed` 派生（5.10），不走这里；
## 这里管的是**不属于任何一个点**的 run 级随机（将来的带选项事件、局外奖励……）。
## 每个流抽到第几次跟着存档走，读档之后接着抽出来的和没存过一样。
class_name RunRNG
extends RefCounted

var run_seed: int = 0
var _counters: Dictionary = {}   # 流名 -> 下一次的序号


func _init(p_seed: int = 0) -> void:
	run_seed = p_seed


## 这个流的下一个随机源。每调一次序号 +1
func next(stream: StringName) -> RandomNumberGenerator:
	var i := int(_counters.get(String(stream), 0))
	_counters[String(stream)] = i + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s:%d" % [run_seed, stream, i])
	return rng


## 这个流抽过几次
func index_of(stream: StringName) -> int:
	return int(_counters.get(String(stream), 0))


func to_dict() -> Dictionary:
	return {"seed": run_seed, "counters": _counters.duplicate()}


static func from_dict(d: Dictionary) -> RunRNG:
	var r := RunRNG.new(int(d.get("seed", 0)))
	for k in d.get("counters", {}):
		r._counters[String(k)] = int(d["counters"][k])
	return r
