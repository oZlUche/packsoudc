## 一局**默认装哪些模块**（101 第 0 刀）：章节没在 [member ChapterDef.modules] 里列清单时用这一份。
##
## 这里列的是「本体功能」—— 每一局都该有的那些（保险箱、将来的倒计时 / 神坛 / 合成……）。
## 101 第 1 刀每搬出一个子系统，这张清单就多一行；章节想不一样（序章不要保险箱、某章加天气）就在 JSON 里自己列。
## 难度开的机制是另一层（[member DifficultyDef.mechanics]），两层叠加，见 [method RunState.install_modules]。
class_name RunModules
extends RefCounted


## 默认清单。每次返回**新实例** —— 模块带自己的状态，两局不能共用一个对象
static func standard() -> Array:
	return [SafeModule.new(), NodeStorageModule.new(), CraftingModule.new(), BuffModule.new(), AltarModule.new(), CountdownModule.new(), BeltModule.new(), WearModule.new()]
