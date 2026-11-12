## 313（试玩切片 S1 第二批）：现在跑的是哪一档 —— 空 = 正式版；`slice` = 试玩切片。
## 切片的判断：导出包带 `slice` 特性，或命令行 `-- --profile=slice`（开发时用）。
## 切片只列切片章节、存档和设置都放在 user://slice/ 下（不碰正式版的存档）、基地只留出征和仓库两个页签
class_name SliceProfile
extends RefCounted

const SLICE := &"slice"
const ARG := "--profile=slice"
const ROOT := "user://slice"
const SLOTS := ROOT + "/slots"
const SETTINGS := ROOT + "/settings.json"
const CALIBRATION := ROOT + "/calibration"
## 切片的基地只留这几个页签（[constant MetaScreen.TABS] 的键）
const TABS: Array[String] = ["expedition", "warehouse"]

## 测试用：不看特性和命令行，直接当成这一档（null = 照常判断）
static var forced: Variant = null


static func current() -> StringName:
	if forced != null:
		return StringName(String(forced))
	if OS.has_feature(String(SLICE)) or OS.get_cmdline_user_args().has(ARG):
		return SLICE
	return &""


## 这一档的存档位放在哪
static func slots_root(p_profile: StringName) -> String:
	return SLOTS if p_profile == SLICE else SaveSlots.DEFAULT_ROOT


## 这一档的设置文件；正式版照旧用 [param fallback]
static func settings_path(p_profile: StringName, fallback: String) -> String:
	return SETTINGS if p_profile == SLICE and fallback == GameSettings.DEFAULT_PATH else fallback


## 这一档的基地有没有这个页签
static func keeps_tab(p_profile: StringName, key: String) -> bool:
	return p_profile != SLICE or TABS.has(key)
