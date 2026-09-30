## 一个信仰体系（第 8 阶段 8-4，报告 081；作者定）：诸神里的一位、或将来的新教。内容种类 `faiths`。
##
## 信仰是道具的一级分类，**靠标签**（作者定的机制）：信仰道具都带 `faith` 标签，再带一个「信仰对象」标签 `faith:<id>`
## （新教也是 `faith` + 自己的 `faith:church`）。本类只提供名字、阵营、说明与校验；机制在 [FaithState]，一个字段都不认具体的神。
## 「不信者」现在只是「没激活任何信仰」这个状态，将来加专门体系时同样走标签。
class_name FaithDef
extends Resource

## 信仰对象标签的前缀：`faith:violence`
const TAG_PREFIX := "faith:"

enum Camp { GODS, CHURCH }

@export var id: StringName = &""
@export var display_name: String = ""
## 088：别的语言的名字，`{"en": "Knife"}`；界面用 [method Names.of] 取（当前语言没有就用 display_name）
@export var display_names: Dictionary = {}
## 诸神信仰 / 新教（皇帝扶持的一神教，与诸神互斥 —— 互斥由「只激活一个」天然成立）
@export var camp: Camp = Camp.GODS
## 信仰的对象（神的名字），给文字用
@export var god: String = ""
@export_multiline var description: String = ""
## 信力（报告 082）：过了几道阈值就是第几阶（非递减、正数）；信仰道具上按阶解锁的功能见 [ItemDef.faith_bonuses]
@export var thresholds: Array[int] = []
## 攒信力的行为（[FaithDeed] 构件）：这个信仰认哪些事、各给几点
@export var deeds: Array[FaithDeed] = []
## 093（作者表）：献祭品 —— 满足哪些条件的道具能献到神坛上换信力，各换多少；一件满足几条结算几次
@export var offerings: Array[OfferingRule] = []
## 093（作者表）：信仰级的效果（[FaithPerk] 构件），各自写第几阶起生效
@export var perks: Array[FaithPerk] = []
## 095（作者定）：赐福模板 —— 哪些道具能被这位神赐福、赐福版长什么样（加载时派生成真实道具 `<id>_<神>`）
@export var blessings: Array[Blessing] = []
## 095：激活这个信仰时每走一步，包里每件能被赐福的道具独立掷一次变成赐福版的概率（+ 每级 convert_per_tier）；0 = 不转化
@export var convert_chance: float = 0.03
@export var convert_per_tier: float = 0.01


## 这个信仰的道具带的标签
func tag() -> StringName:
	return StringName(TAG_PREFIX + String(id))


func matches(def: ItemDef) -> bool:
	return def != null and def.tags.has(tag())


## 这么多点数是第几阶：过了几道阈值
func tier_of(points: int) -> int:
	var tier := 0
	for th in thresholds:
		if points >= th:
			tier += 1
	return tier


## 下一道阈值；都过了返回 -1
func next_threshold(points: int) -> int:
	for th in thresholds:
		if points < th:
			return th
	return -1


## 093：这件道具能献祭吗（至少满足一条）
func accepts_offering(def: ItemDef) -> bool:
	for r in offerings:
		if r != null and (r as OfferingRule).matches(def):
			return true
	return false


## 093：献祭这件换多少信力（每满足一条结算一次；不能献 0）
func offering_value(def: ItemDef) -> int:
	var total := 0
	for r in offerings:
		if r != null:
			total += (r as OfferingRule).value(def)
	if total > 0 and def != null and def.is_blessed() and def.faith_tag() == tag():
		total *= 2     # 095（作者定）：自己神的赐福版献回来算双倍
	return total


## 093：现在第 [param tier] 阶生效的效果（tier ≤ 现在的阶）
func perks_at(tier: int) -> Array[FaithPerk]:
	var out: Array[FaithPerk] = []
	for p in perks:
		if p != null and (p as FaithPerk).tier <= tier:
			out.append(p)
	return out


## 献祭品各一句
func offerings_summary() -> String:
	var parts: Array[String] = []
	for r in offerings:
		if r != null:
			parts.append((r as OfferingRule).describe())
	return "；".join(parts)


## 行为各一句
func deeds_summary() -> String:
	var parts: Array[String] = []
	for d in deeds:
		if d != null and String(d.describe()) != "":
			parts.append(String(d.describe()))
	return "、".join(parts)


## 从标签反推 id：`faith:violence` → `violence`；不是信仰对象标签返回空
static func id_of_tag(t: StringName) -> StringName:
	var s := String(t)
	return StringName(s.substr(TAG_PREFIX.length())) if s.begins_with(TAG_PREFIX) and s.length() > TAG_PREFIX.length() else &""


## 装回全部定义：id → FaithDef，按 id 升序
static func load_all() -> Dictionary:
	var out := {}
	var dir := DirAccess.open(ContentPaths.FAITHS)
	if dir == null:
		return out
	var names: Array[String] = []
	for f in dir.get_files():
		var n := f.trim_suffix(".remap")
		if n.ends_with(".tres") or n.ends_with(".res"):
			names.append(n)
	names.sort()
	for n in names:
		var res := load(ContentPaths.FAITHS + "/" + n)
		if res is FaithDef and (res as FaithDef).id != &"":
			out[(res as FaithDef).id] = res
	return out
