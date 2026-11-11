## 主题奖励池的一行（事件方案 2026-11-11 §8.4）：哪件道具、基础权重、深处与高难度各乘多少、从多深起、限哪几章
class_name RewardPoolEntry
extends Resource

@export var item: StringName = &""
## 基础权重（> 0）
@export var weight: float = 1.0
## 深度 1（最深）时的权重倍率；深度 0 是 1，中间按深度线性过渡
@export var deep_mult: float = 1.0
## 难度每高一档（[member DifficultyDef.level]）权重再乘一次它
@export var hard_mult: float = 1.0
## 节点深度（0～1）至少这么深才进候选
@export var min_depth: float = 0.0
## 只在这几章出（空 = 不限）
@export var chapters: Array[StringName] = []
