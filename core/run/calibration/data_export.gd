## 242 §8.1 第 5 项：「导出平衡数据」—— 校准记录（快照、对局结果）与战斗日志打成一个 zip，玩家交给作者就能拿去做木桩、扫表。
##
## zip 里按目录名放（`calibration/…`、`battle_logs/…`），目录没有或是空的也留一个目录项，打开就知道是哪两样。
## 放桌面（[constant OS.SYSTEM_DIR_DESKTOP]）；取不到桌面就放 user://（设置页那边接着打开那个文件夹）
class_name DataExport
extends RefCounted

const DIRS: Array[String] = [CalibrationRecorder.DIR, BattleArchive.DIR]
const NAME := "背包搜打撤-数据-%s.zip"


static func file_name(date: String = Time.get_date_string_from_system()) -> String:
	return NAME % date


## 放到哪：桌面，取不到就 user://
static func target_dir() -> String:
	var desktop := OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	return desktop if desktop != "" and DirAccess.dir_exists_absolute(desktop) else "user://"


## 打包到 [param out_path]。返回装了几个文件；写不了返回 -1
static func pack(out_path: String, dirs: Array[String] = DIRS) -> int:
	var zip := ZIPPacker.new()
	if zip.open(out_path) != OK:
		return -1
	var count := 0
	for dir in dirs:
		var root := dir.trim_suffix("/").get_file()
		zip.start_file(root + "/")
		zip.close_file()
		count += _add_dir(zip, dir, root)
	zip.close()
	return count


static func _add_dir(zip: ZIPPacker, dir: String, prefix: String) -> int:
	var count := 0
	if not DirAccess.dir_exists_absolute(dir):
		return count
	for file in DirAccess.get_files_at(dir):
		var bytes := FileAccess.get_file_as_bytes(dir.path_join(file))
		zip.start_file(prefix.path_join(file))
		zip.write_file(bytes)
		zip.close_file()
		count += 1
	for sub in DirAccess.get_directories_at(dir):
		count += _add_dir(zip, dir.path_join(sub), prefix.path_join(sub))
	return count
