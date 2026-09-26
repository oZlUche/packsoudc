## 界面语言（085，作者定：主菜单切换中文 / 英语，编辑器等界面跟着走）。
##
## 一张键 → 两种文字的表；`t(key)` 按当前语言取，没有的键原样返回（写错一眼看得见）。语言存在 [GameSettings.language]，
## 主菜单切换后由持有方把 [member lang] 改过来。现在只有主菜单与 buff 制作器用它 —— 别的屏还是写死的中文，
## 逐屏换成 `UiText.t()` 就跟着切（15 节待办）。不是 autoload：一个静态变量就够，和 UiPalette 一样
class_name UiText
extends RefCounted

const LANGS: Array[String] = ["zh", "en"]
const LANG_LABELS := {"zh": "中文", "en": "English"}

static var lang: String = "zh"

const TEXT := {
	# 主菜单
	"menu.new_run": {"zh": "新的一局", "en": "New run"},
	"menu.new_run_to": {"zh": "新的一局 · %s", "en": "New run · %s"},
	"menu.replay": {"zh": "重玩教程（从「%s」开始）", "en": "Replay tutorial (from \"%s\")"},
	"menu.continue": {"zh": "继续上次", "en": "Continue"},
	"menu.meta": {"zh": "仓库与战绩", "en": "Warehouse & records"},
	"menu.settings": {"zh": "设置", "en": "Settings"},
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
	"buff.cap": {"zh": "叠层上限（0 = 不限，通常不限）", "en": "Stack cap (0 = none, usually none)"},
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
	"buff.stacks_cap": {"zh": "至多 %d 层", "en": "up to %d stacks"},
	"buff.stacks_single": {"zh": "不可叠层", "en": "single stack"},
	"buff.usage": {"zh": "道具里这样引用：\"buff\": \"%s\"", "en": "Reference from an item: \"buff\": \"%s\""},
}


## 取一句；没有的键原样返回
static func t(key: String) -> String:
	var entry: Dictionary = TEXT.get(key, {})
	if entry.is_empty():
		return key
	return String(entry.get(lang, entry.get("zh", key)))


## 下一种语言（主菜单点一下切）
static func next_lang(current: String) -> String:
	var i := LANGS.find(current)
	return LANGS[(i + 1) % LANGS.size()] if i >= 0 else LANGS[0]


## 从设置里读当前语言
static func apply(settings: GameSettings) -> void:
	if settings != null and LANGS.has(settings.language):
		lang = settings.language
