## 一种元素反应（175）：目标身上带着甲元素的印、又挨上乙元素 → 结算这里的效果。
##
## 数据在 `data/authoring/reactions/<甲>_<乙>.json`（两种元素按 [constant ReactionResolver.ELEMENTS] 的顺序拼 id）。
## 效果就是普通的规则内容（[CombatEffect]），以**攻击方**为主人跑：「对手」= 挨打的那一方，「自己」= 引发反应的那一方。
## 结算见 [ReactionResolver]（175 补充一 / 三，作者伪代码）：量 N = min(已有印的层数, 新来的层数)，两边各扣 N，新来的余量照常叠上，再跑效果。
##
## 175 补充二：效果里的数字可以随 N 变 —— json 里在数字的位置写下面三种之一，导入器把它记进 [member scaling]（效果里留占位数），
## 结算时 [method effects_for] 按 N 展开；没写的照常是固定值。
## [codeblock]
## {"per_stack": X}             = N × X（可加 "max" 封顶）
## {"stacks": "n"}              = N（可加 "max" 封顶）
## {"stacks": "n/2"}            = N / 2，向下取整（补充四：爆燃重叠的灼伤；为 0 这个效果就不跑）
## {"seconds": "n", "max": 10}  = N 秒，封顶 max（写在 apply_status 的 "duration_sec" 上 = 这次施加的状态持续 N 秒）
## [endcodeblock]
## 补充四：各反应的系数 M 都写在 json 里（作者会调），代码里不写死。算出来是 0 的效果整条不跑（施加 0 层不会变成 1 层）
class_name ReactionDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var display_names: Dictionary = {}
## 一句说明（百科的反应页、悬浮窗的词条）
@export_multiline var description: String = ""
@export var descriptions: Dictionary = {}
## 两种元素（`fire` / `ice` / `lightning` / `poison` / `bleed`），不分先后
@export var elements: Array[StringName] = []
## 效果。层数类（`per_stack`：「每层 3 点」、施加几层）读的是反应的量 N（[member RuleContext.reaction_stacks]，见 [ReactionResolver]）
@export var effects: Array[CombatEffect] = []
## 175 补充二：哪些数字随 N 变 —— `{effect: 第几个效果, field: 字段（"buff.duration_sec" = 施加的状态的时长）, kind: per_stack / n / seconds, x, max}`。
## 导入器从 json 的内联写法填，导出器写回内联写法（json 里不出现这个键）
@export var scaling: Array = []

const KIND_PER_STACK := "per_stack"
const KIND_N := "n"
const KIND_SECONDS := "seconds"
## 175 补充四：N / 2（向下取整）
const KIND_HALF := "n/2"
## 写在 apply_status 上的「这次施加的状态持续几秒」
const BUFF_DURATION := "buff.duration_sec"


func has_element(element: StringName) -> bool:
	return elements.has(element)


## 175 补充二：量 [param n] 时实际跑的效果 —— 没有随 N 变的数字就是 [member effects] 本身；有的复制一份改掉那几个数
func effects_for(n: int) -> Array[CombatEffect]:
	if scaling.is_empty():
		return effects
	var out: Array[CombatEffect] = effects.duplicate()
	var copied := {}
	for raw in scaling:
		var row := raw as Dictionary
		var i := int(row.get("effect", -1))
		if i < 0 or i >= out.size() or out[i] == null:
			continue
		if not copied.has(i):
			out[i] = out[i].duplicate(true) as CombatEffect
			copied[i] = true
		var v := value_of(row, n)
		if is_zero_approx(v):
			out[i] = null     # 补充四：算出来是 0（N = 1 的 N / 2）—— 这条效果不跑
			continue
		var field := String(row.get("field", ""))
		if field == BUFF_DURATION:
			var a := out[i] as ApplyStatus
			if a != null and a.buff != null:
				a.buff = a.buff.duplicate() as BuffDef     # 内容库里的 buff 是外部资源，深复制不会复制它：自己复制一份再改
				a.buff.duration_sec = v
		elif field in out[i]:
			out[i].set(field, roundi(v) if out[i].get(field) is int else v)
	return out


## 175 补充四：百科 / 悬浮窗的效果一句 —— 随 N 变的效果写一层的数（per_stack 写 X，其余写 1）再标「× 反应层数」，
## 这样 M 改了这里跟着变，说明文字里不用写数
func describe_effects() -> String:
	var marks := {}
	for raw in scaling:
		var row := raw as Dictionary
		marks[int(row.get("effect", -1))] = UiText.t("rule.react_half") if String(row.get("kind", "")) == KIND_HALF else UiText.t("rule.react_full")
	var shown := effects_for(1) if not scaling.is_empty() else effects
	var bits: Array[String] = []
	for i in effects.size():
		var e = shown[i] if i < shown.size() and shown[i] != null else effects[i]
		if e == null:
			continue
		var d: String = e.describe() if e.has_method("describe") else ""
		if d == "":
			continue
		bits.append(d + String(marks.get(i, "")))
	return UiText.t("tip.sep").join(bits) if not bits.is_empty() else UiText.t("rule.no_effect")


## 一行随 N 变的数字在量 [param n] 时是多少
static func value_of(row: Dictionary, n: int) -> float:
	var v := float(n)
	match String(row.get("kind", "")):
		KIND_PER_STACK:
			v = n * float(row.get("x", 0.0))
		KIND_N, KIND_SECONDS:
			v = float(n)
		KIND_HALF:
			v = float(n / 2)
	var cap := float(row.get("max", 0.0))
	return minf(v, cap) if cap > 0.0 else v
