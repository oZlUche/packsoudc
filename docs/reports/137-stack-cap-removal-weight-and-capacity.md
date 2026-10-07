# 137 方案：去掉 buff 的叠层上限（可叠 = 不限，不可叠 = 固定一层）；道具重量按名称与标签重配（金属更重）；初始负重上限上调

- 日期：2026-10-07
- 提出：作者（架构设计线程）
- 性质：架构 · 提议（本线程只写方案，不实现、不跑测试）
- 作者原话：「删除道具的叠层上限，可以叠层的效果没有上限，不可叠层的效果才是固定一层（比如未来会引入的无敌）。另外对道具的重量进行和名称和tag的匹配，比如金属质地的道具肯定会更重一些，另外增加初始负重上限」
- 三件事互不依赖，可以分三个提交做；第二、三件要一起上线（重量变了上限不变会全员超重）。

## 一、叠层上限：`max_stacks: int` → `stackable: bool`

### 现状

`BuffDef.max_stacks`（`core/battle/buff_def.gd:22`）一个整数三种含义：0 = 不限层、1 = 不可叠层、N = 至多 N 层。读它的地方：

| 位置 | 用法 |
|---|---|
| `buff_instance.gd:42` `add_stacks` | `min(stacks, max_stacks)` 封顶 |
| `buff_def.gd:32` `is_stackable()` | `max_stacks != 1` |
| `content_importer.gd:182` | 可叠层的不许填时长（085 规矩） |
| `content_importer.gd:369` `warn_unbounded_percent` | 不限层 + 百分比乘 → 提醒填上限 |
| `glossary.gd:149`、`ui_text.gd:77-79`、`buff_editor.gd:254-266 / 415 / 459` | 「不限层 / 至多 N 层 / 不可叠层」三态显示与编辑 |
| `field_text.gd:28` | 字段名「叠层上限（0 = 不限）」 |

数据里填了上限的只有两处：130 的 **嗜血**（6 层）和 **血勇**（5 层）—— 130 当时就是为了封顶才把它们做成 buff 而不是标准轴。
`faiths/*.json` 里的 `max_stacks` 是 **`FaithBonus.max_stacks`**（095：按信力每 N 点算一份、最多几份），是另一个类的字段，和 buff 无关，不动（待定 1 建议顺手改名）。

### 改成

- `BuffDef.stackable: bool = true`。**可叠 = 不限层，不可叠 = 固定一层**；`is_stackable()` 直接返回它；`add_stacks` 去掉封顶。
- 085 的规矩不变：可叠层永续、不填时长；不可叠层才可以过期 —— 「无敌」将来就是 `stackable: false` + `duration_sec`。
- 导入器：`stackable` 缺省 true；**老字段 `max_stacks` 迁移**（0 或 ≥2 → true，1 → false），带一条 warn「`max_stacks` 已改成 `stackable`，上限不再有」，`normalize_content` 把 JSON 重写成新字段（和 133 迁移旧键同一条路）。
- `warn_unbounded_percent` **删掉**：作者定了不限层，这条提醒对每个乘算 buff 都会响，没有信息量。
- 编辑器：`buff_editor` 的上限数字框换成「可叠层」勾选；`PropertyForm` 的字段表、`field_text` 改名「可叠层」。
- 文案：`glossary` / `ui_text` 只剩两态「不限层」「不可叠层」，删 `buff.stacks_cap`。
- 嗜血 / 血勇：去掉上限，其余不动。130 的顾虑（和流血的无限层一起会失控）由作者承担；若实际跑起来过猛，调每层的数而不是回加上限。
- 测试：`test_content_pipeline.gd` 里 `max_stacks: 10 / 5 / 3` 的用例改写成 `stackable`，`t_rage3`（上限 3 的叠层）改成「叠到 10 层不封顶」；百科 / 术语「buff 与叠层」页末删「层数上限」一句。

## 二、重量：按名称与标签重配，金属更重

### 现状（`core/inventory/item_weight.gd`，129）

