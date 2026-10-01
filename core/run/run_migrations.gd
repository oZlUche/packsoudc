## 一局存档的版本迁移链（098，架构文档 7.2）。和 [MetaMigrations] 同一套做法、同一条规矩，只是对象是 [RunState]。
##
## 作者定：**一局档走同一条链，但允许作废** —— 升不上去就按「不认识」处理（备份后从零开始，玩家丢的只是这一局，
## 局外的仓库、图鉴、战绩都还在）。现在 `SAVE_VERSION = 1`，链上还没有任何一步。
##
## 升版时在这里加一步：[const STEPS] 加一行 `老版本: "_vn_to_vn1"`，`upgrade` 的 `match` 里接上，
## 并在 `tests/fixtures/` 留一份那一版的冻结样本（`tests/test_save_migration.gd` 会扫）。
class_name RunMigrations
extends RefCounted

## 有哪几步：from_version → 方法名（文档与自检用；分派走 match，不走反射）
const STEPS := {}


## 尽量升到 [constant RunState.SAVE_VERSION]。不改入参（深拷一份）。
## 升不上去就把能升到哪算哪，版本号照实写在 `version` 里，调用方按「不认识」处理
static func upgrade(src: Dictionary) -> Dictionary:
	var d := src.duplicate(true)
	var v := int(d.get("version", -1))
	while v < RunState.SAVE_VERSION and STEPS.has(v):
		# 这里按 v 分派一步（`match v: 1: d = _v1_to_v2(d)`），然后：
		v += 1
		d["version"] = v
	if int(d.get("version", -1)) != RunState.SAVE_VERSION:
		push_warning("RunMigrations: 没有 v%s → v%d 的迁移，这一局作废（局外进度不受影响）" % [str(d.get("version", "?")), RunState.SAVE_VERSION])
	return d
