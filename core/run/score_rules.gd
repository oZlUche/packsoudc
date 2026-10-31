## 269（作者 2026-10-31 11:50 定 A）：一局的计分 —— 总分 = （战利 + 战绩 + 探索）× 难度系数，向下取整。
## 战利 = 带出价值 + 保险箱价值（战败只有保险箱）；战绩 = 击败的普通 / 精英 / 首领各记一笔（打输不扣）；
## 探索 = 走过的点、翻过的搜索点、合成、图鉴新点亮各记一笔（步数不算）；难度系数 = 1 + [member difficulty_step] × 难度档。
##
## 走内容管线：`data/authoring/base_rules/score.json` → `data/base_rules/score.tres`（[method load_rules]）。数都在 json 里，作者改 json 不动代码；
## 默认全是 0（json 里写什么算什么）。`extract_bonus` 0、`loot_counts` true 是默认，json 里不写（导出时省掉），要改再加上
class_name ScoreRules
extends Resource

const ID := &"score"

@export var id: StringName = &""
@export var display_name: String = ""
## 击败一只记几分：normal / elite / boss
@export var kill: Dictionary = {}
## 探索一项记几分：visited 走过的点 / search 翻过的搜索点 / craft 合成一次 / lit 图鉴新点亮一件
@export var explore: Dictionary = {}
## 每档难度加几成（普通 0 档 ×1）
@export var difficulty_step: float = 0.0
## 撤离额外记几分（A 不用，0）
@export var extract_bonus: int = 0
## 带出价值算不算分（A 算）
@export var loot_counts: bool = true

static var _rules: ScoreRules = null


## 资产里的计分规矩（没导入时用默认）
static func load_rules() -> ScoreRules:
	if _rules == null:
		_rules = ContentPaths.load_asset("base_rules", String(ID)) as ScoreRules
		if _rules == null:
			_rules = ScoreRules.new()
	return _rules


func kill_points(key: String) -> int:
	return int(kill.get(key, 0))


func explore_points(key: String) -> int:
	return int(explore.get(key, 0))


## 难度系数（[param level] = [member DifficultyDef.level]）
func mult(level: int) -> float:
	return 1.0 + difficulty_step * float(maxi(0, level))


## 三项加起来乘系数，向下取整
func total(loot: int, battle: int, explore_sum: int, level: int) -> int:
	return floori(float(loot + battle + explore_sum) * mult(level) + 0.0001)
