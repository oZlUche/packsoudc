## 道具的悬浮说明（084，作者定）：名、稀有度、标签、效果；武器多两行 —— 冷却、耗耐力与 DPS；有增益 / 受益槽的写槽的效果；
## 087：说明里的名词是**词条**（[Glossary]）：主文字只写词，侧边小窗写具体效果（[method describe_full]）。
## 包写包的格数与包体加成；信仰道具写按阶解锁的加成。
##
## 纯文字（BBCode），画是 [HoverTip] 的事。冷却与 DPS 从编译结果取：一件在棋盘上就按它此刻的邻接 / 包体加成算，
## 不在棋盘上（地上、战利品）就单独编一遍 —— 和真打出来的是同一份编译（4.2）
class_name ItemTooltip
extends RefCounted

## 稀有度的名字，下标即稀有度；颜色见 [ItemPainter.RARITY_COLORS]（白 / 绿 / 蓝 / 紫 / 金 / 红）
const RARITY_NAMES := ["普通", "优良", "稀有", "史诗", "传说", "神话"]

## 096（作者定）：信仰状态的探针 —— 局里由 [GameFlow] 接上，返回 `{"active": 激活的信仰 id, "tier": 阶, "points": 信力}`；
## 没接（基地、沙盒、测试）返回空字典。信仰加成的词条按它上色：**生效的白、没生效的灰**；没有探针一律按原色写
static var faith_probe: Callable = Callable()
const DIM_HEX := "8b93a1"


## 现在的信仰状态；没探针 / 不在局里是空
static func faith_status() -> Dictionary:
	if not faith_probe.is_valid():
		return {}
	var v: Variant = faith_probe.call()
	return v if v is Dictionary else {}


## 096：这一条信仰加成现在生效没有：这件的神正激活着，且按 mode 算出至少一份
static func bonus_lit(def: ItemDef, b: FaithBonus, status: Dictionary) -> bool:
	if status.is_empty() or def == null or b == null:
		return false
	var active := StringName(String(status.get("active", "")))
	if active == &"" or def.faith_tag() != FaithTags.PREFIX + String(active):
		return false
	return b.times_for(int(status.get("tier", 0)), int(status.get("points", 0))) > 0


## 107（作者定）：这件道具的信仰现在是不是激活的 —— 信仰相关的行按它上色（亮 = 生效、灰 = 休眠或还没激活）。
## 局外（没探针）一律按没激活算，局外本来就不上色
static func faith_lit(def: ItemDef, status: Dictionary) -> bool:
	if status.is_empty() or def == null or not def.has_faith():
		return false
	var active := StringName(String(status.get("active", "")))
	return active != &"" and def.faith_tag() == FaithTags.PREFIX + String(active)


## [param board] 给了且道具在上面就按棋盘编译；否则单独编。只要主文字；词条见 [method describe_full]
static func describe(inst: ItemInstance, board: GridInventory = null) -> String:
	return String(describe_full(inst, board)["text"])


