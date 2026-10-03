# 122 方案：非战斗道具首批（原矿、陶罐、布料……）—— 价值即用处、兼作科技材料；按是否人造分【工艺】/【自然】；技巧之神祭品加【工艺】

> 架构 · 提议（2026-10-03）。作者：「给世界添加更多道具，第一部分是非战斗道具，它们的用处就是价值本身和作为材料发展科技，因此种类可以多种多样：金属原矿、陶罐、布料等等，其中根据是否为人造物分成工艺和自然两个 tag，有多种稀有度和尺寸。另外，给技巧之神的祭品偏好里添加【工艺】tag」。

## 一、现状（已核实）

- 道具 65 件，带 `material`【材料】的 9 件（钢锭、硬木板、铆钉盒、碎骨串、骨骰子、魔晶石、毒药瓶、异化黑曜石……），其中 `supply`【建材】3 件是科技材料（110：商店不卖）。全部没有说明文字。稀有度分布 0：9 / 1：24 / 2：15 / 3：14 / 4：1 / 5：2。
- 价值：`ItemValue.of` = 每格基础价 `[5, 12, 30, 75, 200][稀有度]` × 格数；`ItemDef.value` 填正数才覆盖。**非战斗道具靠这条公式就够**，不用逐件填数。
- 搜索池：`SearchSession.candidates` = 全部未封存道具减 `exclude_tags`（只排 `treasure`），按 `rarity_weights [50, 30, 15, 4, 1]` × 深度 × 危险抽。新道具一登记就进池。
- 标签是数据（096，`data/authoring/tags/*.json`）：`nature`【自然】已有（「取自自然的东西：皮、木、草药。自然之神看重它」，10 件在用），**没有「工艺」**。`metal`【金属】是材质类标签，和人造 / 自然正交。
- 技巧之神（`skill.json`，由 `docs/gods.xlsx` 生成）献祭三条：`metal` ×5、防具 ×5、带暴击 ×8。**改献祭必须先改表**（104），直接改 JSON 测试会红。
- 科技材料走 118 / 119 的 `tiers[k].items`（id → 数量）。

## 二、两个标签

| id | 名 | 说明（词条） | tip |
|---|---|---|---|
| `crafted` 新 | 工艺 | 人手做出来的东西：陶、布、器具、锭。技巧之神看重它。 | true |
| `nature` 已有 | 自然 | 照旧 | true |

规则：**凡带 `material` 的道具，`crafted` / `nature` 二选一、必有一个**（导入时查，缺了或都有 → 提醒，不拦）。材质标签（`metal` / `gem` / `leather` / `bone`）照旧叠加：铁矿石 = `nature` + `metal`，铜锭 = `crafted` + `metal`。

现有材料按这条补标签：钢锭、铆钉盒、骨骰子、碎骨串、毒药瓶、硬木板 → `crafted`（木板是锯出来的，见待定 1）；魔晶石、异化黑曜石 → `nature`。

## 三、首批清单（二十六件）

共同点：`material` 标签、没有 `combat`、`value` 不填（走公式）、不带 `treasure`（要能搜出来）。形状按 0/1 矩阵，`1/1` 表示竖着两格。价值列是公式算出来的，只为看一眼分布。

### 自然（`nature`）

| id | 名 | 其他标签 | 形状 | 稀有度 | 价值 | 说明 |
|---|---|---|---|---|---|---|
| copper_ore | 铜矿石 | metal | 1 | 0 | 5 | 带绿锈的矿石，熔了就是铜。 |
| iron_ore | 铁矿石 | metal | 1/1 | 1 | 24 | 沉手的黑石，铁匠的饭。 |
| silver_ore | 银矿石 | metal | 1 | 2 | 30 | 石头缝里一线银光。 |
| flint | 燧石 | — | 1 | 0 | 5 | 敲一下就出火星。 |
| raw_salt | 粗盐块 | — | 1 | 0 | 5 | 没化开的盐，内陆值钱。 |
| oak_log | 橡木原木 | — | 1/1/1 | 0 | 15 | 一截还带树皮的硬木。 |
| ironwood_branch | 铁木枝 | — | 1/1 | 2 | 60 | 比铁沉的木头，难得。 |
| quartz_cluster | 水晶簇 | gem | 11/11 | 1 | 48 | 一丛透亮的石英。 |
| raw_amber | 琥珀原石 | gem | 1 | 2 | 30 | 封着一只远古小虫。 |
| beast_hide | 生兽皮 | leather | 111/111 | 1 | 72 | 刚剥下来的皮，还得鞣。 |
| fine_fur | 细毛皮 | leather | 11 | 2 | 60 | 雪地兽的冬毛，又软又密。 |
| antler | 鹿角 | bone, trophy | 11/10 | 1 | 36 | 一对分叉的角，猎人的凭证。 |
| dried_herbs | 干草药束 | — | 1 | 0 | 5 | 晒干扎好的草药。 |
| beeswax | 蜂蜡块 | — | 1 | 1 | 12 | 带蜜香的蜡。 |

### 工艺（`crafted`）

