## 304（武器、合成与铸造升级现状调查）：只读导出 —— 用正式加载入口（[ItemDatabase]、[RecipeDef.load_all]、[SmithRecipeDef.load_all]）
## 把全部道具、相邻 / 拖合配方、铁匠铺与砧配方导成一份 JSON，供调查附表用。不写存档、不改内容。
##
##     godot --headless --path . --script res://tools/export_weapon_web.gd -- <输出.json>
extends CliTool


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://weapon_web.json"
	var items := ItemDatabase.new()
	var n := items.load_dir()
	var recipes := RecipeDef.load_all()
	var smith := SmithRecipeDef.load_all()
	var ids: Array = items.all_ids()     # 全部（含封存、随身、铸牌等 ids() 滤掉的），每行再记 in_pool
	Ids.sort(ids)
	var pool := items.ids()
	var codex := items.ids(true)
	var item_rows: Array = []
	for item_id in ids:
		var row := _item(items.get_def(StringName(String(item_id))))
		row["in_random_pool"] = pool.has(item_id)     # [method ItemDatabase.ids]：搜索 / 掉落 / 商店 / 敌人装备的总候选
		row["in_codex_list"] = codex.has(item_id)
		item_rows.append(row)
	var recipe_rows: Array = []
	for r in recipes:
		recipe_rows.append({"id": String(r.id), "inputs": r.inputs.map(func(x): return String(x)), "output": String(r.output),
			"adjacent": r.adjacent, "display_name": r.display_name, "note": r.note})
	var smith_rows: Array = []
	for s in smith:
		smith_rows.append({"id": String(s.id), "output": String(s.output), "inputs": _str_dict(s.inputs), "material_inputs": _str_dict(s.material_inputs), "material_slots": s.material_slots,
			"funds": s.funds, "group": s.group, "level": s.level, "tech": String(s.tech), "tech_level": s.tech_level,
			"is_upgrade": Anvil.is_upgrade(s), "note": s.note})
	var doc := {
		"generated_by": "tools/export_weapon_web.gd",
		"engine": Engine.get_version_info().get("string", ""),
		"item_count_loaded": n,
		"items": item_rows,
		"recipes": recipe_rows,
		"smith_recipes": smith_rows,
		"quality": {"scaled_stats": BattleCompiler.QUALITY_SCALED.map(func(x): return String(x)), "step": BattleCompiler.QUALITY_STEP,
			"percent_step": BattleCompiler.QUALITY_PERCENT_STEP, "max": ItemInstance.QUALITY_MAX},
	}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("写不了 " + out_path)
		finish(1)
		return
	f.store_string(JSON.stringify(doc, "\t", false))
	f.close()
	print("导出 %d 件道具、%d 张配方、%d 张铁匠铺配方 → %s" % [item_rows.size(), recipe_rows.size(), smith_rows.size(), out_path])
	finish(0)


func _str_dict(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = d[k]
	return out


func _item(d: ItemDef) -> Dictionary:
	var cells: Array = []
	if d.shape != null:
		for c in d.shape.cells:
			cells.append([c.x, c.y])
	var row := {
		"id": String(d.id), "name_zh": d.display_name, "name_en": String(d.display_names.get("en", "")),
		"has_description": d.description != "", "rarity": d.rarity, "tags": d.tags.map(func(x): return String(x)),
		"material": d.material, "crystal_family": String(d.crystal_family), "cells": cells, "weight": d.weight, "value": d.value,
		"requires_unlock": String(d.requires_unlock), "unique": d.is_unique(), "no_random_source": d.is_no_random_source(),
		"signature": d.is_signature(), "keepsake": d.is_keepsake(), "sealed": d.is_sealed(), "lesser": d.is_lesser(), "ticket": d.is_ticket(), "token": d.is_token(), "blessed_of": String(d.blessed_of), "has_wear": d.wear != null,
		"wear_broken_into": null,
		"has_enchant": d.enchant != null, "has_growth": d.growth != null, "is_bag": d.is_bag,
		"applies": d.applies.map(func(a): return {"buff": String(a.get("buff")) if a.get("buff") != null else "", "stacks": a.get("stacks")}),
	}
	row["combat"] = null
	if d.wear != null:
		row["wear_broken_into"] = String(d.wear.broken_into)
	if d.combat != null:
		row["combat"] = _combat(d.combat)
	return row


func _combat(p: CombatProfile) -> Dictionary:
	var rules: Array = []
	for r in p.rules:
		var rule := r as AbilityRule
		var cad = null
		if rule.cadence != null:
			cad = {"class": _cls(rule.cadence)}
			for key in ["seconds", "step_seconds", "use_haste"]:
				if key in rule.cadence:
					cad[key] = rule.cadence.get(key)
		var costs: Array = []
		for c in rule.costs:
			var cr := {"class": _cls(c)}
			for key in ["resource_key", "amount", "amount_stat"]:
				if key in c:
					cr[key] = str(c.get(key)) if c.get(key) is StringName else c.get(key)
			costs.append(cr)
		var fx: Array = []
		for e in rule.effects:
			var er := {"class": _cls(e)}
			for key in ["buff", "stacks", "axis", "delta", "amount", "damage_stat", "damage_type"]:
				if key in e:
					var v = e.get(key)
					er[key] = v.resource_path.get_file().get_basename() if v is Resource else (str(v) if v is StringName else v)
			fx.append(er)
		rules.append({"trigger": _cls(rule.trigger), "cadence": cad, "costs": costs, "effects": fx})
	return {"base_stats": _str_dict(p.base_stats), "power_mult": p.power_mult, "rules": rules}


func _cls(o: Object) -> String:
	if o == null:
		return ""
	var s: Script = o.get_script()
	if s != null and s.get_global_name() != &"":
		return String(s.get_global_name())
	return o.get_class()