## 087：主文字 + 侧边词条。返回 `{"text": BBCode（词条已标色）, "terms": [{name, text}]}`：
## 主文字里指向名词的地方只写名词（「开战时血怒」不写「伤害 +10%」），每个名词在 `terms` 里有一条具体说明，悬浮窗在侧边一个一个开小窗。
## 词条 = 固定词条（[Glossary.TERMS]）+ 这件道具会施加的 buff（说明按定义生成）
static func describe_full(inst: ItemInstance, board: GridInventory = null) -> Dictionary:
	if inst == null or inst.def == null:
		return {"text": "", "terms": []}
	var def := inst.def
	var lines: Array[String] = []
	var rc := ItemPainter.rarity_color(def).to_html(false)
	lines.append("[color=#%s][b]%s[/b][/color]　%s　%d 格　值 %d　重 %d" % [rc, Names.of(def), rarity_name(def.rarity), def.cell_count(), ItemValue.of(def), ItemWeight.of(def)])     # 129：重
	var desc := Names.description_of(def)     # 104：说明里的 {字段} 按这件道具自己的字段填
	if desc != "":
		lines.append("[color=#8b93a1]%s[/color]" % desc)
	var shown_tags := TagRegistry.shown(def.tags)     # 107 后续（作者定）：内部标签（快攻 / 重击 / 重型）不给玩家看
	if not shown_tags.is_empty():
		lines.append("[color=#8b93a1]标签：%s[/color]" % "、".join(_names(shown_tags)))     # 096：标签按当前语言显示名字
	if def.is_bag:
		var size := def.shape.size_rotated(0) if def.shape != null else Vector2i.ZERO
		lines.append("包：%d×%d，放进去的东西才参战" % [size.x, size.y] + ("；只收 %s" % "、".join(_names(def.bag_accept_tags)) if not def.bag_accept_tags.is_empty() else ""))
		for m in def.bag_mods:
			lines.append("　包里的东西：%s" % Glossary.mod_text(m))
	var spec := spec_for(inst, board)
	var compiled: CompiledItem = spec.item_of(inst.uid) if spec != null else null
	if compiled == null and spec != null and not spec.items.is_empty():
		compiled = spec.items[0]     # 单独编的那块棋盘上只有它的副本
	var weapon := def.tags.has(&"weapon")
	# 087（作者定）：没有「主武器」—— 包里每一件武器都各自出手，这里每件都按自己的规则写
	if def.combat != null:
		for key in def.combat.base_stats:
			lines.append("%s %s" % [Glossary.stat_name(StringName(String(key))), str(def.combat.base_stats[key])])
		for r in def.combat.rules:
			var rule := r as AbilityRule
			if rule == null:
				continue
			var line := Glossary.rule_text(rule)
			if weapon and rule.cadence is CooldownCadence and compiled != null and compiled.stats != null:
				var hz := rule.cadence.estimated_hz(compiled.stats)
				if hz > 0.0:
					line = line.replace("每 %.1f 秒" % (rule.cadence as CooldownCadence).seconds, "冷却 %.1f 秒" % (1.0 / hz))
			var st := _stamina_of(rule, compiled.stats if compiled != null else null)
			if st > 0.0:
				line += "　耗耐力 %.0f" % st     # 087（作者定）：武器要写耐力消耗
			lines.append(line)
	# 108（作者定）：别人挂到我身上的规则（邻居的增益规则、信仰附魔）—— 只在棋盘上才有，来源名放句尾
	var attached_buffs := {}
	if compiled != null:
		for a in compiled.attached:
			var idx := int(a["rule_index"])
			if idx < 0 or idx >= compiled.rules.size():
				continue
			var ar := compiled.rules[idx] as AbilityRule
			lines.append("[color=#%s]附加：%s ← %s[/color]" % [UiPalette.GRANT.to_html(false), Glossary.rule_text(ar), origin_name(StringName(String(a["origin"])), board)])
			Glossary.buffs_in_rules([ar], attached_buffs)
	if weapon and compiled != null and spec != null:
		lines.append("[color=#f0ad4e]约 %.1f DPS[/color]" % spec.estimated_dps_of(compiled))
	for e in def.effects:
		var d: String = e.describe() if e != null and e.has_method("describe") else ""
		lines.append("效果：%s" % (d if d != "" else _type_name(e)))
	if def.adjacency != null:
		var adj := def.adjacency
		if not adj.grant_cells.is_empty():
			var gives: Array[String] = []
			if not adj.grant_mods.is_empty() or adj.grant_rules.is_empty():
				gives.append(_mods(adj.grant_mods))
			for gr in adj.grant_rules:     # 108：给邻居挂的规则
				if gr != null:
					gives.append("附加：%s" % Glossary.rule_text(gr))
			lines.append("[color=#%s]增益槽 ×%d[/color]：给站在那儿的邻居%s %s" % [UiPalette.GRANT.to_html(false), adj.grant_cells.size(),
				("（%s）" % "、".join(_names(adj.grant_filter))) if not adj.grant_filter.is_empty() else "", "；".join(gives)])
		if not adj.receive_cells.is_empty():
			lines.append("[color=#%s]受益槽 ×%d[/color]：每点亮一格%s，自己 %s" % [UiPalette.RECEIVE.to_html(false), adj.receive_cells.size(),
				("（%s）" % "、".join(_names(adj.receive_filter))) if not adj.receive_filter.is_empty() else "", _mods(adj.receive_mods)])
	var status := faith_status() if def.has_faith() else {}
	for fb in def.faith_bonuses:
		var b := fb as FaithBonus
		if b != null:
			var line := "信力 " + b.describe()
			# 096（作者定）：局里按状态上色 —— 生效的白、没生效（没激活 / 阶不够 / 别的神）的灰；局外原色
			if not status.is_empty():
				line = "[color=#%s]%s[/color]" % [UiPalette.FG.to_html(false) if bonus_lit(def, b, status) else DIM_HEX, line]
			lines.append(line)
	# 107（作者定）：不再写「信仰道具：别的信仰激活时休眠…」那一行，也不写「—— 现在休眠 / 还没激活」的状态尾巴 ——
	# **状态就是颜色**：这件道具的信仰激活着就亮色，休眠或还没激活就全灰
	if def.is_anchor():
		# 099（作者定）：切信仰不进菜单 —— 右键一下，或者在棋盘里把它重新落下
		var line := "信物：%s" % ("当前信仰" if faith_lit(def, status) else "右键：奉为主信仰")
		lines.append("[color=#%s]%s[/color]" % [UiPalette.FG.to_html(false) if faith_lit(def, status) else DIM_HEX, line])
	if def.set_id != &"":
		lines.append("[color=#8b93a1]套装：%s[/color]" % String(def.set_id))
	var text := "\n".join(lines)
	# 词条：这件道具会施加的 buff（名字 → 按定义生成的说明）+ 固定词条
	var extra := Glossary.tag_terms(shown_tags)     # 096：登记了说明的标签也是词条
	var item_buffs := Glossary.buffs_in_item(def)
	item_buffs.merge(attached_buffs)     # 108：挂到我身上的规则施加的 buff（弓身上的【中毒】）也进侧窗
	for id in item_buffs:
		var bd: BuffDef = item_buffs[id]
		if Names.of(bd) != "":
			extra[Names.of(bd)] = Glossary.describe_buff(bd)
	var terms := Glossary.terms_in(text, extra)
	return {"text": Glossary.mark(text, terms), "terms": terms}


