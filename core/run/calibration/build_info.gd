## 平衡检测方案（2026-11-10）§4.1：这一份数据是哪个构建产出的。
##
## 找法依次是：
## 1. `res://build_id.txt`（打包或开发启动前由 `tools/stamp_build.sh` 写入，一行，比如 `git:1a2b3c4d5e6f+dirty:9f8e7d6c`）；
## 2. 仓库里的 `.git/HEAD`（只认提交号，工作区有没有改动这里看不出来，所以带上 `+wip?`）；
## 3. 都没有就退回游戏版本号 `ver:<application/config/version>`。
## 玩家包运行时不依赖 Git。格式版本（schema）与游戏版本分开记
class_name BuildInfo
extends RefCounted

const STAMP := "res://build_id.txt"
## 只认提交号、看不出工作区改动时的后缀
const UNKNOWN_WORKTREE := "+wip?"

static var _cached: String = ""


## 构建标识（见类说明）。结果缓存，整个进程只找一次
static func id() -> String:
	if _cached == "":
		_cached = _find()
	return _cached


## 测试用：清掉缓存
static func reset() -> void:
	_cached = ""


static func _find() -> String:
	if FileAccess.file_exists(STAMP):
		var stamp := FileAccess.get_file_as_string(STAMP).strip_edges()
		if stamp != "":
			return stamp
	var sha := git_head(ProjectSettings.globalize_path("res://"))
	if sha != "":
		return "git:%s%s" % [sha.substr(0, 12), UNKNOWN_WORKTREE]
	return "ver:" + CalibrationRecorder.version()


## [param root] 下 `.git/HEAD` 指向的提交号；不是仓库或读不出返回空
static func git_head(root: String) -> String:
	var git := root.path_join(".git")
	var head_path := git.path_join("HEAD")
	if not FileAccess.file_exists(head_path):
		return ""
	var head := FileAccess.get_file_as_string(head_path).strip_edges()
	if not head.begins_with("ref:"):
		return head if head.is_valid_hex_number() else ""
	var ref := head.substr(4).strip_edges()
	var ref_path := git.path_join(ref)
	if FileAccess.file_exists(ref_path):
		return FileAccess.get_file_as_string(ref_path).strip_edges()
	var packed := git.path_join("packed-refs")
	if FileAccess.file_exists(packed):
		for line in FileAccess.get_file_as_string(packed).split("\n"):
			var parts := line.strip_edges().split(" ")
			if parts.size() == 2 and parts[1] == ref:
				return parts[0]
	return ""


## 引擎版本，比如 `4.7.1.stable.official.a13da4feb`
static func engine() -> String:
	var v := Engine.get_version_info()
	var h := String(v.get("hash", ""))
	return String(v.get("string", "")) + (" " + h.substr(0, 9) if h != "" else "")
