# 英文核心词表（221 F）

这张表定的是玩家会反复读到的那些词的英文。界面（`UiText`）、事件、教练和百科的英文都照它写。原则如下：

- **数据里已有英文名的，以数据为准**，这张表只是抄过来，方便查（道具 / 敌人 / buff / 标签 / 信仰 / 反应 / 章节 / 伤害类型的 `display_names.en`）。
- 数据里没有的词，由这张表定。改词要先改这张表，再全局替换。
- 英文正文里的数字写成单词（three seals, four steps）。读数本来就是数字的地方（`%d`、面板上的数值）不受这条限制。
- 专有名词首字母大写（Faith、Stamina、Warehouse）；句中的普通用法小写（"your bag", "the board"）。

## 流程与地图

| 中文 | English | 备注 |
|---|---|---|
| 一局 | run | |
| 序章 | Prologue | 章名见数据：Prologue: Edge of the Ruins / Prologue II: The Fork / Prologue III: The Altar |
| 自由模式 | Free mode | 章名 Magic Ruins |
| 机关沙漏 | Clockwork Hourglass | 章名 |
| 开局（屏） | Setup | |
| 出发 | Set out | 开局屏按钮 |
| 出生点 | starting point | |
| 节点 / 点 | node | 句中多写 "spot"、"place" |
| 搜索 / 搜索点 | Search / search spot | |
| 战斗 / 遭遇 / 精英 / 首领 | battle / encounter / elite / boss | |
| 商店 | Shop | |
| 休息 / 营地 | Rest / camp | |
| 神坛 / 祭坛 | Altar | |
| 宝箱 | Chest | |
| 保险箱 | Safe | |
| 铸炉 | Forge | |
| 撤离 / 撤离点 | Extract / extraction point | 已有 UiText |
| 倒计时 | Countdown | 已有 UiText |
| 侵蚀 | Erosion | 已有 UiText |
| 体力 | Vitality | 一局里输了扣的那个 |
| 钱 / 币 / 钱袋 | coins / coin / Purse | |
| 结算 | Results | |
| 战利品 | Loot | |
| 地上 | Ground | `TERMS_EN` |
| 仓库 | Warehouse | `TERMS_EN` |
| 包架 | Bag Rack | 225：局外放包的那一列（UiText `rack.title`） |
| 本图规则 | Map rules | |
| 百科 | Encyclopedia | 链接短写 "Codex >" 不用，统一 "Encyclopedia" |
| 图鉴 | Collection | |
| 日志 | Log | |
| 暂停 | Paused | |

## 背包与道具

| 中文 | English | 备注 |
|---|---|---|
| 背包 / 背包窗 | Pack / pack window | 指整个棋盘界面 |
| 包 | Bag | `TERMS_EN`；道具名见数据 |
| 棋盘 | Board | `TERMS_EN` |
| 格子 | cell | |
| 旋转 | rotate | |
| 合成 | Craft | |
| 整理背包 | Sort pack | |
| 全部拾取 | Take all | |
| 稀有度 | Rarity | |
| 重量 | Weight | |
| 价值 | Value | |
| 耐久 | Durability | |
| 标签 | Tag | |
| 相邻 | Adjacency / adjacent | |
| 特殊道具 | Keepsake | 标签名 |
| 信物 | Anchor | 标签名（数据已有） |
| 护符 | Charm | 道具名见数据 |
| 魔晶石 | Crystal | |
| 腰带 | Belt | |
| 负重 | Load | 已有 UiText（"Load is now …"）；档位名见数据：Burdened / Overloaded |
| 火漆签 | wax seal | 背包窗底下三枚 |
| 耐力档 | stamina band | |
| 估算输出 | est. damage | |

## 战斗

| 中文 | English | 备注 |
|---|---|---|
| 战前准备 | Pre-battle | `TERMS_EN` |
| 开战 / 迎战 | Fight | `TERMS_EN` |
| 回放 | Replay | |
| 播放 / 暂停 / 倍速 / 跳过 | Play / Pause / Speed / Skip | |
| 时间轴 | timeline | |
| 生命 | Health | `STAT_NAMES` |
| 耐力 | Stamina | |
| 法力 | Mana | |
| 格挡 | Block | `STAT_NAMES` |
| 护甲 | Armor | |
| 急速 | Haste | |
| 冷却 | Cooldown | |
| 暴击 | Crit | |
| 伤害 | Damage | |
| 增益 / 减益 | buff / debuff | |
| 层 / 层数 | stack / stacks | |
| 反应 | Reaction | 反应名见数据 |
| 元素名（反应用） | Fire / Ice / Volt / Toxin / Blood | `ReactionResolver.ELEMENT_NAMES` |
| 伤害类型 | Physical / Fire / Ice / Lightning / Toxin / Bleed / Drain / Reflect | 数据 |
| 赢了 / 输了 / 平局 | Victory / Defeat / Draw | |

