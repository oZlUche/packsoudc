## 赐福异体参与合成方案（docs/plans/2026-11-12-blessed-fusion-review-actions.md §6、§8.6）第一步：只读导出
## 「配方 × 赐福来源」矩阵。每张配方的两件输入各取「普通」或「每位有赐福版的神」，逐组分类：
##   ready（成品有那位神的赐福版或两件都普通）/ loss（成品没有那位神的赐福版，会回落普通）/
##   forbidden_pending（两把武器分属两位神）/ cross_other（别的异神组合，按择神规则走）/ invalid（成品不存在）。
## 另列 §8.5：被赐福后稀有度够得上更高一档铁匠材料格的素材。不改内容、不写存档。
##
##     godot --headless --path . --script res://tools/blessed_fusion_matrix.gd -- <输出目录>
extends CliTool


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://blessed_matrix"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var items := ItemDatabase.new()
	items.load_dir()
	var faiths: Array = FaithDef.load_all().keys()
	Ids.sort(faiths)
	var rows: Array[String] = ["recipe_id,input_a,faith_a,input_b,faith_b,output,class,output_variants"]
	var counts := {"ready": 0, "loss": 0, "forbidden_pending": 0, "cross_other": 0, "invalid": 0}
	var loss_pairs := {}
	for r in RecipeDef.load_all():
		var a := r.inputs[0]
		var b := r.inputs[1]
		var out := items.get_def(r.output)
		var sa := _sources(items, a, faiths)
		var sb := _sources(items, b, faiths)
		for fa in sa:
			for fb in sb:
				var cls := _classify(items, r, fa, fb)
				counts[cls] = int(counts[cls]) + 1
				var have: Array[String] = []
				for f in [fa, fb]:
					if String(f) != "" and Blessings.variant_of(items, r.output, f) != null and not have.has(String(f)):
						have.append(String(f))
				if cls == "loss":
					loss_pairs["%s|%s" % [r.id, fa if String(fa) != "" else fb]] = true
				rows.append("%s,%s,%s,%s,%s,%s,%s,%s" % [r.id, a, fa, b, fb, String(r.output) if out != null else "MISSING", cls, " ".join(PackedStringArray(have))])
	_write(out_dir.path_join("matrix.csv"), "\n".join(PackedStringArray(rows)) + "\n")
	# §8.5：赐福把素材抬到更高一档
	var mat_rows: Array[String] = ["base,faith,variant,base_rarity,variant_rarity,material"]
	var ids: Array = items.all_ids()
	Ids.sort(ids)
	for id in ids:
		var d := items.get_def(StringName(String(id)))
		if d == null or not d.is_blessed():
			continue
		var base := items.get_def(d.blessed_of)
		if base == null or not (base.tags.has(&"material") or base.tags.has(&"crystal")) or d.rarity <= base.rarity:
			continue
		mat_rows.append("%s,%s,%s,%d,%d,%s" % [base.id, _faith_of(d, faiths), d.id, base.rarity, d.rarity, base.material if base.tags.has(&"material") else "crystal:" + String(base.crystal_family)])
	_write(out_dir.path_join("blessed_materials.csv"), "\n".join(PackedStringArray(mat_rows)) + "\n")
	print(JSON.stringify({"counts": counts, "loss_recipe_faith_pairs": loss_pairs.size(), "blessed_materials_up": mat_rows.size() - 1}))
	finish()


## 这件输入的来源：普通（空串）+ 每位有它赐福版的神
static func _sources(items: ItemDatabase, base: StringName, faiths: Array) -> Array[StringName]:
	var out: Array[StringName] = [&""]
	out.append_array(Blessings.faiths_with_variant(items, base, faiths))
	return out


static func _classify(items: ItemDatabase, r: RecipeDef, fa: StringName, fb: StringName) -> String:
	if items.get_def(r.output) == null:
		return "invalid"
	if fa == &"" and fb == &"":
		return "ready"
	if fa != &"" and fb != &"" and fa != fb:
		var wa := items.get_def(r.inputs[0])
		var wb := items.get_def(r.inputs[1])
		if wa != null and wb != null and wa.tags.has(&"weapon") and wb.tags.has(&"weapon"):
			return "forbidden_pending"
		return "cross_other"
	var f := fa if fa != &"" else fb
	return "ready" if Blessings.variant_of(items, r.output, f) != null else "loss"


static func _faith_of(d: ItemDef, faiths: Array) -> String:
	for f in faiths:
		if Blessings.variant_id(d.blessed_of, StringName(String(f))) == d.id:
			return String(f)
	return "?"


static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
