## 难度实验的改数（报告 303，材料与难度方案 §7.2 D1 / D3）：只在实验副本里改，不碰资产、不碰共用的敌人池。
##
## 一份改数是个字典：
## - `foe`：`{"敌人 id 或 *": {"属性": 倍率}}` —— 按敌人基线（默认 → 敌人自己 → 档位倍率 → 节点内容覆盖）算出的值再乘，
##   写进节点内容的 `base_stats`（[method EnemyKit.baseline_of] 最后读它）。只改这一种敌人，不动档位表（档位表一改就是整池）；
## - `hp`：双方编译好的最大生命同乘（D3 节奏拉长；道具加的生命也一起乘）。
## 空字典 = 不改（基线）
class_name BalanceMutation
extends RefCounted


static func foe_mults(m: Dictionary, enemy_id: String) -> Dictionary:
	var out := {}
	var table = m.get("foe", {})
	if not (table is Dictionary):
		return out
	for k in ["*", enemy_id]:
		var row = (table as Dictionary).get(k, null)
		if row is Dictionary:
			for stat in row:
				out[String(stat)] = float(out.get(String(stat), 1.0)) * float(row[stat])
	return out


## 敌人节点内容按 [param m] 改好的副本；没命中返回原件
static func foe_content(content: Dictionary, m: Dictionary, enemies: EnemyDatabase, pool: EnemyPool) -> Dictionary:
	var eid := String(content.get("enemy", ""))
	var mults := foe_mults(m, eid)
	if mults.is_empty() or enemies == null:
		return content
	var def := enemies.enemy(StringName(eid))
	if def == null:
		return content
	var tier := pool.tier_of(int(content.get("strength", 0))) if pool != null else null
	var b := EnemyKit.baseline_of(def, tier, content)
	var out := content.duplicate(true)
	var over := {}
	if out.get("base_stats", null) is Dictionary:
		over = (out["base_stats"] as Dictionary).duplicate()
	for stat in mults:
		over[stat] = b.value_of(StringName(stat), 0.0) * float(mults[stat])
	out["base_stats"] = over
	return out


## 编译好的一方按 `hp` 乘最大生命（原地改；实验每次现编译，不会串到别的实验）
static func scale_hp(spec: CombatantSpec, m: Dictionary) -> void:
	var k := float(m.get("hp", 1.0))
	if spec != null and k != 1.0:
		spec.max_hp = roundi(float(spec.max_hp) * k)
