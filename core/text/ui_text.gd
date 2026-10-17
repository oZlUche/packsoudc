## 界面语言（085，作者定：主菜单切换中文 / 英语，编辑器等界面跟着走）。
##
## 一张键 → 两种文字的表；`t(key)` 按当前语言取，没有的键原样返回（写错一眼看得见）。语言存在 [GameSettings.language]，
## 主菜单切换后由持有方把 [member lang] 改过来。现在只有主菜单与 buff 制作器用它 —— 别的屏还是写死的中文，
## 逐屏换成 `UiText.t()` 就跟着切（15 节待办）。不是 autoload：一个静态变量就够，和 UiPalette 一样
class_name UiText
extends RefCounted

const LANGS: Array[String] = ["zh", "en"]

static var lang: String = "zh"

const TEXT := {
	# 主菜单
	"menu.new_run": {"zh": "新的游戏", "en": "New game"},
	"menu.continue": {"zh": "继续", "en": "Continue"},
	"menu.load": {"zh": "读取存档", "en": "Load game"},
	"slots.title": {"zh": "读取存档", "en": "Load game"},
	"slots.full": {"zh": "三个存档位都满了：删掉一个再开新的游戏", "en": "All three slots are full: delete one to start a new game"},
	"slots.slot": {"zh": "存档位 %d", "en": "Slot %d"},
	"slots.empty": {"zh": "空", "en": "Empty"},
	"slots.summary": {"zh": "第 %d 局　撤离 %d　战败 %d%s", "en": "Run %d · extracted %d · died %d%s"},
	"slots.in_run": {"zh": "　（有进行中的一局）", "en": " (run in progress)"},
	"slots.current": {"zh": "　← 当前", "en": " ← current"},
	"slots.load": {"zh": "载入", "en": "Load"},
	"slots.new_here": {"zh": "在这一位开新的游戏", "en": "New game here"},
	"slots.delete": {"zh": "删除", "en": "Delete"},
	"slots.confirm_delete": {"zh": "再点一次确认删除", "en": "Click again to confirm"},
	"slots.back": {"zh": "回主菜单", "en": "Back"},
	# 098：读不出来的存档已备份（%s = 备份文件名）
	"slots.backed_up": {"zh": "这个存档位的局外进度来自旧版本，读不回来，已备份成 %s，重新从零开始",
		"en": "This slot's meta progress is from an older version and could not be read; backed up as %s, starting fresh"},
	"slots.run_backed_up": {"zh": "进行中的那一局来自旧版本，读不回来，已备份成 %s；局外进度不受影响",
		"en": "The run in progress is from an older version and could not be read; backed up as %s. Meta progress is unaffected"},
	# 新版本的存档拿旧版本打开（%d = 存档的版本号、本版本认得的版本号）：只读，不动它
	"slots.newer": {"zh": "这个存档位来自更新版本的游戏（存档版本 %d，本版本只认 %d）：本版本不会读它、也不会改它。请换回新版本再玩，或者换一个存档位",
		"en": "This slot was saved by a newer version of the game (save version %d; this build reads %d). It will not be read or changed here: switch back to the newer build, or use another slot"},
	# 186：地图顶端栏下面的提示行（玩家用语：不写点号、花费、内部原因）
	"notice.not_adjacent": {"zh": "那里走不过去", "en": "You can't get there from here"},
	"notice.cannot_move": {"zh": "现在走不了", "en": "You can't move right now"},
	"notice.busy": {"zh": "先把眼前的事做完", "en": "Finish what's in front of you first"},
	"notice.not_extract": {"zh": "这里不是撤离点", "en": "This isn't an extraction point"},
	"notice.extract_closed": {"zh": "这个撤离点已经关闭了", "en": "This extraction point has closed"},
	"notice.extract_fee": {"zh": "钱不够：撤离要 %d 币", "en": "Not enough coins: extracting costs %d"},
	"notice.nothing_to_reopen": {"zh": "这里没有能再打开的东西", "en": "There's nothing here to reopen"},
	"notice.pick_spawn": {"zh": "先在地图上挑一个出生点", "en": "Pick a starting point on the map first"},
	"notice.countdown": {"zh": "倒计时只剩 %d 步", "en": "Only %d steps left"},
	"notice.erosion_warned": {"zh": "侵蚀快到了：还有 %d 步", "en": "Erosion is coming: %d steps left"},
	"notice.erosion_advanced": {"zh": "外圈被侵蚀了", "en": "The outer ring has eroded"},
	"notice.erosion_total": {"zh": "全图都被侵蚀了，快撤", "en": "The whole map has eroded. Get out"},
	"notice.hunter_sensed": {"zh": "附近有动静……", "en": "Something stirs nearby..."},
	"notice.expelled": {"zh": "被赶了回来", "en": "You were driven back"},
	"notice.safe_closed": {"zh": "保险箱关上了：%d 件送回基地", "en": "The safe has closed: %d items sent home"},
	"notice.at_extract": {"zh": "到了撤离点：按「撤离」结束这一局", "en": "Extraction point reached: press Extract to end the run"},
	"notice.at_extract_paid": {"zh": "到了撤离点：按「撤离」结束这一局，要 %d 币", "en": "Extraction point reached: press Extract to end the run (costs %d)"},
	"notice.encumbrance": {"zh": "负重变成「%s」", "en": "Load is now \"%s\""},
	# 173：读档修复报告（一句，各段用分号连）
	"repair.head": {"zh": "存档修复：", "en": "Save repaired: "},
	"repair.sep": {"zh": "；", "en": "; "},
	"repair.prev": {"zh": "存档文件损坏，已从上一份恢复", "en": "the save file was damaged and the previous copy was restored"},
	"repair.salvaged": {"zh": "进行中的那一局因版本更新作废，带着的东西已放回仓库", "en": "the run in progress could not continue after the update; what you carried is back in the warehouse"},
	"repair.refunded": {"zh": "%d 件道具已随版本更新折算为 %d 钱", "en": "%d items removed by the update were refunded for %d coins"},
	"repair.replaced": {"zh": "%d 件换成了新版本里的对应道具", "en": "%d items were replaced with their new versions"},
	"repair.rehomed": {"zh": "%d 件放不回原位，换了位置", "en": "%d items did not fit their old spot and were moved"},
	"repair.dropped": {"zh": "%d 件按版本说明移除", "en": "%d items were removed as the update notes say"},
	"repair.unenchanted": {"zh": "%d 件的附魔已失效、被摘掉", "en": "%d enchantments no longer exist and were removed"},     # 175
	"slots.newer_tag": {"zh": "　（更新版本的存档）", "en": " (saved by a newer version)"},
	"menu.meta": {"zh": "仓库与战绩", "en": "Warehouse & records"},
	"menu.settings": {"zh": "设置", "en": "Settings"},
	"menu.encyclopedia": {"zh": "百科", "en": "Encyclopedia"},
	"menu.dev_tools": {"zh": "开发工具（沙盒与编辑器）", "en": "Dev tools (sandboxes & editors)"},
	"menu.quit": {"zh": "退出", "en": "Quit"},
	"menu.language": {"zh": "语言：中文（点击切换 English）", "en": "Language: English (click for 中文)"},
	"menu.stats": {"zh": "第 %d 局　撤离 %d 次　战败 %d 次　仓库 %d 件　累计价值 %d　钱 %d", "en": "Run %d · extracted %d · died %d · warehouse %d items · score %d · funds %d"},
	# buff 制作器
	"buff.title": {"zh": "Buff 制作器", "en": "Buff maker"},
	"buff.list": {"zh": "Buff", "en": "Buffs"},
	"buff.new": {"zh": "新建", "en": "New"},
	"buff.rescan": {"zh": "刷新列表", "en": "Rescan"},
	"buff.discard": {"zh": "放弃改动", "en": "Discard changes"},
	"buff.save": {"zh": "保存", "en": "Save"},
	"buff.save_as": {"zh": "另存为新 id", "en": "Save as new id"},
	"buff.id": {"zh": "id", "en": "id"},
	"buff.name": {"zh": "名字", "en": "Name"},
	"buff.debuff": {"zh": "是减益", "en": "Is a debuff"},
	"buff.stacking": {"zh": "叠层", "en": "Stacking"},
	"buff.stackable": {"zh": "可叠层", "en": "Stackable"},
	"buff.duration": {"zh": "时长", "en": "Duration"},
	"buff.permanent": {"zh": "永续（到战斗结束）", "en": "Permanent (until battle ends)"},
	"buff.permanent_forced": {"zh": "可叠层的 buff 一律永续", "en": "Stackable buffs are always permanent"},
	"buff.seconds": {"zh": "持续秒数", "en": "Seconds"},
	"buff.effects": {"zh": "效果（从预设里挑：属性加成 / 规则 / 施加时 / 到期时）", "en": "Effects (pick presets: mods / rules / on apply / on expire)"},
	"buff.code": {"zh": "代码编辑器（JSON，可直接改）", "en": "Code editor (JSON, edit directly)"},
	"buff.apply_code": {"zh": "套用上面的 JSON", "en": "Apply JSON above"},
	"buff.validation": {"zh": "校验", "en": "Validation"},
	"buff.saved": {"zh": "已保存 %s.json，并生成 %s.tres", "en": "Saved %s.json and generated %s.tres"},
	"buff.err_id": {"zh": "id 不能为空", "en": "id must not be empty"},
	"buff.err_save": {"zh": "有错误，没有保存", "en": "Errors: not saved"},
	"buff.err_json": {"zh": "JSON 语法错误", "en": "JSON syntax error"},
	"buff.err_write": {"zh": "作者数据写入失败", "en": "Could not write authoring data"},
	"buff.warn_asset": {"zh": "JSON 存了，但资产写入失败 —— 跑一次 import_content", "en": "JSON saved, but the asset failed to write — run import_content"},
	"buff.ok": {"zh": "✓ 没有问题", "en": "✓ No problems"},
	"buff.summary": {"zh": "%s　%s", "en": "%s · %s"},
	"buff.stacks_unlimited": {"zh": "不限层", "en": "unlimited stacks"},
	"buff.stacks_single": {"zh": "不可叠层", "en": "single stack"},
	"buff.usage": {"zh": "道具里这样引用：\"buff\": \"%s\"", "en": "Reference from an item: \"buff\": \"%s\""},
}


## 取一句；没有的键原样返回
static func t(key: String) -> String:
	return pick(TEXT.get(key, null), key)


## 一张「语言 → 文字」的小表按当前语言取；没有就中文、再没有给 [param fallback]；传进来的不是表就原样
## （null 给 [param fallback]）。界面文字、分类名、属性名……凡是 `{zh, en}` 小表都走这一条回退规则
static func pick(entry: Variant, fallback: String = "") -> String:
	if entry is Dictionary:
		var d := entry as Dictionary
		return String(d.get(lang, d.get("zh", fallback)))
	return String(entry) if entry != null else fallback


## 下一种语言（主菜单点一下切）
static func next_lang(current: String) -> String:
	var i := LANGS.find(current)
	return LANGS[(i + 1) % LANGS.size()] if i >= 0 else LANGS[0]


## 从设置里读当前语言
static func apply(settings: GameSettings) -> void:
	if settings != null and LANGS.has(settings.language):
		lang = settings.language
