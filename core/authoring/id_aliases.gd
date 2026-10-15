## 内容 id 的改名表（098）：**旧 id → 新 id**。存档只写 id（架构文档 3.1），所以内容改了名，老存档里的
## 道具、标签、信仰就查不到定义了 —— 道具会被容器的 `from_dict` 告警后丢弃、图鉴计数对不上。
## 这里一张静态表就够：改名是内容的事，不是存档格式的事，所以**不进版本链**（[MetaMigrations]）。
##
## 查的时机都是「先按真名查，查不到才问这里」：[method ItemDatabase.get_def]、[method TagRegistry.get_def]、
## [method FaithPower.restore]（旧信仰的点数并进新池子）、[method RunSave.load_chapter] / [method GameFlow.chapter_of]（章节）。
##
## 规矩（测试 `tests/test_save_migration.gd` 守着）：
## - 表里的**新 id 必须存在**（道具在库里、标签登记过、信仰装得回来）；
## - **旧 id 不许再被内容引用**（作者数据里不该再出现老名字），否则就不是改名而是两个东西撞名。
class_name IdAliases
extends RefCounted

## 道具 id：旧 → 新
const ITEMS := {
	&"strength_sigil": &"charm_brute",     # 142：力量的符号并进蛮神的护符
}

## 173：**删掉了、没有接班的道具**（不是改名）。老存档里读到它时怎么处置（[SaveReconcile]）：
## `{"refund": true, "value": 最后一次的价值}` 折钱（局外进 funds、一局进钱包）/ `{"replace": "<新 id>"}` 换成另一件 / `{"drop": true}` 丢掉。
## 三处（真名、[constant ITEMS]、这里）都查不到的默认也折钱（价值按 0）并写进报告。删道具时**在这里补一行**，
## 内容快照测试（`tests/content/test_content_snapshot.gd`）守着
const RETIRED_ITEMS := {
	&"aid_pack": {"refund": true, "value": 12},     # 160 补一：腰带道具搬去 belt_skills
	&"smoke_bomb": {"refund": true, "value": 12},     # 同上
	&"smg": {"refund": true, "value": 24},     # 155：冲锋枪删了
	&"sniper": {"refund": true, "value": 300},     # 155：狙击枪删了
	&"mana_crystal": {"refund": true, "value": 24},     # 148：换成三色魔晶石
	&"mana_shard": {"refund": true, "value": 8},     # 同上
}

## 173：形状 / 尺寸 / 是否包变过的道具（id → 哪次、怎么变的）。只是登记：对账层照样把原位放不下的重摆，
## 但改了形状的那次要同时看一眼敌人预设棋盘的 `at`（165）。内容快照测试要求变了形状的都在这里
const RESHAPED := {
	&"shortsword": "143：挪位并改成 T 形",
}

## 173：道具 `state` 里改过名的键：旧 → 新（对账时统一改，未知键原样留着）
const STATE_KEYS := {}

## 173：标签 / 信仰 / 章节 / 敌人里删掉、没有接班的 id（种类 → id 列表）。内容快照测试要求消失的 id 要么在改名表、要么在这里
const RETIRED := {
	"tags": [],
	"faiths": [],
	"chapters": [],
	"enemies": [],
}

## 标签：旧 → 新。093 把暴力之神 / 太阳与火之神并成蛮神 / 日神，道具上的对象标签跟着改
const TAGS := {
	&"faith:violence": &"faith:brute",
	&"faith:sunfire": &"faith:sun",
}

## 信仰 id：旧 → 新（093 的合并改名）
const FAITHS := {
	&"violence": &"brute",
	&"sunfire": &"sun",
}

## 章节 id：旧 → 新（114：序章之后只有自由模式，第一章改名）
const CHAPTERS := {
	&"chapter_01": &"free_mode",
}

## 地图节点类型：旧 → 新（175 补充二：独立的铸炉点撤掉，铸炉并进休息点；老存档里的铸炉点按休息点读，[SaveReconcile]）
const NODE_TYPES := {
	&"forge": &"rest",
}


## 一张表里查一次（没有就原样返回）。只查一跳：改名表里不许串成链（a → b、b → c 就把 a 直接写成 c）
static func resolve(table: Dictionary, id: StringName) -> StringName:
	return table.get(id, id)


static func item(id: StringName) -> StringName:
	return resolve(ITEMS, id)


static func tag(id: StringName) -> StringName:
	return resolve(TAGS, id)


static func faith(id: StringName) -> StringName:
	return resolve(FAITHS, id)


static func chapter(id: StringName) -> StringName:
	return resolve(CHAPTERS, id)


## 改名成 [param id] 的那些老名字（局外进度里按章节记的账，老名字下的也算）
static func old_names(table: Dictionary, id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for old in table:
		if table[old] == id:
			out.append(old)
	return out


## 这个 id 是不是被改过名的老名字
static func renamed(table: Dictionary, id: StringName) -> bool:
	return table.has(id)