| id | 名 | 其他标签 | 形状 | 稀有度 | 价值 | 说明 |
|---|---|---|---|---|---|---|
| clay_pot | 陶罐 | — | 11/11 | 0 | 20 | 粗陶烧的罐子，装什么都行。 |
| glazed_vase | 彩釉瓷瓶 | — | 1/1 | 2 | 60 | 釉色流转，别磕了。 |
| linen_bolt | 亚麻布卷 | — | 111 | 0 | 15 | 一卷素色亚麻。 |
| wool_cloth | 羊毛呢 | — | 11 | 1 | 24 | 厚实的呢料，御寒。 |
| silk_bolt | 丝绸卷 | — | 111 | 3 | 225 | 光滑如水的一卷丝。 |
| rope_coil | 麻绳卷 | — | 1 | 0 | 5 | 盘好的粗麻绳。 |
| copper_ingot | 铜锭 | metal, supply | 1 | 1 | 12 | 熔好的铜，匀净。 |
| silver_ingot | 银锭 | metal, supply | 1 | 2 | 30 | 打了印记的银。 |
| nail_keg | 铁钉桶 | metal, supply | 11/11 | 1 | 48 | 一小桶铁钉。 |
| tanned_leather | 熟皮革 | leather, supply | 11 | 1 | 24 | 鞣好的皮，能直接裁。 |
| brass_gear | 黄铜齿轮 | metal | 1 | 2 | 30 | 齿口精细的小齿轮。 |
| oil_lamp | 铜油灯 | metal | 1/1 | 1 | 24 | 还有半盏油。 |
| gilded_goblet | 鎏金酒杯 | metal | 1 | 3 | 75 | 金皮包的杯子，贵族的。 |
| tapestry | 挂毯 | — | 111/111 | 3 | 450 | 织着狩猎图的整幅挂毯。 |

（`silk_bolt`、`tapestry`、`gilded_goblet` 三件稀有度 3，是「背出去就赚」的那一类；其余以 0～2 为主，免得把搜索池抬高。）

说明文字都照 112：无数字、无占位符，TextLint 过。英文名执行时按直译补 `display_names.en`。

## 四、科技材料接上

带 `supply` 的新材料进 118 的首批树（改 119 的 `docs/techs.xlsx` 等级表；119 未落地就改 JSON）：

| 科技 | 级 | 加材料 |
|---|---|---|
| 行囊 pack | 3 | tanned_leather 2、linen_bolt 1（linen_bolt 因此也加 `supply`） |
| 保险箱扩格 safe_box | 2 | 原 steel_ingot 2、rivet_box 1 → 改 nail_keg 1、steel_ingot 1 |
| 筋骨 sinew | 3 | copper_ingot 2 |
| 讨价 bargain | 2 | silver_ingot 1 |
| 仓库扩建 warehouse | 5 | 加 nail_keg 1 |

商店不卖 `supply`（110 规矩照旧）。

## 五、技巧之神

`docs/gods.xlsx` 献祭表加一行：`skill ｜ 技巧之神 ｜ tags: crafted ｜ 工艺品 ｜ 5 ｜ False`。跑 `tools/gods_xlsx_to_json.gd` → `skill.json` 多一条 `{"tags": ["crafted"], "multiplier": 5.0}`；镜像 `docs/gods.md` 对应行补上。铜锭献给技巧之神 = `metal` ×5 + `crafted` ×5（多条命中相加，表里备注 2 的规矩）。

## 六、搜索池的影响

二十六件里稀有度 0～1 的有十九件，现有池里 0～1 共三十三件，普通搜索里材料会占到四成上下。这正是作者要的「多种多样」；先不做按标签压权重，播测觉得「搜到一堆布」再加 `SearchRules.tag_weights`（见待定 2）。

## 七、改动点

| 文件 | 改动 |
|---|---|
| `data/authoring/tags/crafted.json` 新 | §二 |
| `data/authoring/items/<26 个 id>.json` 新 | §三 |
| 现有 8 件材料 JSON | 补 `crafted` / `nature` |
| `core/authoring/content_importer.gd` | `material` 必有且只有一个 `crafted` / `nature`：提醒 |
| `docs/gods.xlsx` + `tools/gods_xlsx_to_json.gd` → `faiths/skill.json`、`docs/gods.md` | §五 |
| `docs/techs.xlsx`（或 `techs/*.json`） | §四 |
| `tools/import_content.gd` | 跑一遍 |
| `tests/content/test_materials.gd` 新 | 二十六件都在库里、都可搜（`candidates` 含之）、`crafted`/`nature` 二选一、价值 = 公式；技巧之神对铜锭的献祭 = 10 × 2^稀有度；TextLint 过 |
| `docs/item-roster.md` | 加一节「非战斗材料（122）」指向本篇 |

## 八、待定（按推荐即执行）

| # | 问题 | 推荐 |
|---|---|---|
| 1 | 硬木板算工艺还是自然 | **工艺**（锯出来的）；自然之神少一件木头，换来规则干净 |
| 2 | 搜索池要不要按标签压材料权重 | **不压**，播测后再说 |
| 3 | 矿石带不带 `metal` | **带**（它就是金属，日神 / 技巧之神都收）；人造 / 自然只由 `crafted` / `nature` 表达 |
| 4 | 二选一规则导入时拦还是提醒 | **提醒**，和「标签未登记」同级 |
| 5 | 鹿角带 `trophy`（狩猎之神 ×10） | **带**，猎人的凭证本来就是战利品 |


## 补正（作者，2026-10-03）

魔晶石以及以后魔法相关的材料，不算【自然】也不算【工艺】，归新标签【魔法】`magic`。
材料的出身标签由二选一改为三选一：`crafted` / `nature` / `magic`，恰好带一个（导入时提醒，不拦）。
「破碎的魔晶石」`mana_shard` 与「魔晶石」`mana_crystal` 由【自然】改为【魔法】。
连带影响：这两件不再触发自然之神「带 `nature` 的道具」那条，也不再按自然之神祭品计价。
