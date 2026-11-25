extends SceneTree
## 游戏测试 v8.62（PR #928）：13 把匕首按稀有度的暴击伤害。逐把：数据、编进战斗后的数、悬浮里写的（中文 / 英文）
const WANT := [1.6, 1.7, 1.8, 1.9, 2.0, 2.1]

func _init() -> void:
	var c := TestSupport.load_content("free_mode")
	var ids := []
	for i in c.items.ids(true):
		var d0 := c.items.get_def(StringName(i))
		if d0 != null and d0.has_tag(&"dagger"): ids.append(d0)
	ids.sort_custom(func(a, b): return a.rarity < b.rarity or (a.rarity == b.rarity and String(a.id) < String(b.id)))
	print("DG928 带 dagger 标签的 %d 件" % ids.size())
	for d in ids:
		var def := d as ItemDef
		var raw = def.combat.base_stats.get("crit_damage", null) if def.combat != null else null
		var board := GridInventory.new(Vector2i(6, 6))
		var inst := TestSupport.put(board, def)
		var spec := BattleCompiler.compile(board, CompileInput.new())
		var ci = spec.item_of(inst.uid)
		var cd := StatMath.to_float(ci.stats.total_of(BattleStats.CRIT_DAMAGE)) if ci != null else -1.0
		var cc := StatMath.to_float(ci.stats.total_of(BattleStats.CRIT_CHANCE)) if ci != null else -1.0
		var want: float = WANT[clampi(def.rarity, 0, 5)]
		var tips := []
		for lang in ["zh", "en"]:
			UiText.lang = lang
			var t := ItemTooltip.describe(inst, board)
			var lines := []
			for ln in t.split("\n"):
				if ln.contains("暴击") or ln.to_lower().contains("crit"): lines.append(ln.strip_edges())
			tips.append("%s：%s" % [lang, " / ".join(lines) if not lines.is_empty() else "（没写暴击）"])
		UiText.lang = "zh"
		print("DG928 %s（%s，稀有度 %d）：数据 %s；编进战斗 暴伤 %.2f、暴击率 %.2f；该是 %.1f → %s" % [String(def.id), Names.of(def), def.rarity, str(raw), cd, cc, want, "对" if is_equal_approx(cd, want) else "！不对"])
		for t in tips: print("DG928 　　悬浮 %s" % t.left(400))
	quit(0)
