## 平衡检测方案（2026-11-10）§4.1：一次实验 / 一份记录的公共元数据。沿用 JSON / JSONL，不另起格式。
##
## [method make] 给工具开一次实验用（`manifest.json`）；[method stamp] 给每一行记录打上同一组字段（来源、构建、格式版本）。
## [b]来源[/b]（[constant SOURCES]）把真人、作者、自动脚本、合成战斗、测试分开 —— 合成的行不许拼进真人统计。
## 格式版本 [constant SCHEMA_VERSION] 与游戏版本分开：改了行的字段才涨它
class_name ExperimentManifest
extends RefCounted

const SCHEMA_VERSION := 1
## 记录行的格式版本（快照、对局、系数假设三种行共用；没有这个键的是老格式）
const ROW_SCHEMA := 2
const HUMAN := "human"
const AUTHOR := "author"
const AUTO := "auto"
const SYNTHETIC := "synthetic"
const TEST := "test"
const SOURCES: Array[String] = [HUMAN, AUTHOR, AUTO, SYNTHETIC, TEST]

## 记录行上的几个公共键
const K_SCHEMA := "schema"
const K_SOURCE := "source"
const K_BUILD := "build"
const K_RUN := "run_id"
const K_BATTLE := "battle_id"


## 开一次实验：[param source] 是 [constant SOURCES] 之一；[param config] 原样存（命令行参数、场数、池子…）；
## [param content_dirs] 算内容摘要（影响实验的资源目录）；[param suite] 是场景 / 配装集合（算摘要，不整个存）
static func make(source: String, config: Dictionary, content_dirs: Array[String] = [] as Array[String], suite: Variant = null,
		seed_manifest: String = "seeds.json") -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"experiment_id": new_id("exp"),
		"source": source,
		"build_id": BuildInfo.id(),
		"engine_version": BuildInfo.engine(),
		"content_hash": content_hash(content_dirs),
		"suite_hash": canonical_hash(suite) if suite != null else "",
		"seed_manifest": seed_manifest,
		"config": config.duplicate(true),
		"started_at": Time.get_datetime_string_from_system(true) + "Z",
	}


## 给一行记录打上来源、构建、格式版本（就地改，也返回它）
static func stamp(row: Dictionary, source: String) -> Dictionary:
	row[K_SCHEMA] = ROW_SCHEMA
	row[K_SOURCE] = source
	row[K_BUILD] = BuildInfo.id()
	return row


## 一个新的不重复标识：`<前缀>-<UTC 毫秒十六进制>-<随机八位十六进制>`。用自己的随机数，不碰局内随机数
static func new_id(prefix: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%s-%x-%08x" % [prefix, int(Time.get_unix_time_from_system() * 1000.0), rng.randi()]


## 任意值的规范摘要：键排序的 JSON 再取 sha256 前 16 位。同样的内容不管键的顺序都得同一个值
static func canonical_hash(value: Variant) -> String:
	return JSON.stringify(value, "", true).sha256_text().substr(0, 16)


## 几个目录下全部文件（按相对路径排序）的内容摘要：路径和内容一起算，改名也算改。目录不在就跳过；全空返回空串
static func content_hash(dirs: Array[String]) -> String:
	var files: Array[String] = []
	for d in dirs:
		_collect(d, files)
	if files.is_empty():
		return ""
	files.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for f in files:
		ctx.update(f.to_utf8_buffer())
		var bytes := FileAccess.get_file_as_bytes(f)
		if not bytes.is_empty():
			ctx.update(bytes)
	return ctx.finish().hex_encode().substr(0, 16)


static func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".uid") or f.ends_with(".import"):
			continue
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_collect(dir.path_join(sub), out)
