## 后果（091）：立一面局外旗标 —— 写成 [member value]（默认 1）；[member add] 为真则在原数上加；[member clear] 拔掉。
## 跟局外存档（持有方在选项选完后存 meta），下一局、营地对话都看得见。沙盒里没有局外（ctx.meta 为 null）就什么也不做
class_name SetFlag
extends EventOutcome

@export var flag: StringName = &""
@export var value: int = 1
## 在原数上加 value 而不是覆盖
@export var add: bool = false
## 拔掉这面旗
@export var clear: bool = false


func apply(ctx: EventContext) -> void:
	if ctx == null or ctx.meta == null or flag == &"":
		return
	if clear:
		ctx.meta.set_flag(flag, 0)
	elif add:
		ctx.meta.add_flag(flag, value)
	else:
		ctx.meta.set_flag(flag, value)


func describe() -> String:
	if clear:
		return "拔掉旗标「%s」" % flag
	if add:
		return "旗标「%s」%s%d" % [flag, "+" if value >= 0 else "", value]
	return "立旗标「%s」" % flag if value == 1 else "旗标「%s」= %d" % [flag, value]
