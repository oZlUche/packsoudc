## 事件选项的一个条件（构件）：看一眼一局的状态，说能不能选。**只读**，不改任何东西。
## 登记在 [RunRegistry.EVENT_CONDITIONS]；加一种 = 加一个子类、登记一行。
@abstract
class_name EventCondition
extends Resource

@abstract func check(ctx: EventContext) -> bool

## 不满足时给玩家看的一句话（灰掉的选项旁边）
func describe() -> String:
	return ""


## 2026-10-17：给玩家看的说明里写名字、不写 id —— 按种类与 id 读定义的名字；查不到给「数据缺失」
static func content_name(kind: String, id: StringName) -> String:
	if id == &"":
		return "数据缺失"
	var path := ContentPaths.asset_file(kind, String(id))
	var res: Resource = load(path) if path != "" and ResourceLoader.exists(path) else null
	var name := Names.of(res)
	return name if name != "" else "数据缺失"
