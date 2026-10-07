## 一次地图校验的结果（架构文档 5.3）。
##
## 与 [ImportReport] 形似但不是一回事，所以没有复用：导入器的消息定位到
## **文件里的一个字段**（`rifle.combat.rules[0].cadence.seconds`），
## 而这里定位到**图上的一处**，并且要能按规则**跨多次尝试聚合** ——
## 生成失败会换种子重来几十次，这时「32 次里 30 次是全图不连通」远比
## 最后一次的细节有用：它直接指出该调哪个参数。
##
## 所以每条失败都带一个 [param rule] 键（`&"reachable"`、`&"goals"`…），
## 聚合按它来。消息本身写给人看。
class_name MapValidation
extends RefCounted

## {rule: StringName, message: String}
var failures: Array[Dictionary] = []


## 记一条失败。[param rule] 是聚合用的键，同一条规则多次失败用同一个键。
func fail(rule: StringName, message: String) -> void:
	failures.append({"rule": rule, "message": message})


func ok() -> bool:
	return failures.is_empty()


## 失败过的规则，按首次出现的顺序去重。
func rules() -> Array[StringName]:
	var out: Array[StringName] = []
	for f in failures:
		var r: StringName = f["rule"]
		if not out.has(r):
			out.append(r)
	return out


## 规则 → 失败条数
func tally() -> Dictionary:
	var out := {}
	for f in failures:
		var r: StringName = f["rule"]
		out[r] = int(out.get(r, 0)) + 1
	return out


## 人读的多行汇总。条数多时只列前几条 —— 「117 个节点到不了入口」列全了没人看，
## 而前几个足够定位。
func to_text(limit: int = 6) -> String:
	if failures.is_empty():
		return "✓ 没有问题"
	var lines: Array[String] = []
	for i in mini(failures.size(), limit):
		lines.append("✗ [%s] %s" % [failures[i]["rule"], failures[i]["message"]])
	if failures.size() > limit:
		lines.append("…… 另有 %d 条" % (failures.size() - limit))
	return "\n".join(lines)