公式 = 格数 × 每格重：`heavy` 3、`metal` 2、轻材（药、食、弹、符号、珍宝…）半格一重、其余 1；31 件写死。
金属只比木头 / 骨头重一倍，和同格数的皮甲、陶罐差不多：制式短剑 4 ≈ 皮甲 4，圆盾 8 = 两个皮革包 + 口粮，铜齿轮 2 = 两根干草药，魔晶石和陶罐一样是每格 1。

### 新的材质档（从上到下取第一个命中）

| 档 | 判定 | 每格 | 例 |
|---|---|---|---|
| 重型 | `heavy` | **4** | 板甲 36、塔盾 24 |
| 金属 | `metal` | **3** | 长剑 9、制式短剑 6、匕首 3、圆盾 12、弯刀 9、铜齿轮 3、鎏金酒杯 3、腐蚀香炉 6 |
| 石与晶 | `gem`、以及名字带「石」「晶」「盐」的（标签 `stone`，新加） | **2** | 魔晶石 4、破碎的魔晶石 2、琥珀原石 2、异化黑曜石 2、水晶簇 8、粗盐块 2 |
| 轻材 | `remedy` / `food` / `ammo` / `keepsake` / `sigil` / `treasure` / `relic` | 半格一重（向上取整） | 不变 |
| 一般 | 其余（木、骨、皮、布、陶、皮包） | 1 | 不变 |

`stone` 是新标签（【自然】档的材质标签，给矿石以外的石头 / 晶体 / 盐），现有 `gem` 的那几件不必补 `stone`，公式两者任一命中。

### 写死值跟着名字再过一遍（只列改的）

| id | 名称 | 现在 | 改成 | 理由 |
|---|---|---|---|---|
| `warhammer` | 战锤 | 9 | **12** | 要比长剑（9）重 |
| `oil_lamp` | 铜油灯 | 3 | **4** | 铜的；公式 6 太重，手调 |
| `blessed_shield` | 技巧之神赐福的盾牌 | 2 | **6** | 四格的盾，哪怕是赐福也不该比口粮轻；留一半给「赐福」 |
| `spyglass` | 望远镜 | 1 | **2** | 黄铜筒 |
| `copper_ore` / `silver_ore` | 铜矿石 / 银矿石 | 2（公式） | 3（公式） | 和铜锭 / 银锭（3）齐 |
| `iron_ore` | 铁矿石 | 6 | 6 | 两格 ×3 = 公式，**去掉写死** |
| `copper_ingot` / `silver_ingot` / `steel_ingot` / `rivet_box` | 锭、铆钉盒 | 3 | 3 | 一格 ×3 = 公式，**去掉写死** |
| `nail_keg` | 铁钉桶 | 12 | 12 | 四格 ×3 = 公式，**去掉写死** |
| `quartz_cluster` | 水晶簇 | 6 | 8 | 石与晶档的公式，**去掉写死** |
| `warped_obsidian` / `raw_salt` | 异化黑曜石 / 粗盐块 | 2 | 2 | 公式，**去掉写死** |
| `antler` | 鹿角 | 3 | **2** | 三格但是空心的角 |
| `clay_pot` | 陶罐 | 4 | **3** | 129 正文说陶罐该轻，没落实 |
| `leather_armor` | 皮甲 | 4 | 4 | 不动：皮的就是一般档 |
| `longbow` / `shortbow` / `blessed_longbow` | 弓 | 4 / 3 / 4 | 4 / 3 / 4 | 不动：木的 |

原则：**公式算得对的就不写死**（这次能去掉十一件的写死值），名字说它和材质不符的才写死。全表（96 件未封存）由执行线程按上表与公式生成后贴进附录，并更新 129 附录 A 的「定稿」列为「137 定稿」。

### 配套

- `ItemWeight.formula` 加石与晶一档、每格重改数；`docs/architecture.md` 7.6 与百科「负重」页的每格重跟着改。
- 导入器：道具同时带 `metal` 与 `heavy` 以外两档材质标签（如 `metal` + `stone`）不报错，按先命中的算。
- 悬浮窗「重 {weight}」不变。

