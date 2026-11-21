## 354：「买来就炼」核对表（只读）。两张表：
## 1. 集市卖的每件素材：买价、尘值、两档折损下得尘、每点尘花几枚金币（< 1 = 买来炼比尘的面值便宜，倒挂）；
## 2. 每张铁匠配方：全用尘补要几点尘（点名道具按尘值；魔晶石格、传说格不能补），
##    （材料格按这一格最便宜的合格品的基础价）能补的那几样直接在集市买最便宜的合格品要几枚金币，和「买集市里每尘最便宜的素材来炼、再补」要几枚金币；后者更便宜 = 倒挂。
## 只看「能补的料」：不能补的、集市买不到的不比。
##
##     godot --headless --path . --script res://tools/alchemy_arbitrage.gd -- <输出.md>
extends CliTool


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://alchemy_arbitrage.md"
	var items := ItemDatabase.new()
	items.load_dir()
	var rules := Alchemy.load_rules()
	var mrules := Market.load_rules()
	var losses: Array[float] = [rules.loss_at(3), rules.loss_at(4)]
	var sold := {}     # 集市满级会卖的：id → 买价
	for st in Market.stalls():
		for id in Market.catalogue(mrules, items, st, 99):
			sold[id] = Market.price_of(mrules, items.get_def(id))
	var lines: Array[String] = []
	lines.append("## 表一 · 集市素材买来就炼")
	lines.append("")
	lines.append("| 素材 | 买价 | 尘值 | 得尘 %d%% | 每尘金币 | 得尘 %d%% | 每尘金币 |" % [roundi(losses[0] * 100), roundi(losses[1] * 100)])
	lines.append("|---|---|---|---|---|---|---|")
	var best := [INF, INF]     # 两档里每点尘最便宜要几枚金币
	var ids: Array = sold.keys()
	ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	var any_inverted := false
	for id in ids:
		var d := items.get_def(id)
		var inst := ItemInstance.create(d, 0)
		if not Alchemy.can_dissolve(inst, rules):
			continue
		var v := Alchemy.dust_value(d)
		var row := "| %s | %d | %d" % [Names.of(d), int(sold[id]), v]
		for k in 2:
			var got := Alchemy.yield_of(v, 1, losses[k])
			var per := float(sold[id]) / float(got)
			best[k] = minf(best[k], per)
			any_inverted = any_inverted or per < 1.0
			row += " | %d | %.2f" % [got, per]
		lines.append(row + " |")
	lines.append("")
	lines.append("每点尘最便宜：%.2f 枚金币（%d%%）、%.2f 枚金币（%d%%）。" % [best[0], roundi(losses[0] * 100), best[1], roundi(losses[1] * 100)])
	lines.append("")
	lines.append("## 表二 · 配方全用尘补")
	lines.append("")
	lines.append("| 配方 | 能补的料 | 全尘 | 直接买料 | 买来炼再补 %d%% | 买来炼再补 %d%% | 倒挂 |" % [roundi(losses[0] * 100), roundi(losses[1] * 100)])
	lines.append("|---|---|---|---|---|---|---|")
	var line_hits: Array[String] = []     # 单看一样料：买来炼再补比直接买那样料便宜
	var recipes := SmithRecipeDef.load_all()
	recipes.sort_custom(func(a: SmithRecipeDef, b: SmithRecipeDef) -> bool: return String(a.id) < String(b.id))
	for r in recipes:
		var dust := 0
		var buy := 0
		var parts: Array[String] = []
		var buyable := true
		for key in r.inputs:
			var d := items.get_def(StringName(String(key)))
			if d == null or not Alchemy.input_dustable(d, rules):
				continue
			var n := int(r.inputs[key])
			dust += Alchemy.dust_value(d) * n
			parts.append("%s×%d" % [Names.of(d), n])
			if sold.has(d.id):
				buy += int(sold[d.id]) * n
			else:
				buyable = false
		for slot in r.slots():
			if not Alchemy.slot_dustable(slot, rules):
				continue
			var n := int(slot["count"])
			dust += Alchemy.slot_dust(slot, items) * n
			parts.append("%s≥%d×%d" % [String(slot["material"]), int(slot["min"]), n])
			var cheapest := -1
			for id in sold:
				if SmithRecipeDef.slot_fits(slot, items.get_def(id)) and (cheapest < 0 or int(sold[id]) < cheapest):
					cheapest = int(sold[id])
			if cheapest < 0:
				buyable = false
			else:
				buy += cheapest * n
				for k in 2:
					var via_line := ceili(float(Alchemy.slot_dust(slot, items)) * best[k])
					if via_line < cheapest:
						line_hits.append("%s 的「%s ≥%d」一格：尘 %d，折损 %d%% 下买来炼再补约 %d 枚金币，直接买最便宜的合格品 %d 枚" % [Names.of(items.get_def(r.output)),
							String(slot["material"]), int(slot["min"]), Alchemy.slot_dust(slot, items), roundi(losses[k] * 100), via_line, cheapest])
		if dust == 0:
			continue
		var via: Array[int] = []
		for k in 2:
			via.append(ceili(float(dust) * best[k]))
		var inverted := buyable and (via[0] < buy or via[1] < buy)
		any_inverted = any_inverted or inverted
		lines.append("| %s | %s | %d | %s | %d | %d | %s |" % [Names.of(items.get_def(r.output)), "、".join(PackedStringArray(parts)), dust,
			str(buy) if buyable else "买不全", via[0], via[1], "是" if inverted else ""])
	lines.append("")
	lines.append("## 表三 · 单看一格")
	lines.append("")
	if line_hits.is_empty():
		lines.append("没有。")
	for h in line_hits:
		lines.append("- " + h)
	lines.append("")
	lines.append("结论：%s" % ("整张配方有倒挂，见表二" if any_inverted else "整张配方没有倒挂") + ("；单格有 %d 处，见表三" % line_hits.size() if not line_hits.is_empty() else "；单格也没有"))
	var text := "\n".join(PackedStringArray(lines)) + "\n"
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print(text)
	finish()
