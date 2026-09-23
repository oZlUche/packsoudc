## 一局的机制（069：进阶难度 = 机制清单，不只是数值）。构件：登记在 [EffectRegistry.RUN_MECHANICS]，加一种 = 一个子类、登记一行。
##
## 难度定义（[DifficultyDef]）列出要开的机制与各自的参数；开局（和读档）时 [RunState.install_mechanics] 逐个 [method install]，
## 机制自己把自己接进一局：侵蚀接到 `MapTravel.erosion`，猎手接到 `RunState.hunters`……本类不认识任何具体机制。
## 没有难度定义 = 普通难度 = 什么机制都不装，一局和现在一样。
@abstract
class_name RunMechanic
extends Resource

## 把自己接进一局。读档也会调一次（机制的状态若跟着存档，在这里读回来）；必须幂等
@abstract func install(run: RunState) -> void

## 给开局屏与编辑器看的一句话
func describe() -> String:
	return ""
