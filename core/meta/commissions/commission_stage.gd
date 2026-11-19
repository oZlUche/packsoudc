## 336（W0）：一份委托的一步。每一步只认一种真实发生的事（[member goal]，[constant Commissions.GOALS]），不靠界面按钮自报完成。
##
## 在哪完成（[member where]）决定这一步怎么并进局外：
## - `camp`：营地当场办完（基地里打造、交货、核对），立刻记账；
## - `field`：局内现场交付，交了就算，之后败退也算（和配方发现一样，[method Commissions.merge_run]）；
## - `carry`：要带回营地 —— 只在本人撤离成功时算；[member entrust_ok] 为真时托付成功也算。没带回这一步重做，已归档的步骤保留
class_name CommissionStage
extends Resource

const CAMP := &"camp"
const FIELD := &"field"
const CARRY := &"carry"
const WHERES: Array[StringName] = [CAMP, FIELD, CARRY]

## 目标种类（[constant Commissions.GOALS] 里的键）
@export var goal: StringName = &""
## 要做几次（同一处 / 同一件只记一次）
@export var count: int = 1
## 目标的参数（比如 `{"kind": "free"}` = 只认免费撤离点）
@export var params: Dictionary = {}
## camp / field / carry
@export var where: StringName = FIELD
## 带回类：托付成功算不算数
@export var entrust_ok: bool = false
## 出征时发进背包的任务道具（带 `commission` 标签；空 = 不发）
@export var item: StringName = &""
## 任务卡上「做什么」那一句（候选文本，待作者过目）
@export var text: String = ""
@export var texts: Dictionary = {}
