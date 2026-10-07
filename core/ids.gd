## 内容 id（[StringName]）的排序。
##
## [b]为什么要有这个文件[/b]：Godot 的 `Array[StringName].sort()` 比的是
## StringName 的**内部指针**，也就是这些名字在进程里第一次出现的先后 —— 不是字典序。
## 于是「id 升序」的候选表实际上会随无关代码的改动（新加一个脚本、多一个常量）换顺序，
## 而候选表的顺序一旦喂给随机数，生成结果就跟着变：敌人的招牌武器会莫名换成普通版，
## 掉落会换一件。这是 105 落地时被一条断言抓出来的（`tests/run/test_author_087.gd` 的神射手招牌）。
##
## 凡是**顺序会影响结果**的 id 表（敌人配装的候选池、掉落候选、同族道具）都用这里的，
## 不用 `sort()`。只给人看的（面板、报错里列一串名字）用哪个都行，但也建议用这里的
class_name Ids
extends RefCounted


## 原地按文本升序排（有类型的、无类型的 id 数组都收）
static func sort(names: Array) -> void:
	names.sort_custom(func(a, b) -> bool: return String(a) < String(b))
