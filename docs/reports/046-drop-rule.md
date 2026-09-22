# 046 · M4-2 掉落规则与尸体容器

> 阶段 5 · M4 ｜ 架构文档 6.1（v1.45）｜ 规划见[报告 045](045-m4-plan-and-enemy-pool.md)

作者的设想原话：

> 敌人的每件道具都有一定概率掉落，但稀有度越高基础掉落率越低，受以下修正：难度（正面加成）、幸运值增益/减益、
> 局外 buff（留空占位，保留接口方法）、地图 buff（留空占位）。另外，每个敌人都有概率掉落自身未持有的高稀有度道具
> （最高一级红色和第二级金色），且一定是「珍宝」类型（未详细定义，留空占位）。

## 产出

| 文件 | 职责 |
|---|---|
| `core/loot/drop_rule.gd` | `DropRule`：按稀有度的基础掉落率表（非递增）、难度 / 幸运每级加多少、珍宝概率与稀有度权重、珍宝标签。作者数据，走管线 |
| `core/loot/drop_bonus_source.gd` | `DropBonusSource` 抽象：`owned_bonus(ctx, def)` / `treasure_bonus(ctx)` —— 局外 buff 与地图 buff 的**接口方法** |
| `core/loot/meta_drop_bonus.gd`、`map_drop_bonus.gd` | 两个**占位**实现，现在都加 0；将来从 meta 存档 / 章节区域定义里读 |
| `core/loot/loot_context.gd` | 加 `difficulty`、`luck`、`sources`；原有四个量（rolls、rarity_bias、category_bias、drop_owned_chance）各自有了在掉落里的用处 |
| `core/loot/drop_resolver.gd` | `DropResolver`：每件的概率、珍宝概率、掷、期望件数、尸体容器 |
| `core/run/chapter_def.gd` | 加 `drop_rule: StringName`（按 id 引用） |
| 内容管线 | 新种类 `drop_rules`（在 enemy_pools 之后、chapters 之前）；`import_drop_rule` + 校验；导出、命令行导入、normalize 各一分支 |
| `data/authoring/drop_rules/standard.json` → `data/drop_rules/standard.tres` | 第一章的规则（占位数值）；`chapter_01` 引用它 |
| `ui/map/map_sandbox.gd` | 悬停战斗点的那一行多了「预计掉 x 件，珍宝 y%」 |
| `tests/test_drop_resolver.gd` | 6 组 |

## 怎么算

**每件各掷一次。** 敌人自己的每件道具：

```
p = base_chance[稀有度]                 # 表，非递增：越稀有越难掉（导入器校验）
  + difficulty × difficulty_bonus       # 难度只做正面加成（负难度按 0）
  + luck × luck_bonus                   # 幸运可正可负，减益就是负的幸运
  + drop_owned_chance                   # 道具 / 套装的战利品效果（M2 就有的接口）
  + Σ source.owned_bonus(ctx, def)      # 局外 buff、地图 buff（占位，各 0）
夹进 0～1
```

**珍宝。** `rolls` 次尝试（基础 1，「掉落次数 +1」的效果加在这里），每次按
`treasure_chance`（默认也吃上面那套修正，`treasure_modified` 可关）掷；中了按 `treasure_weights`（+ `rarity_bias`）抽稀有度，
再在「带 `treasure_tag`、这个稀有度、敌人**没有**」的道具里抽一件（`category_bias` 加权）。
这一档没有就退到表里别的档；哪一档都没有（珍宝还没定义，现在就是这样）就记一笔 `treasure_missing`，不掉、不报错。

**尸体容器**就是一个 `GridInventory`：大小照敌人的棋盘，掉下来的 + 珍宝 `try_add` 进去，塞不下就加高（最多到两倍）。
搜刮界面（M4-3 / M6）直接拿它当容器，M1 的代码原样复用 —— 6.1 一开始就是这么写的。

## 关键决策

- **规则是数据，不是代码里的常量。** 作者说的每一条（递减、难度、幸运、珍宝的两档）都是 `DropRule` 的字段；
  「越稀有越难掉」写成导入器校验而不是注释。
- **修正全是加法、同一个单位**（0.05 = 5 个百分点）。乘法会让难度和幸运互相放大，调一个数看不清另一个的效果。
- **局外 / 地图 buff 是接口不是字段。** 作者要求留空占位、保留接口方法：`DropBonusSource` 两个方法，`LootContext.sources` 装它们。
  `DropResolver` 现在就调它们，接上的那天规则与测试一行不改；沙盒已经把两个占位来源装进去了。
- **珍宝类型用标签占位。** 「珍宝」作者没细定，`treasure_tag`（默认 `treasure`）说哪些道具算珍宝。仓库里现在没有一件带这个标签，
  所以第一章掉不出珍宝 —— 测试就是这么断言的；定义了珍宝道具之后这条断言会红，提醒把它改成正面的。
- **珍宝一定不是敌人自己有的。** 候选排除 `content.items` 里的 id：地图上看到它背什么，就知道那不是珍宝会掉的。
- **M2 的四个量都有了归宿。** `rolls` = 珍宝尝试次数，`rarity_bias` = 珍宝稀有度权重偏移，`category_bias` = 珍宝候选加权，
  `drop_owned_chance` = 自身道具概率加成。套装与道具的战利品效果不用改一个字。
- **幸运值谁给，这里不管。** `LootContext.luck` 是个数；角色、buff、道具将来往里填。

## 验证

```
bash tools/test.sh
通过  5530 项断言，33 个套件，耗时 80 秒
```

- 概率：五档裸概率 = 表；逐档不增；难度 2 加两份、负难度不扣；幸运 ±5 各加减五份；效果 +15% 加进来；
  测试来源加 0.1、两个占位来源加 0；珍宝概率吃来源与难度、`treasure_modified` 关掉只剩基础；封顶 1 封底 0；超表长按最后一档。
- 掷：同种子同结果；掉的都是自己有的；概率全 1 全掉、全 0 不掉；0.8 掷一千次落在 740～860。
- 珍宝：带标签、稀有度在表里、不是自己有的；自己背着的金不当珍宝掉；没标签的传说品不算；金 3 : 红 1 一千次红在 180～320；
  `rarity_bias` +30 之后红 > 800；`category_bias` 偏向带 weapon 的；`rolls` 3 → 三件；没有珍宝道具 → 不掉、记一笔、期望里不算；抽到金只有红 → 退到红。
- 期望与容器：期望 = 各件概率之和 + 尝试次数 × 珍宝概率；容器里正好是掉下来的；照敌人棋盘大小；塞不下加高。
- 管线：往返逐字节相同；递增、>1、键不是稀有度、权重 0、打错字段名 → 全错；仓库文件导得进、是导出器格式、资产一致；第一章引用得到；指向不存在的规则 → 错。
- 第一章：种子 1 全图每场掉的都是它背的、珍宝为零、尸体容器装下全部；总掉落数与期望差得不离谱。

## 没做的

- 珍宝道具本身（作者留空）。定义时给道具打 `treasure` 标签、稀有度 3 或 4 即可。
- 幸运值从哪来（角色 / buff / 道具属性）：M5 run 状态的事。
- 局外与地图 buff 的内容：两个占位类各有一个 `entries` 字典，接上时填它或换实现。
- 搜刮界面（6.2 渐进揭示）与「打赢了才掉」的接线：M4-3 / M4-4。
