## 一局的模块 —— [RunState] 的扩展点（101 第 0 刀，作者 2026-10-01 的要求：「流程控制器要能扩展、能加东西」）。
##
## **加一种玩法 = 一个子类 + 注册表一行 + 内容清单里一条，[RunState] 一行都不改。**
## 模块自带状态、自带存档、自己接线：`install` 里造自己的状态、订阅 [RunState] / [MapTravel] / [NodeEvents] 已有的信号
## （和侵蚀、猎手、信力一直以来的接法一样 —— 1.2 命令进信号出，逻辑层之间直接引用）。
## 基类只保证四件事：**装、存、读、说一句**。生命周期的钩子刻意不写在基类里：写了就得在 [RunState] 里逐个调，
## 那又回到了「每加一个玩法都要改 RunState」。
##
## 哪些模块装，三层叠加（[method RunState.install_modules]）：
## 1. 章节 [member ChapterDef.modules]（本体功能：保险箱、倒计时、神坛……），没列就用 [method RunModules.standard]；
## 2. 难度 [member DifficultyDef.mechanics]（069 的机制清单，[RunMechanic] 是本类的子类）；
## 3. 跑起来之后临时加的（事件、角色）：`run.install_module(m)`。
##
## 存档：[RunState.to_dict] 把每个模块的 [method to_dict] 存进 `modules[id]`；读档时先 [method restore] 分发、再 `install`
## —— 所以 `restore` 只收字典、要内容库才能还原的东西（容器里的道具）留到 `install` 里用 `run.items` 做。
## 新加模块 = 新键、带默认值，不用升存档版本（098 的规矩）。
@abstract
class_name RunModule
extends Resource

## 存档里的键、`mechanic_tags` 的键、`run.module(id)` 的 id。返回空 = 不进 `modules` 存档（难度机制那种自己另有存档键的）
@abstract func id() -> StringName


## 把自己接进一局。开局与读档各一次，**必须幂等**。
## 这时 `run` 的骨架（地图、旅程、棋盘、节点事件）都已经造好；要给别人调用的能力自己挂上去
func install(_run: RunState) -> void:
	pass


## 自己的状态（进 `modules[id]`）。不存状态的模块不用覆盖
func to_dict() -> Dictionary:
	return {}


## 读档：`install` **之前**拿到自己上次存的那份。要内容库的还原留到 `install` 里做
func restore(_d: Dictionary) -> void:
	pass


## 给开局屏的规则卡、编辑器看的一句话
func describe() -> String:
	return ""
