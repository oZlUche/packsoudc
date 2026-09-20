## 一条套装效果。按作用域分类，各系统只取自己关心的那些。
##
## 注意与 [Effect] 的区别：[Effect] 是战斗中「做一件事」，本类是
## 「套装激活后，在某个系统里持续起什么作用」，作用域可以在战斗之外。
@abstract
class_name SetEffect
extends Resource

## 本效果属于哪个作用域，见 [SetScope]
@abstract func scope() -> StringName

## 给 UI 的一行说明
func describe() -> String:
	return ""
