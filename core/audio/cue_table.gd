## 204：声音的 cue 表 —— 手写的 `data/authoring/audio/cues.json`（音效）与 `music.json`（配乐），直接读（同 169 的 `text_colors.json`，不走内容管线、不进快照）。
##
## cue 名 = `组.名`（`ui.press`）。每个 cue：`files`（相对 `res://assets/audio/`，多个随机挑）、`volume_db`、`pitch_var`（音高 1 ± 它）、`cooldown`（同一 cue 两次最短间隔，秒）。
## 206：`alias`（这个名字只是另一个 cue 的别名：一层、不链、不带 files，查表时先解）、`max_per_sec`（一秒最多响几次，滑动窗口；0 = 不限）。
## 配乐：曲名 → `file`、`volume_db`。只管读和校字段，不认识 Node / 播放器（播放是界面层 `ui/audio.gd` 的事）
class_name CueTable
extends RefCounted

const CUES_PATH := "res://data/authoring/audio/cues.json"
const MUSIC_PATH := "res://data/authoring/audio/music.json"
## 素材的根（`files` / `file` 相对它）
const ASSET_ROOT := "res://assets/audio/"
const DEFAULT_COOLDOWN := 0.04
## cue 认得的字段（`files` 必填）
const CUE_FIELDS := ["files", "volume_db", "pitch_var", "cooldown", "max_per_sec"]
## 别名条目只认这一个字段
const ALIAS_FIELD := "alias"
const MUSIC_FIELDS := ["file", "volume_db"]

## cue 名 → {files: Array[String], volume_db, pitch_var, cooldown}（缺的字段补了默认）
var cues: Dictionary = {}
## 206：别名 → 真名（一层）
var aliases: Dictionary = {}
## 曲名 → {file, volume_db}
var music: Dictionary = {}
## 读表时发现的问题（测试看；玩家什么也不见）
var errors: Array[String] = []


## 读默认的两张表
static func load_default() -> CueTable:
	var t := CueTable.new()
	t.load_files(CUES_PATH, MUSIC_PATH)
	return t


func load_files(cues_path: String, music_path: String) -> void:
	cues = {}
	aliases = {}
	music = {}
	errors = []
	var raw := _read(cues_path)
	for key in raw:
		if raw[key] is Dictionary and (raw[key] as Dictionary).has(ALIAS_FIELD):
			_alias(String(key), raw[key])
			continue
		var c := _cue(String(key), raw[key])
		if not c.is_empty():
			cues[StringName(String(key))] = c
	for name in aliases.keys():
		var target: StringName = aliases[name]
		if aliases.has(target):
			errors.append("%s：别名指向的 %s 也是别名（不许链）" % [name, target])
			aliases.erase(name)
		elif not cues.has(target):
			errors.append("%s：别名指向的 %s 不在表里" % [name, target])
			aliases.erase(name)
	var mraw := _read(music_path)
	for key in mraw:
		var m := _track(String(key), mraw[key])
		if not m.is_empty():
			music[StringName(String(key))] = m


## 这个 cue（别名先解；没有 = 空字典）
func cue(name: StringName) -> Dictionary:
	return cues.get(resolve(name), {})


## 206：别名解成真名（不是别名原样返回）
func resolve(name: StringName) -> StringName:
	return aliases.get(name, name)


## 这个 cue 的文件（res:// 全路径）
func files_of(name: StringName) -> Array[String]:
	var out: Array[String] = []
	for f in (cue(name).get("files", []) as Array):
		out.append(ASSET_ROOT + String(f))
	return out


## 这首曲子（没有 = 空字典）
func track(name: StringName) -> Dictionary:
	return music.get(name, {})


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("%s：不是 JSON 对象" % path)
		return {}
	return parsed


func _cue(key: String, raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		errors.append("%s：不是对象" % key)
		return {}
	var d: Dictionary = raw
	for f in d:
		if not CUE_FIELDS.has(String(f)):
			errors.append("%s：不认识的字段 %s" % [key, f])
	var files: Array[String] = []
	if not d.get("files") is Array:
		errors.append("%s：files 要是数组" % key)
	else:
		for f in (d["files"] as Array):
			if f is String and String(f) != "":
				files.append(String(f))
			else:
				errors.append("%s：files 里有不是文件名的 %s" % [key, f])
	return {"files": files, "volume_db": _num(key, d, "volume_db", 0.0), "pitch_var": maxf(0.0, _num(key, d, "pitch_var", 0.0)),
		"cooldown": maxf(0.0, _num(key, d, "cooldown", DEFAULT_COOLDOWN)), "max_per_sec": maxi(0, int(_num(key, d, "max_per_sec", 0.0)))}


## 206：别名条目 `{"alias": "真名"}`：只许这一个字段（带 files 等报错，别名照样记上）
func _alias(key: String, d: Dictionary) -> void:
	for f in d:
		if String(f) != ALIAS_FIELD:
			errors.append("%s：别名不许带 %s" % [key, f])
	var target: Variant = d[ALIAS_FIELD]
	if not target is String or String(target) == "":
		errors.append("%s：alias 要是 cue 名" % key)
		return
	aliases[StringName(key)] = StringName(String(target))


func _track(key: String, raw: Variant) -> Dictionary:
	if not raw is Dictionary or not (raw as Dictionary).get("file") is String:
		errors.append("%s：配乐要有 file" % key)
		return {}
	var d: Dictionary = raw
	for f in d:
		if not MUSIC_FIELDS.has(String(f)):
			errors.append("%s：不认识的字段 %s" % [key, f])
	return {"file": String(d["file"]), "volume_db": _num(key, d, "volume_db", 0.0)}


func _num(key: String, d: Dictionary, field: String, fallback: float) -> float:
	var v: Variant = d.get(field, fallback)
	if v is int or v is float:
		return float(v)
	errors.append("%s：%s 要是数" % [key, field])
	return fallback