## 这条规则每次出手花多少耐力（面板数或属性值）
static func _stamina_of(rule: AbilityRule, stats: StatSet) -> float:
	var total := 0.0
	for c in rule.costs:
		var rc := c as ResourceCost
		if rc == null or rc.resource_key != BattleStats.RES_STAMINA:
			continue
		if rc.amount_stat != &"" and stats != null and stats.has(rc.amount_stat):
			total += StatMath.to_float(stats.total_of(rc.amount_stat))
		else:
			total += rc.amount
	return total


## 108：附加规则的来源给人看 —— `faith:<id>` 写神名，道具 id 写道具名（在棋盘上找得到就用它的名字，否则原词）
static func origin_name(origin: StringName, board: GridInventory = null) -> String:
	var fid := FaithTags.id_of_tag(origin)
	if fid != &"":
		var god: FaithDef = FaithDef.load_all().get(fid, null)
		return Names.of(god) if god != null else String(fid)
	if board != null:
		for inst in board.items():
			var item := inst as ItemInstance
			if item.def != null and item.def.id == origin:
				return Names.of(item.def)
	return String(origin)


static func rarity_name(rarity: int) -> String:
	return RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)]


## 这件道具所在的编译结果：在 [param board] 上就编整块棋盘；否则单独编一遍（放在一块刚好装下它的棋盘上，副本是那块棋盘上唯一的一件）
static func spec_for(inst: ItemInstance, board: GridInventory) -> CombatantSpec:
	if inst == null or inst.def == null or inst.def.combat == null:
		return null
	if board != null and board.has_item(inst.uid):
		return BattleCompiler.compile_board(board)
	var size := inst.def.shape.size_rotated(0) if inst.def.shape != null else Vector2i.ONE
	var scratch := GridInventory.new(size, 0, false)
	var copy := ItemInstance.create(inst.def, 0)
	if not scratch.place(copy, Vector2i.ZERO, 0):
		return null
	return BattleCompiler.compile_board(scratch)


## 这件道具现在的编译结果（一件）
static func compiled_for(inst: ItemInstance, board: GridInventory) -> CompiledItem:
	var spec := spec_for(inst, board)
	if spec == null or spec.items.is_empty():
		return null
	var mine := spec.item_of(inst.uid)
	return mine if mine != null else spec.items[0]


static func _mods(mods: Array) -> String:
	return Glossary.mods_text(mods) if not mods.is_empty() else "无"


## 096：标签给人看（数据里的名字，按当前语言）
static func _names(tags: Array) -> Array[String]:
	var out: Array[String] = []
	for t in tags:
		out.append(Glossary.tag_name(t))
	return out




static func _type_name(obj: Object) -> String:
	return String(ContentSchema.registry_name_of(obj)) if obj != null else "?"
