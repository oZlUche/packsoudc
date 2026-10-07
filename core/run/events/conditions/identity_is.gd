## 条件（136）：这一局的角色身份（[member CharacterDef.identity]：slave / legion）在名单里。事件按身份分支用；没有角色 = 不满足
class_name IdentityIs
extends EventCondition

@export var identities: Array[StringName] = []


func check(ctx: EventContext) -> bool:
	return ctx != null and ctx.hooks != null and identities.has(ctx.hooks.identity())


func describe() -> String:
	var names: Array[String] = []
	for t in identities:
		names.append(String(t))
	return "需要身份是%s" % " / ".join(names)
