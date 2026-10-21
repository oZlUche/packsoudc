## 一种路线风格（架构文档 5.4.2）。
##
## 路线不是从生成好的图里事后找出来的 —— 每个出生点配一种风格，先铺路线再长地图。
## 风格之间不是「难度相同」，而是**风险与收益各在自己的档位上，且性价比相当**。
class_name RouteStyle
extends Resource

## "combat" / "search" / "mixed" …
@export var id: StringName = &""

## 该路线**独占**的节点里各类型的份额（比例，不必加到 1）。
## 偏战斗：`{"battle": 5, "elite": 1, "event": 1}`
## 偏搜索：`{"search": 4, "event": 2, "battle": 1}`
## [b]M3-3c 才用到。[/b]
@export var mix: Dictionary = {}

## 类型 → 在这条路线独占节点里至少占几成（0～1）。偏搜索的路线 `{"search": 0.8}`：
## 校准再怎么换，搜索点的份额不能掉到八成以下。分母不算出生点、撤离点、休息区、商店这些
## 别的步骤放的固定点。[b]M3-3c 用。[/b]
@export var min_share: Dictionary = {}

## 这条路线的风险分总和该落在哪个区间（相对全图平均）。[b]M3-3c 才用到。[/b]
@export var risk_band: Vector2 = Vector2(0.8, 1.2)

## 同上，收益分。低风险配低收益、高风险配高收益 —— 两个区间一起决定风格。
## [b]M3-3c 才用到。[/b]
@export var reward_band: Vector2 = Vector2(0.8, 1.2)

## 路线的尽头。
##
## [code]&"core"[/code] 走到核心打 BOSS；[code]&"extract"[/code] 走到撤离环间（偶数环取内侧那环），
## 沿那一环朝相邻路线横着走一段弧，弧的最后一个点定为撤离点、和相邻路线共用（报告 053）——
## **偏搜索的路线可以不打最终敌人，搜够了就从中间走**。想打还是能打：撤离点之后就是换乘区。
## 没有撤离环间的规模（大型图，两道还没定）仍在核心前一环结束。
@export var ends_at: StringName = &"core"

## 高危区能不能从这条路线上岔出来。偏搜索的路线 false（报告 053 第三条）：
## 它让出了内圈，高危区长在别的路线旁边。放进数据，而不是在生成器里认 ends_at
@export var spawns_zones: bool = true


## 作者 2026-10-19：挑出生点时给玩家看的路线名与一句特点（按风格 id；只说特点，不说尽头）
const PLAYER_TEXT := {
	&"combat": {"name": "战斗", "text": "沿途多是战斗和精英，最危险，战利品也最多。",
		"en": {"name": "Combat", "text": "Mostly battles and elites along the way: the most dangerous route, with the most loot."}},
	&"mixed": {"name": "常规", "text": "战斗、搜索、事件大致各占三分之一，风险和收获都适中。",
		"en": {"name": "Balanced", "text": "Roughly a third each of battles, searches and events: moderate risk, moderate reward."}},
	&"search": {"name": "搜索", "text": "沿途大多是搜索点，战斗很少，危险低，收获也少。",
		"en": {"name": "Search", "text": "Mostly search spots along the way and few battles: low danger, smaller rewards."}},
}


## 风格 id → 给玩家看的 {name, text}（按 UiText.lang 取，没写的语言回落中文）；没登记的风格给空
static func player_text(style_id: StringName) -> Dictionary:
	var e: Dictionary = PLAYER_TEXT.get(style_id, {})
	if e.is_empty():
		return {}
	var loc: Dictionary = e.get(UiText.lang, {})
	return {"name": String(loc.get("name", e["name"])), "text": String(loc.get("text", e["text"]))}


func is_core_route() -> bool:
	return ends_at != &"extract"
