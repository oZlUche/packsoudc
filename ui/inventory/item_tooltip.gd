## 道具的悬浮说明（084，作者定）：名、稀有度、标签、效果；武器多两行 —— 冷却与 DPS；有增益 / 受益槽的写槽的效果；
## 包写包的格数与包体加成；信仰道具写按阶解锁的加成。
##
## 纯文字（BBCode），画是 [HoverTip] 的事。冷却与 DPS 从编译结果取：一件在棋盘上就按它此刻的邻接 / 包体加成算，
## 不在棋盘上（暂存区、战利品）就单独编一遍 —— 和真打出来的是同一份编译（4.2）
class_name ItemTooltip
extends RefCounted

const RARITY_NAMES := ["普通", "优良", "稀有", "史诗", "传说"]
const TRIGGER_NAMES := {"on_schedule": "自发", "on_battle_start": "开战时", "on_item_fired": "出手时", "on_damage": "受伤时",
	"on_stacks_at_least": "层数够时", "on_resource_below": "资源低于时", "on_status_applied": "上状态时", "on_status_expired": "状态到期时"}


## [param board] 给了且道具在上面就按棋盘编译；否则单独编
static func describe(inst: ItemInstance, board: GridInventory = null) -> String:
	if inst == null or inst.def == null:
		return ""
	var def := inst.def
	var lines: Array[String] = []
	var rc := ItemPainter.rarity_color(def).to_html(false)
	lines.append("[color=#%s][b]%s[/b][/color]　%s　%d 格　值 %d" % [rc, def.display_name, rarity_name(def.rarity), def.shape.cell_count() if def.shape != null else 0, ItemValue.of(def)])
	if not def.tags.is_empty():
		var tags: Array[String] = []
		for t in def.tags:
			tags.append(String(t))
		lines.append("[color=#8b93a1]标签：%s[/color]" % "、".join(tags))
	if def.is_bag:
		var size := def.shape.size_rotated(0) if def.shape != null else Vector2i.ZERO
		lines.append("包：%d×%d，放进去的东西才参战" % [size.x, size.y] + ("；只收 %s" % "、".join(_names(def.bag_accept_tags)) if not def.bag_accept_tags.is_empty() else ""))
		for m in def.bag_mods:
			lines.append("　包里的东西：%s" % str(m))
	var compiled := compiled_for(inst, board)
	var weapon := def.tags.has(&"weapon")
	if def.combat != null:
		for key in def.combat.base_stats:
			lines.append("%s %s" % [_stat_name(StringName(String(key))), str(def.combat.base_stats[key])])
		for r in def.combat.rules:
			var rule := r as AbilityRule
			if rule == null:
				continue
			var bits: Array[String] = []
			for e in rule.effects:
				var d := (e as Effect).describe() if e != null else ""
				bits.append(d if d != "" else _type_name(e))
			var when := _type_name(rule.trigger) if rule.trigger != null else ""
			var line := "%s%s" % [("[%s] " % TRIGGER_NAMES.get(when, when)) if when != "" else "", "，".join(bits) if not bits.is_empty() else "（没有效果）"]
			if weapon and rule.cadence is CooldownCadence:
				var secs := (rule.cadence as CooldownCadence).seconds
				if compiled != null and compiled.stats != null:
					var hz := rule.cadence.estimated_hz(compiled.stats)
					if hz > 0.0:
						secs = 1.0 / hz
				line += "　冷却 %.1f 秒" % secs
			elif not weapon and rule.cadence is CooldownCadence:
				line += "（每 %.1f 秒）" % (rule.cadence as CooldownCadence).seconds
			lines.append(line)
	if weapon and compiled != null:
		lines.append("[color=#f0ad4e]约 %.1f DPS[/color]" % compiled.estimated_dps())
	for e in def.effects:
		var d := (e as Effect).describe() if e != null else ""
		lines.append("效果：%s" % (d if d != "" else _type_name(e)))
	if def.adjacency != null:
		var adj := def.adjacency
		if not adj.grant_cells.is_empty():
			lines.append("[color=#%s]增益槽 ×%d[/color]：给站在那儿的邻居%s %s" % [UiPalette.GRANT.to_html(false), adj.grant_cells.size(),
				("（%s）" % "、".join(_names(adj.grant_filter))) if not adj.grant_filter.is_empty() else "", _mods(adj.grant_mods)])
		if not adj.receive_cells.is_empty():
			lines.append("[color=#%s]受益槽 ×%d[/color]：每点亮一格%s，自己 %s" % [UiPalette.RECEIVE.to_html(false), adj.receive_cells.size(),
				("（%s）" % "、".join(_names(adj.receive_filter))) if not adj.receive_filter.is_empty() else "", _mods(adj.receive_mods)])
	for fb in def.faith_bonuses:
		var b := fb as FaithBonus
		if b != null:
			lines.append("信力第 %d 阶：%s%s" % [b.tier, _mods(b.mods), ("　" + b.note) if b.note != "" else ""])
	if def.set_id != &"":
		lines.append("[color=#8b93a1]套装：%s[/color]" % String(def.set_id))
	return "\n".join(lines)


static func rarity_name(rarity: int) -> String:
	return RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)]


## 这件道具现在的编译结果：在 [param board] 上就取棋盘的；否则单独编一遍（放在一块刚好装下它的棋盘上）
static func compiled_for(inst: ItemInstance, board: GridInventory) -> CompiledItem:
	if inst == null or inst.def == null or inst.def.combat == null:
		return null
	if board != null and board.has_item(inst.uid):
		return BattleCompiler.compile(board).item_of(inst.uid)
	var size := inst.def.shape.size_rotated(0) if inst.def.shape != null else Vector2i.ONE
	var scratch := GridInventory.new(size, 0, false)
	var copy := ItemInstance.create(inst.def, 0)
	if not scratch.place(copy, Vector2i.ZERO, 0):
		return null
	return BattleCompiler.compile(scratch).item_of(copy.uid)


static func _mods(mods: Array) -> String:
	var out: Array[String] = []
	for m in mods:
		out.append(str(m))
	return "、".join(out) if not out.is_empty() else "无"


static func _names(tags: Array) -> Array[String]:
	var out: Array[String] = []
	for t in tags:
		out.append(String(t))
	return out


static func _stat_name(key: StringName) -> String:
	match key:
		BattleStats.DAMAGE:
			return "伤害"
		BattleStats.ARMOR:
			return "护甲"
		BattleStats.MAX_HP:
			return "生命"
		BattleStats.MAX_STAMINA:
			return "耐力"
		BattleStats.HASTE:
			return "急速"
		BattleStats.COOLDOWN:
			return "冷却"
		BattleStats.REGEN_STAMINA:
			return "每秒回耐力"
		BattleStats.REGEN_HP:
			return "每秒回血"
		BattleStats.MAX_SHIELD:
			return "护盾（开战时满）"
		BattleStats.MAX_MANA:
			return "法力"
	return String(key)


static func _type_name(obj: Object) -> String:
	return String(ContentExporter._registry_name_of(obj)) if obj != null else "?"
