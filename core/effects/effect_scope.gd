## 效果的作用域。
##
## 一个效果在哪个系统里起作用，由它自己声明；**每个系统只查自己那一档，
## 彼此不需要认识对方**。新增作用域 = 加一个 [Effect] 子树 + 对应系统去查询，
## 不改基类，也不动其他系统。
##
## 原名 SetScope —— 改名是因为作用域不是套装专有的，道具同样可以带跨域效果。
class_name EffectScope
extends RefCounted

## 战斗内。**只有这一支依赖扳机。**
const COMBAT := &"combat"

## 战斗胜利后的战利品生成。激活即生效，不需要扳机。
const LOOT := &"loot"

## 地图层：节点、路线、事件。占位，M3 再实现。
const MAP := &"map"

## 一局的规则：体力上限、开局钱、多搜几次、商店价、幸运…… 由 buff 携带（059），[RunState] 在对应的点查询 [RunContext]
const RUN := &"run"
