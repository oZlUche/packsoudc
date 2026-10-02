## 一局的机制（069：进阶难度 = 机制清单，不只是数值）。构件：登记在 [EffectRegistry.RUN_MODULES]，加一种 = 一个子类、登记一行。
##
## 难度定义（[DifficultyDef]）列出要开的机制与各自的参数；开局（和读档）时 [RunState.install_modules] 逐个 [method install]，
## 机制自己把自己接进一局：侵蚀接到 `MapTravel.erosion`，猎手接到 `RunState.hunters`……本类不认识任何具体机制。
## 没有难度定义 = 普通难度 = 什么机制都不装，一局和现在一样。
##
## 101 第 0 刀：机制就是 [RunModule] 的一种 —— 这个扩展点被升级成了一局的统一插件模型，本体功能（保险箱、倒计时……）
## 和难度机制走同一条路。本类留着是因为「难度开的机制」这个说法有它自己的意思（[member DifficultyDef.mechanics] 的元素类型），
## 而且侵蚀、猎手不用改一行。它们的状态各有自己的存档键（`erosion` / `hunters`），所以 [method id] 默认是空的。
@abstract
class_name RunMechanic
extends RunModule

## 难度机制默认不进 `modules` 存档：侵蚀、猎手早就各有自己的键（098 的规矩：格式不改不升版）。
## 新写的机制要存状态就覆盖它，返回一个自己的 id
func id() -> StringName:
	return &""


## 把自己接进一局。读档也会调一次（机制的状态若跟着存档，在这里读回来）；必须幂等
@abstract func install(run: RunState) -> void
