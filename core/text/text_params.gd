## 一个内容定义自己的数值字段 → 文本模板的键（104 第十节：说明文字里的数只能来自字段）。
##
## `description`、`note`、事件选项的 `label` 渲染时拿它当 [TextTemplate] 的上下文，作者写 `{per_points}` 而不是 50。
## 规则（全部从导出属性反射出来，内容类不用写任何东西）：
## - 数值字段（int / float，不含 bool）→ 同名键：`{amount}` `{duration_steps}` `{per_points}`
## - 值是数的字典字段 → 每个键直接用：角色 `base_stats` 的 `{max_hp}`
## - 数组里**注册表里有名字的**构件（事件结果、条件、局内效果……）→ `<类型>_<字段>`：
##   `{change_money_amount}` `{pass_time_actions}` `{steps_within_min_steps}` `{vitality_max_bonus_amount}`；同类型出现几次取第一个
## - 数组里其余对象（属性修饰 `mods`……）→ 第一个元素的字段不加前缀补进来（已有的键不覆盖）：`{amount}`（133：原 `{mult_percent}` / `{flat}`）
## - 单个子对象（道具的 `combat`）→ 递归进去，不加前缀
## 整数值的 float 显示成整数（`4.0` → `4`）。键全表见 docs/text-placeholders.md「定义自身字段」
class_name TextParams
extends RefCounted

const MAX_DEPTH := 4

## 类名 → 注册表里的类型名（空 = 不在注册表里）；反查要逐个 load 脚本，记一下
static var _type_cache := {}


static func of(obj: Object) -> Dictionary:
	var out := {}
	_collect(obj, "", out, 0)
	return out


static func _collect(obj: Object, prefix: String, out: Dictionary, depth: int) -> void:
	if obj == null or depth > MAX_DEPTH:
		return
	for p in ContentSchema.properties_of(obj):
		var name := String(p["name"])
		var v: Variant = obj.get(name)
		if v is bool:
			continue
		if v is int or v is float:
			_put(out, prefix + name, v)
		elif v is Dictionary:
			for k in v:
				var x: Variant = (v as Dictionary)[k]
				if (x is int or x is float) and not (x is bool):
					_put(out, prefix + String(k), x)
		elif v is Array:
			var first_plain := true
			for e in v:
				if not (e is Object):
					continue
				var type := _type_of(e)
				if type != "":
					_collect(e, prefix + type + "_", out, depth + 1)
				elif first_plain:
					first_plain = false
					_collect(e, prefix, out, depth + 1)
		elif v is Object and v is Resource:
			_collect(v, prefix, out, depth + 1)


## 已有的键不覆盖：同一层先出现的、外层的优先
static func _put(out: Dictionary, key: String, v: Variant) -> void:
	if out.has(key):
		return
	out[key] = int(v) if v is float and is_equal_approx(v, roundf(v)) else v


static func _type_of(e: Object) -> String:
	var cls := ContentSchema.class_name_of(e)
	if not _type_cache.has(cls):
		var type := ContentSchema.registry_name_of(e)
		_type_cache[cls] = String(type) if type != &"" and type != cls else ""
	return String(_type_cache[cls])
