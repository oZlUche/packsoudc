## 成就（091 第十节，作者定）：完成了记进局外存档；完成给的**解锁 id** 开道具 / 地图 / 难度（它们各自的 `requires_unlock` 引用同一个 id）；
## 成就页写着**解锁途径**（[member description]）与进度，能按「全部 / 已解锁 / 未解锁」切。
##
## 条件是「局外的某个数达到多少」（[member kind] + [member amount] / [member target]），看的全是 [MetaState] 里已有或顺手多记的数；
## 什么时候算由 [method GameFlow.check_achievements] 定（一局结算之后、读档之后）。「全部解锁」开着时成就不计（10.2 第 4 条）。
## 走内容管线：`data/authoring/achievements/*.json` → `data/achievements/*.tres`
class_name AchievementDef
extends Resource

## 条件种类 → 看局外的哪个数
const KINDS: Array[StringName] = [&"extractions", &"runs", &"deaths", &"best_value", &"score", &"funds", &"codex_count",
	&"codex_has", &"chapter_extractions", &"boss_kills", &"battles_won", &"unlock", &"keepsake"]
## 要写 target 的种类
const TARGETED: Array[StringName] = [&"codex_has", &"chapter_extractions", &"unlock", &"keepsake"]
## 只看有没有、不看次数的种类（进度 0 / 1）
const BINARY: Array[StringName] = [&"codex_has", &"unlock", &"keepsake"]

@export var id: StringName = &""
@export var display_name: String = ""
## 088：别的语言的名字，`{"en": "..."}`；界面用 [method Names.of] 取
@export var display_names: Dictionary = {}
## 解锁途径（成就页写的那句：怎么做才能完成）
@export_multiline var description: String = ""
## 221 F5: description in other languages, {"en": ...}
@export var descriptions: Dictionary = {}
## 没完成前只显示「？？？」，途径也藏（彩蛋）
@export var hidden: bool = false
## 成就页的先后（小的在前）
@export var order: int = 0
## 条件种类（见 KINDS）：撤离次数 / 局数 / 战败次数 / 单局最高价值 / 累计价值 / 攒的钱 / 图鉴点亮数 / 图鉴里有某件 /
## 某章撤离次数 / 击败核心次数 / 打赢场数 / 有某个解锁 / 有某件特殊道具
@export var kind: StringName = &"extractions"
## 要达到的数（BINARY 种类不看）
@export var amount: int = 1
## 条件的对象：codex_has 的道具 id、chapter_extractions 的章节 id、unlock 的解锁 id、keepsake 的特殊道具 id
@export var target: StringName = &""
## 完成给的局外解锁 id：道具 / 章节 / 难度按各自的 requires_unlock 引用；空 = 只是一枚徽章
@export var grants: Array[StringName] = []


## 要达到的数
func goal() -> int:
	return 1 if BINARY.has(kind) else maxi(1, amount)


## 现在的进度（局外的数）
func progress(meta: MetaState) -> int:
	if meta == null:
		return 0
	match kind:
		&"extractions":
			return meta.extractions
		&"runs":
			return meta.runs
		&"deaths":
			return meta.deaths
		&"best_value":
			return meta.best_value
		&"score":
			return meta.score
		&"funds":
			return meta.funds
		&"codex_count":
			return meta.codex.size()
		&"codex_has":
			return 1 if meta.codex_lit(target) else 0
		&"chapter_extractions":
			return meta.chapter_extractions_of(target)
		&"boss_kills":
			return meta.boss_kills
		&"battles_won":
			return meta.battles_won
		&"unlock":
			return 1 if meta.has_unlock(target) else 0
		&"keepsake":
			return 1 if meta.has_keepsake(target) else 0
	return 0


func is_met(meta: MetaState) -> bool:
	return progress(meta) >= goal()


## 成就页上进度那一段：「3 / 5」；只看有没有的种类写「未 / 已」由界面定
func progress_text(meta: MetaState) -> String:
	return "%d / %d" % [mini(progress(meta), goal()), goal()]
