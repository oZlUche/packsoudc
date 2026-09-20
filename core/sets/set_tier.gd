## 套装的一个档位：集齐几件时生效，生效什么。
class_name SetTier
extends Resource

## 达到几件时生效
@export var pieces: int = 2

## 本档的效果。可以跨作用域混着放 —— 「4 件套：增伤 20% 且掉落 +1」
## 就是一条 CombatSetEffect 加一条 LootSetEffect。
@export var effects: Array[SetEffect] = []


## 取本档中属于某作用域的效果
func effects_in(scope: StringName) -> Array[SetEffect]:
	var out: Array[SetEffect] = []
	for e in effects:
		if (e as SetEffect).scope() == scope:
			out.append(e)
	return out