## 三、初始负重上限上调

### 为什么要调

新公式下标准初始包（两皮革包 + 制式短剑 + 内甲 + 伤药 + 纱布 + 口粮）= 3 + 3 + 6 + 1 + 1 + 1 = **16**（原 14）。
一套中期常见配置「长剑 + 圆盾 + 皮甲 + 两包 + 四件消耗品」= 9 + 12 + 4 + 6 + 4 = **35**，按现在的 28 / 34 / 40，安德烈乌斯和马库斯一上手就「吃力」。
棋盘 48 格、平均每格约一重半，装满约 70。

### 新上限

| 角色 | 现在 | 改成 | 初始包占比 | 「中期配置」35 |
|---|---|---|---|---|
| 安德烈乌斯 | 28 | **40** | 四成 | 轻装 |
| 马库斯 | 34 | **48** | 三成三 | 轻装 |
| 布鲁图斯 | 40 | **56** | 两成九 | 轻装 |

三级门槛 1.0 / 1.25 / 1.5 不动；科技「扛重」每级的加数不动（相对占比变小，可以在 techs.xlsx 里把三级改成 +4 / +8 / +12，待定 3）。
136 的角色表里写的 28 / 34 / 40 以本篇为准。

## 四、改动清单

| 文件 | 改什么 |
|---|---|
| `core/battle/buff_def.gd`、`buff_instance.gd` | `stackable`；去封顶 |
| `core/authoring/content_importer.gd`、`normalize_content` | 迁移 `max_stacks`；删 `warn_unbounded_percent`；`stone` 标签 |
| `ui/buff_editor/buff_editor.gd`、`core/authoring/field_text.gd`、`core/text/glossary.gd`、`ui_text.gd` | 两态显示与勾选 |
| `data/authoring/items/bloodlust_bracer.json`、`bloodhound_sigil.json` + 四件 `max_stacks: 1` 的 | 重写成 `stackable` |
| `core/inventory/item_weight.gd` | 新档与每格重 |
| `data/authoring/tags/stone.json`、相关道具加标签 | 石与晶 |
| `data/authoring/items/*.json` | 第二节的写死值增删 |
| `data/authoring/characters/*.json` | 40 / 48 / 56 |
| `docs/architecture.md` 7.6、`docs/encyclopedia.md`、百科「负重」「buff 与叠层」页、129 附录 A | 回写 |
| `tests/authoring/test_content_pipeline.gd`、`tests/run/test_encumbrance.gd`、`tests/battle/test_status_synergy.gd` | 第五节 |

## 五、测试

- 叠层：`stackable: true` 的 buff 叠到 50 层不封顶；`false` 的叠两次还是 1 层；老 JSON `max_stacks: 6` 导入 → `stackable == true` 且有迁移 warn，`normalize` 后文件里没有 `max_stacks`；可叠层填时长仍报错；嗜血叠 10 层的急速 = 每层 × 10。
- 重量：长剑 9、圆盾 12、板甲 36、魔晶石 4、战锤 12、口粮 1；标准初始包 16；去掉写死的十一件公式值与原值一致。
- 上限：三人开局读数「负重 16 / 40」「16 / 48」「16 / 56」均为轻装；35 重在三人都轻装、安德烈乌斯 41 重「吃力」。

## 六、待定（都按推荐做）

1. **`FaithBonus.max_stacks` 要不要改名**（避免和 buff 的旧字段混）。推荐：**改成 `max_shares`**，导入器迁移旧键，和本篇一起做。
2. **赐福盾 2 → 6**。推荐：**改**；「赐福」体现在效果不在重量。
3. **「扛重」科技的加数**要不要随上限放大。推荐：**不动**，先看三档上限够不够。
4. **嗜血 / 血勇每层的数**要不要因为去上限而下调。推荐：**不动**，跑过再说。
5. **皮甲是否算「轻甲」减半**。推荐：**不**，皮的就是一般档 4。
