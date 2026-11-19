## 信仰重构 C（交接方案 §6.4）：大地之神的「空间承托」—— 奉神即有（tier 0）。编译期按摆放算承托（[EarthSupport.layers]），
## 按 uid 给大件放修饰（[member CompileInput.item_mods]），再放一条开战规则（写战记；三阶给护甲）。
## 信仰窗一阶一行：[member part] 0 = 基础（只有它编译），1 = 中件也算，3 = 开战护甲
class_name EarthSupportPerk
extends FaithPerk

@export var part: int = 0
@export var min_cells: int = 5
## 一阶起：这么多格就算大件
@export var min_cells_t1: int = 4
@export var max_layers: int = 2
## 攻击型大件每层耐力消耗 −N%
@export var stamina_percent: int = 4
## 防御型大件每层格挡 / 护甲上限 +N%
@export var defense_percent: int = 4
## 三阶：开战每件承托着的大件给最大生命 N% 的护甲，合计不超过 [member armor_cap]%
@export var armor_percent: int = 2
@export var armor_cap: int = 10


func compile_into(input: CompileInput, board: GridInventory, run: RunState) -> void:
	if part != 0 or board == null:
		return
	var at_tier := maxi(0, run.active_faith_tier()) if run != null else 0
	var got := EarthSupport.layers(board, FaithState.board_tag(board), min_cells_t1 if at_tier >= 1 else min_cells, max_layers)
	for uid in got:
		var mods := mods_for(board.get_item(int(uid)).def, int(got[uid]))
		if not mods.is_empty():
			input.item_mods[uid] = mods
	var trig := FaithMechanicTrigger.new()
	trig.events = [BattleEvent.BATTLE_START] as Array[StringName]
	var eff := EarthSupport.new()
	eff.supported = got.size()
	eff.armor_percent = armor_percent if at_tier >= 3 else 0
	eff.armor_cap = armor_cap
	var rule := AbilityRule.new()
	rule.trigger = trig
	rule.cadence = EffectRegistry.instantiate(&"cadence", &"always")
	rule.effects.append(eff)
	input.rules.append(rule)


## [param layers] 层承托给这件的修饰
func mods_for(def: ItemDef, layers: int) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	match EarthSupport.role_of(def):
		&"attack":
			out.append(StatModifier.make(BattleStats.STAMINA_COST, StatModifier.Mode.MULT, -float(stamina_percent * layers)))
		&"defense":
			var key := BattleStats.BLOCK if def.tags.has(&"shield") else BattleStats.MAX_ARMOR
			out.append(StatModifier.make(key, StatModifier.Mode.MULT, float(defense_percent * layers)))
	return out


func _summary() -> String:
	match part:
		1:
			return UiText.t("perk.earth_1") % min_cells_t1
		3:
			return UiText.t("perk.earth_3") % [armor_percent, armor_cap]
	return UiText.t("perk.earth") % [min_cells, max_layers, stamina_percent, defense_percent]


func battle_note(_run: RunState) -> String:
	return _summary() if part == 0 else ""
