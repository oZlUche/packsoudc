## 局外存档的版本迁移链（098，架构文档 7.2）：**一步只认 n → n+1**，输入输出都是 Dictionary，不碰对象。
##
## 为什么在字典层而不在对象层：[method MetaState.from_dict] 继续严格只认当前版本，内存里的对象永远只有一套形状；
## 迁移只在「读文件」这一层做（[MetaSave.from_text]），不用在 from_dict 里堆版本分支。
##
## 升版规矩（作者定）：**改语义或改 id 才升版，只加带默认值的字段不升版**（那一类靠 `d.get(key, default)` 隐式兼容）。
## 每升一版，这里加一步、`upgrade` 的 `match` 里接上，并在 `tests/fixtures/` 留一份那一版的冻结样本 ——
## 链上缺了一级就报错不猜，返回的字典版本号仍然不等于当前版本，调用方按「不认识」处理（备份后从零开始）。
class_name MetaMigrations
extends RefCounted


## 尽量升到 [constant MetaState.SAVE_VERSION]。不改入参（深拷一份）。
## 升不上去（缺这一级的迁移）就把能升到哪算哪，版本号照实写在 `version` 里
static func upgrade(src: Dictionary) -> Dictionary:
	var d := src.duplicate(true)
	var v := int(d.get("version", -1))
	while v < MetaState.SAVE_VERSION:
		match v:
			1:
				d = _v1_to_v2(d)
			2:
				d = _v2_to_v3(d)
			3:
				d = _v3_to_v4(d)
			4:
				d = _v4_to_v5(d)
			_:
				push_warning("MetaMigrations: 没有 v%d → v%d 的迁移，停在 v%d" % [v, v + 1, v])
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



## 319：v4 那一版（v6.19）的旧成本 —— 迁移按它退，**不按现在的科技表推算**（表改了，旧账还是旧账）。科技 id → 每级 {funds, items}
const V4_COSTS := {
	"luck": [{"funds": 400, "items": {}}, {"funds": 800, "items": {}}, {"funds": 1300, "items": {"hardwood_plank": 2, "rivet_box": 2}}],
	"bargain": [{"funds": 500, "items": {}}, {"funds": 1000, "items": {"silver_ingot": 1}}],
}
## 319：v5 归机制树的科技（v4 时它们还花钱和材料）—— 没交完的材料退回、上交记录清掉
const V5_MECHANISM := ["pack", "thorough_search", "scouting", "bargain", "market", "smithy", "mithril_smelting", "staffcraft", "luck"]


## v4 → v5（319，双科技树）：
## - 幸运删掉：已买的每一级按 v4 成本退钱退材料，等级去掉；
## - 讨价并成一级：1、2 级都记 1 级，2 级多花的那一级（1000 币 + 1 银锭）退回；
## - 归机制树的科技没交完的材料退回，上交记录清掉；已有的等级照旧（不补交见识）；
## - 数值树的等级与上交记录不动；历史总分不换见识。
## 钱直接加进 `funds`；材料写进 `migration_refund.items`，[method MetaState.from_dict] 装完仓库再放进去（放不下折钱）。迁移做了什么记进 `migration_log`
static func _v4_to_v5(d: Dictionary) -> Dictionary:
	var levels: Dictionary = d.get("tech_levels", {}) if d.get("tech_levels", null) is Dictionary else {}
	var deposits: Dictionary = d.get("tech_deposits", {}) if d.get("tech_deposits", null) is Dictionary else {}
	var funds := 0
	var items := {}
	var notes: Array = []
	var luck := clampi(int(levels.get("luck", 0)), 0, (V4_COSTS["luck"] as Array).size())
	for k in luck:
		funds += _refund_tier(V4_COSTS["luck"][k], items)
	if luck > 0:
		notes.append("luck %d" % luck)
	levels.erase("luck")
	var bargain := int(levels.get("bargain", 0))
	if bargain >= 2:
		for k in range(1, mini(bargain, (V4_COSTS["bargain"] as Array).size())):
			funds += _refund_tier(V4_COSTS["bargain"][k], items)
		notes.append("bargain %d -> 1" % bargain)
	if bargain >= 1:
		levels["bargain"] = 1
	for id in V5_MECHANISM:
		var got = deposits.get(id, null)
		if got is Dictionary:
			for item in got:
				if int(got[item]) > 0:
					items[String(item)] = int(items.get(String(item), 0)) + int(got[item])
			if not (got as Dictionary).is_empty():
				notes.append("deposits %s" % id)
		deposits.erase(id)
	d["tech_levels"] = levels
	d["tech_deposits"] = deposits
	d["funds"] = int(d.get("funds", 0)) + funds
	d["migration_refund"] = {"items": items}
	var log_: Array = d.get("migration_log", []) if d.get("migration_log", null) is Array else []
	log_.append({"to": 5, "funds": funds, "items": items.duplicate(), "notes": notes})
	d["migration_log"] = log_
	return d


static func _refund_tier(tier: Dictionary, items: Dictionary) -> int:
	for item in tier.get("items", {}):
		items[String(item)] = int(items.get(String(item), 0)) + int(tier["items"][item])
	return int(tier.get("funds", 0))
