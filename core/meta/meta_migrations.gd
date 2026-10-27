## 局外存档的版本迁移链（098，架构文档 7.2）：**一步只认 n → n+1**，输入输出都是 Dictionary，不碰对象。
##
## 为什么在字典层而不在对象层：[method MetaState.from_dict] 继续严格只认当前版本，内存里的对象永远只有一套形状；
## 迁移只在「读文件」这一层做（[MetaSave.from_text]），不用在 from_dict 里堆版本分支。
##
## 升版规矩（作者定）：**改语义或改 id 才升版，只加带默认值的字段不升版**（那一类靠 `d.get(key, default)` 隐式兼容）。
## 每升一版，这里加一步、[const STEPS] 加一行，并在 `tests/fixtures/` 留一份那一版的冻结样本 ——
## 链上缺了一级就报错不猜，返回的字典版本号仍然不等于当前版本，调用方按「不认识」处理（备份后从零开始）。
class_name MetaMigrations
extends RefCounted

## 有哪几步：from_version → 方法名（只做文档与自检用，分派是下面的 match，不走反射）
const STEPS := {1: "_v1_to_v2", 2: "_v2_to_v3", 3: "_v3_to_v4"}


## 尽量升到 [constant MetaState.SAVE_VERSION]。不改入参（深拷一份）。
## 升不上去（缺这一级的迁移）就把能升到哪算哪，版本号照实写在 `version` 里
static func upgrade(src: Dictionary) -> Dictionary:
	var d := src.duplicate(true)
	var v := int(d.get("version", -1))
	while v < MetaState.SAVE_VERSION:
		if not STEPS.has(v):
			push_warning("MetaMigrations: 没有 v%d → v%d 的迁移，停在 v%d" % [v, v + 1, v])
			return d
		match v:
			1:
				d = _v1_to_v2(d)
			2:
				d = _v2_to_v3(d)
			3:
				d = _v3_to_v4(d)
			_:
				push_error("MetaMigrations: STEPS 里有 v%d 但 match 没接上" % v)
				return d
		v += 1
		d["version"] = v
	return d


## v1 → v2（恒等）：v2 只是 [method MetaState.keeps] 放行了「带信仰的 1 格包」（大地之神的护符），
## 字典形状一点没变 —— 老档里不会有这种东西，照原样读回来就对
static func _v1_to_v2(d: Dictionary) -> Dictionary:
	return d


## v2 → v3（110）：补局外科技的两个空字典 —— 老档里谁都没升过级，什么也没交
static func _v2_to_v3(d: Dictionary) -> Dictionary:
	if not (d.get("tech_levels", null) is Dictionary):
		d["tech_levels"] = {}
	if not (d.get("tech_deposits", null) is Dictionary):
		d["tech_deposits"] = {}
	return d


## v3 → v4（262）：科技「集市」「铁匠铺」改义为「高级货物」「高级配方」（铺子默认 1 级，科技每级再升一级），最多两级 ——
## 老档点过的级数照旧（铺子白得一级，不退钱不扣级），只把 3 压到 2
static func _v3_to_v4(d: Dictionary) -> Dictionary:
	var levels = d.get("tech_levels", null)
	if levels is Dictionary:
		for id in ["market", "smithy"]:
			if (levels as Dictionary).has(id):
				levels[id] = mini(int(levels[id]), 2)
	return d

