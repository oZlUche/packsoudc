## 320：把一份内容定义（难度这类 Resource，连同它的子构件）拍成一份能进存档的字典，读档时原样造回来。
## 只认 `res://core/` 下的脚本；只走存档属性（`@export`）。正式游戏里用，不碰导入器 / 导出器（启动图测试 176）。
## 数字、名字、数组、字典、子 Resource 递归；类型按属性声明转回去（JSON 读回来的 3.0 → 3、"x" → &"x"）
class_name ResourceSnapshot
extends RefCounted

const SCRIPT_KEY := "@script"
const ROOT := "res://core/"


static func dump(obj: Object) -> Dictionary:
	var out := {}
	if obj == null or obj.get_script() == null:
		return out
	out[SCRIPT_KEY] = (obj.get_script() as Script).resource_path
	for p in obj.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or int(p["usage"]) & PROPERTY_USAGE_STORAGE == 0:
			continue
		out[String(p["name"])] = _enc(obj.get(String(p["name"])))
	return out


static func _enc(v: Variant) -> Variant:
	if v is Resource:
		return dump(v)
	if v is Array:
		var arr: Array = []
		for e in v:
			arr.append(_enc(e))
		return arr
	if v is Dictionary:
		var d := {}
		for k in v:
			d[String(k)] = _enc((v as Dictionary)[k])
		return d
	if v is StringName:
		return String(v)
	return v


## 造回来；脚本不在 core 下、读不出来返回 null
static func build(data: Dictionary) -> Object:
	var path := String(data.get(SCRIPT_KEY, ""))
	if not path.begins_with(ROOT) or not ResourceLoader.exists(path):
		return null
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		return null
	var obj: Object = script.new()
	for p in obj.get_property_list():
		var name := String(p["name"])
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or not data.has(name):
			continue
		var raw: Variant = data[name]
		var cur: Variant = obj.get(name)
		if cur is Array:
			var list: Array = []
			for e in raw if raw is Array else []:
				list.append(_dec(e, (cur as Array).get_typed_builtin()))
			(cur as Array).assign(list)
		elif cur is Dictionary:
			obj.set(name, (raw as Dictionary).duplicate(true) if raw is Dictionary else {})
		else:
			obj.set(name, _dec(raw, int(p["type"])))
	return obj


static func _dec(v: Variant, type: int) -> Variant:
	if v is Dictionary and (v as Dictionary).has(SCRIPT_KEY):
		return build(v)
	match type:
		TYPE_INT:
			return int(v)
		TYPE_FLOAT:
			return float(v)
		TYPE_STRING_NAME:
			return StringName(String(v))
		TYPE_STRING:
			return String(v)
		TYPE_BOOL:
			return bool(v)
	return v
