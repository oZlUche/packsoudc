## 206：拿起 / 放下的声音按道具的材质分三类（素材按材质做，不按件做）。按标签从上到下第一个命中；包按皮；其余都算布。
## 金属那一组和 [ItemWeight] 的重档同一批标签
class_name SfxMaterial
extends RefCounted

const METAL := &"metal"
const LEATHER := &"leather"
const CLOTH := &"cloth"
## 第一个命中的组说了算
const GROUPS := [
	[METAL, [&"heavy", &"metal", &"gem", &"stone"]],
	[LEATHER, [&"leather", &"wood", &"bone", &"clay"]],
]


static func of(def: ItemDef) -> StringName:
	if def == null:
		return CLOTH
	for g in GROUPS:
		for tag in g[1]:
			if def.tags.has(tag):
				return g[0]
	return LEATHER if def.is_bag else CLOTH


## 拿起这件响哪个 cue
static func pick_cue(def: ItemDef) -> StringName:
	return StringName("bag.pick." + String(of(def)))


## 放进棋盘响哪个 cue
static func place_cue(def: ItemDef) -> StringName:
	return StringName("bag.place." + String(of(def)))
