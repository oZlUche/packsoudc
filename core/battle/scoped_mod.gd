## 按件修饰（报告 105 3.2）：**筛一批参战道具，对它们做几件事**。
##
## 四条信仰效果要的都是这个形状 —— 附魔（筛武器、随机挑几把、挂规则、改耐力消耗）、
## 食物翻倍（筛食物、基础值缩放）、`stat_mod(items, tag)`（筛标签、加修饰）、
## 献祭生命上限（不筛、全部加急速）。筛法是公共的，做的事互相独立（空的就跳过），
## 所以是**一个**构件带几种能力，而不是三个构件各抄一遍筛选。
##
## [b]编译器唯一的按件入口[/b]：进到 `CompileInput.scoped` 里，第 7 步统一施加。
## 在它之前，`core/run` 的 perk 是拿着编译完的 [CombatantSpec] 自己改 —— 战斗单位有两个来源。
##
## 是 [Resource] + `@export` 而不是 RefCounted：现在只有 perk 程序化地造它，但增益来源还有
## 局内 buff / 局外 / 套装（作者定，105 第 ① 条）。将来 [RunBuffDef] / 套装档位加一个
## `scoped: Array[ScopedMod]` 字段就能在内容里写「这局所有武器 +10%」，那时再在
## 注册表登记种类（10.4 的反射管线自动认得）。**这一轮不登记、不加内容字段。**
class_name ScopedMod
extends Resource

## 任一命中就算（标签在 [ItemDef.tags] 上）；空 = 不看标签，所有参战道具都命中
@export var tags: Array[StringName] = []
## 只给有规则的道具（附魔：没规则的武器根本不出手，附上去也没用）
@export var require_active: bool = false
## 0 = 全部命中件；> 0 = 用 [member CompileInput.seed] 从命中件里随机挑这么多件（不够就全部）
@export var pick: int = 0

## 施加到每件命中（乘区 / flat，可交换）
@export var mods: Array[StatModifier] = []
## 挂到每件命中。规则里的 [OnItemFired] 在编译时绑成「只听自己」（填 source_uids = [本件 uid]）
@export var rules: Array[AbilityRule] = []

## 108：挂上去的规则记在宿主的 [member CompiledItem.attached] 里的来源（`faith:sun`……）；空 = 不记
@export var origin: StringName = &""

## 命中件**所有属性的基础值**乘它（食物翻倍）。1.0 = 不缩放
@export var base_scale: float = 1.0
## 不参与 [member base_scale] 的属性（急速：每件都是 1.0，翻倍就成了二倍速）
@export var base_scale_except: Array[StringName] = []


## 什么都不做的一条（筛了也白筛）
func is_empty() -> bool:
	return mods.is_empty() and rules.is_empty() and is_equal_approx(base_scale, 1.0)


## 这件道具命中没有。[param active] = 它打包之后有规则
func matches(def: ItemDef, active: bool) -> bool:
	if def == null:
		return false
	if require_active and not active:
		return false
	if tags.is_empty():
		return true
	for tag in tags:
		if def.tags.has(tag):
			return true
	return false


## 从命中件里挑（[member pick] > 0 才挑）。[param uids] 要按 uid 升序传进来 ——
## 挑的结果只由 [param seed] 与候选集决定，所以同一局拖动预估和真打挑的是同一批。
## Fisher-Yates 取前 pick 件（和搬家前 `enchant_weapons` 的抽法逐步相同）
func choose(uids: Array[int], seed: int) -> Array[int]:
	if pick <= 0 or uids.size() <= pick:
		return uids
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pool := uids.duplicate()
	var out: Array[int] = []
	for _i in pick:
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


## 这条的基础值缩放要不要跳过这个属性
func scales(key: StringName) -> bool:
	return not is_equal_approx(base_scale, 1.0) and not base_scale_except.has(key)
