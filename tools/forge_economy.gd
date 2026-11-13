## 合成改造 C 批第五步（报告 310，方案 §9.3）首轮经济对照：只读。
## 每张产物「不进随机来源」的铁匠配方（及秘银剑、大魔导杖），算最便宜的一套料 + 资金 = 打造成本，
## 对照成品在基地卖得的价（定价 × MetaRules.sell_ratio）、
## 打了再卖比直接卖料多得多少（profit_vs_selling_mats）。
## 成本按 [ItemValue] 定价，材料是局内带回来的，所以它是「机会成本」而不是真花的钱。
##
##     godot --headless --path . --script res://tools/forge_economy.gd -- <输出.csv>
extends CliTool


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://forge_economy.csv"
	var items := ItemDatabase.new()
	items.load_dir()
	var ratio := GameFlow.load_meta_rules().sell_ratio
	var all := SmithRecipeDef.load_all()
	var lines: Array[String] = ["recipe,output,output_rarity,funds,materials_value,forge_cost,sell_at_base,margin,profit_vs_selling_mats,cheapest_set"]
	for r in all:
		var out := items.get_def(r.output)
		if out == null or not (out.is_no_random_source() or r.id == &"smith_mithril_sword" or r.id == &"smith_grand_magus_staff"):
			continue
		var mats := 0
		var set_: Array[String] = []
		for key in r.inputs:
			var d := items.get_def(StringName(String(key)))
			mats += ItemValue.of(d) * int(r.inputs[key])
			set_.append("%s×%d" % [key, int(r.inputs[key])])
		for slot in r.slots():
			var cheapest: ItemDef = null
			for id in items.ids(true):
				var d := items.get_def(id)
				if SmithRecipeDef.slot_fits(slot, d) and (cheapest == null or ItemValue.of(d) < ItemValue.of(cheapest)):
					cheapest = d
			if cheapest != null:
				mats += ItemValue.of(cheapest) * int(slot["count"])
				set_.append("%s×%d" % [cheapest.id, int(slot["count"])])
		var cost := r.funds + mats
		var sell := roundi(ItemValue.of(out) * ratio)
		var arb := sell - r.funds - roundi(mats * ratio)     # 材料不打造、直接在基地卖掉的那笔也算进来：正数 = 打了再卖比直接卖料多得
		lines.append("%s,%s,%d,%d,%d,%d,%d,%d,%d,%s" % [r.id, r.output, out.rarity, r.funds, mats, cost, sell, sell - cost, arb, " + ".join(PackedStringArray(set_))])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(PackedStringArray(lines)) + "\n")
	f.close()
	print("\n".join(PackedStringArray(lines)))
	finish()
