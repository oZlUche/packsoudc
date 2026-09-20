## 极简断言收集器。刻意不引入第三方测试框架 —— 逻辑层是纯 RefCounted，
## 一个 SceneTree 脚本就能全部跑完，没必要为此增加依赖。
class_name TestCase
extends RefCounted

var checks: int = 0
var failures: Array[String] = []
var _suite: String = ""


func begin(suite: String) -> void:
	_suite = suite


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append("[%s] %s" % [_suite, msg])


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	checks += 1
	if actual != expected:
		failures.append("[%s] %s\n      期望: %s\n      实际: %s" % [_suite, msg, expected, actual])


func ne(actual: Variant, unexpected: Variant, msg: String) -> void:
	checks += 1
	if actual == unexpected:
		failures.append("[%s] %s\n      不应等于: %s" % [_suite, msg, unexpected])


func is_null(value: Variant, msg: String) -> void:
	check(value == null, msg + "（应为 null，实际为 %s）" % value)


func not_null(value: Variant, msg: String) -> void:
	check(value != null, msg + "（不应为 null）")


func passed() -> bool:
	return failures.is_empty()