属性轴的正负名（`StatAxes.TABLE`），有同名 buff 的取 buff 的英文名：

| 轴 | 正 | 负 |
|---|---|---|
| attack_speed | 加速 Haste | 减速 Slow |
| damage_dealt | 强攻 Might | 虚弱 Weak |
| damage_taken | 易伤 Vulnerable | 坚韧 Hardy |
| regen_hp | 回春 Renewal | 失血 Bleeding Out |
| regen_hp_pct | 再生 Regeneration | 腐蚀 Corrosion |
| regen_stamina | 回气 Second Wind | 疲乏 Fatigue |
| crit_chance | 锐目 Keen Eye | 失准 Off Target |
| crit_damage | 致命 Lethal | 钝击 Blunted |
| fire_damage | 炽烈 Blaze | 熄火 Doused |
| stamina_cost | 灵巧 Nimble | 笨拙 Clumsy |
| block | 加固 Fortified | 破绽 Exposed |
| max_hp | 生长 Vigor | 衰颓 Decline |
| max_mana | 充盈 Brimming | 枯竭 Drained |

## 信仰

| 中文 | English | 备注 |
|---|---|---|
| 信仰 | Faith | `Glossary.FAITH_WORD` |
| 信力 | Faith | 读数；需要区分时写 "Faith points" |
| 阶 | Rank | |
| 献祭 | Offering | |
| 神名 | 见数据 | The Brute / The Sun God / … |

## 人物与口吻

| 中文 | English | 备注 |
|---|---|---|
| 军团 | the Legion | |
| 接应者 | the handler | |
| 军团的交代 | The Legion's Briefing | 事件标题 |
| 角色名 | 见数据 | Brutus / Marcus / Andreus |

交代、教练、事件里的英文用接应者的口吻：短句，第二人称，不带说明书腔。百科用手册口吻。

## F5 补充（221 §九）

| 中文 | English | 备注 |
|---|---|---|
| 轻装 | Unburdened | 负重第 0 档；吃力 / 超重见负重 |
| 随身（商店那一排） | Carried | 随身技能写 carried tool |
| 猎手名 | 见数据 | 追猎者 Stalker、守路人 Road Warden |
| 猎手的输法 | 见数据 | 击退 Repel、驱逐 Expel、驱逐并驻守 Expel and Hold |
| 角色技能 | 见数据 | Old Paths / Slippery / Raised in the Wild / Tough / Spoils of War / Drill / Second Wind / Assault / Slip |
| 自发 / 开战时 / 出手时 / 受伤时 | Automatic / At battle start / On attack / When hit | 时机类别名（`Glossary.TRIGGER_NAMES`） |
| 增益 / 减益 / 系统 | Buff / Debuff / System | 状态悬浮窗名字行右边的小字 |
| 背包搜打撤（游戏名） | Pack & Extract | 作者 2026-10-21 定；主菜单兜底标题、启动屏 |
| 基地 / 科技 / 成就 / 出售 | Base / Tech / Achievements / Sell | F5b 局外屏 |
| 诅咒之地 | Cursed Lands | 成就说明 |
| 进阶难度 | Ascension | 难度名 Ascension I… |
| 底色：石墨 / 深夜 / 石板 / 暮色 / 苔绿 / 雾灰 | Graphite / Midnight / Slate / Dusk / Moss / Mist | 设置屏 |
| 光标：秘银 / 铁 / 皮革 | Mithril / Iron / Leather | 设置屏 |
| 仓库页签「一 / 二 / 三」 | 1 / 2 / 3 | 英文写数字 |

规则句（道具悬浮窗）的英文：扳机写成方括号里大写开头的短句（[When hit]），条件与效果小写接在后面，整行句首由 `Glossary.cap` 大写；伤害一律写「<类型名> damage」，`Glossary.mark_rich` 认这个写法上色。
