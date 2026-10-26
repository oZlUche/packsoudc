## 256（马库斯的军功牌）：每打赢一场，棋盘上靠军功长的道具（[member GrowthProfile.fuel] = honor）记军功点 ——
## 点数按这一场的类型查道具自己的表（普通 1、精英 3、核心 5）；逃跑、退回、溜走没打，不记。点数和阶都记在实例上
## （`state.honor` / `state.growth_stage`，[GrowthProfile.add_honor]），跟着这一局的存档走，不进局外：每局从铜起。
##
## 101 的插件模型：只订阅 [signal NodeEvents.battle_finished]，自己不存东西
class_name HonorModule
extends RunModule

const ID := &"honor"

## 这一场有几件升了阶：{uid: 新阶}
signal ranked_up(stages: Dictionary)


static func of(run: RunState) -> HonorModule:
	return run.module(ID) as HonorModule if run != null else null


func id() -> StringName:
	return ID


func describe() -> String:
	return "军功：打赢一场，军功牌记点、攒够了升阶"


func install(run: RunState) -> void:
	if run == null or run.events == null:
		return
	_run = run
	if not run.events.battle_finished.is_connected(_on_battle_finished):
		run.events.battle_finished.connect(_on_battle_finished)


func _on_battle_finished(_node: MapNode, _result: BattleResult, won: bool) -> void:
	if not won or _run.board == null:
		return
	var type := StringName(String(_run.events.last_battle.get("type", "battle")))
	var up := {}
	var any := false
	for raw in _run.board.items():
		var inst := raw as ItemInstance
		if inst == null or inst.def == null or inst.def.growth == null or not inst.def.growth.runs_on_honor():
			continue
		var pts := inst.def.growth.honor_for(type)
		if pts <= 0:
			continue
		any = true
		if GrowthProfile.add_honor(inst, pts):
			up[inst.uid] = GrowthProfile.stage_of(inst)
	if not any:
		return
	_run.board.changed.emit()     # 角标的数、名字前缀、增益圈都变了：棋盘重画
	if not up.is_empty():
		ranked_up.emit(up)
