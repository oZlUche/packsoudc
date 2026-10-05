# 125 方案 + 文案：百科机制页四十五页全文（流程 / 背包 / 战斗 / 信仰 / 地图 / 局外）

> 架构 · 提议 + 文案（2026-10-05）。作者：「补充百科」。114 定了框架、落地时只写了「合成」一页；本篇把 `docs/encyclopedia.md` 清单里的页全部写出来，执行线程照抄进 `data/authoring/help_pages/<id>.json`。

## 一、怎么用这份文案

- 每页一个块：`### <id> · <标题>`、`category` / `order`、`related`、`see_items`、`sources`、`text:` 正文。字段一一对应 `HelpPageDef`；`texts.en` 这次不写（57 个事件都还没英文，百科不抢先）。
- 正文已按 112 规矩写：**全文零阿拉伯数字**（脚本核过）、占位符只用 `docs/text-placeholders.md` 里的（`{zone:…}` `{key:…}` `{faith:…}` `{char}`）、词条名（防护 / 护盾 / 急速 / 叠层 / 永续 / 耐力 / 冷却 / 信力 / 增益槽 / 受益槽 / 中毒 / 流血 / 自发 / 合成）按原词写好让链接自动生效。`related` 只填页 id 或词条名，`see_items` 只填库里有的道具 id。
- 现有 `crafting.json` 补 `"order": 4`（背包分类第五页）。
- 执行时跑 `tools/import_content.gd`，导入器会查分类 / 非空 / `see_items` 存在 / 占位符存在 / `related` 指得到 / 无裸数字；任何一页红了改文案不改规则。
- 测试 `tests/content/test_help_pages.gd`：四十六页（含合成）都在；每个分类的 `order` 连续；每页 `related` 都能解析；百科目录按分类 → order 排；搜索「护盾」能命中 shield 页与词条页。

## 二、起草时标了「待核」的地方，已核

| 页 | 疑问 | 核对结果 |
|---|---|---|
| bags | 药水带是不是「只收药剂 / 食物」的包 | **是**：`belt_potion.is_bag = true`，`bag_accept_tags = [remedy, food]`，照写 |
| grant_receive_slots | 毒箭的增益槽是不是挂在弓上 | **是**：`poison_arrows.adjacency.grant_filter = [ranged]`，`grant_rules` 出手上毒，照写 |
| shield | 护身符是否仍在战斗中叠护盾 | **是**：`warding_charm` 每秒给自己一层「护符结界」（护盾上限 +），照写 |
| haste | 冷却按「工作量」还是「快照」 | **按代码（快照）**写；架构 4.7 那段由文档线程改口 |
| god_skill / god_hunt | 等级效果 | 按 JSON：**尚未加入**；`docs/gods.md` 第四节是 082 旧文，不以它为准 |
| special_rites | 赐福对象措辞 | 按代码：「包里能被赐福的最值钱那件，棋盘优先、其次暂存区」 |
| node_types | 节点浮窗要不要写「拿到望远镜才开」 | **保留**：`ChapterDef.node_tooltips` 默认关、`free_mode.json` 没开 |
| rest_point | 休息回复量 | 文案不写数，无影响 |

正文里的 `<!-- 待核 -->` 注释执行时**删掉**，不进 JSON。

## 三、改动点

| 文件 | 改动 |
|---|---|
| `data/authoring/help_pages/<45 个 id>.json` 新 | §四 |
| `data/authoring/help_pages/crafting.json` | `order: 4` |
| `tests/content/test_help_pages.gd` 新 | §一 |
| `docs/encyclopedia.md` | 「首批要写的页」一节改成「已写（125）」 |
| `docs/architecture.md` 4.7 | 冷却改按快照语义描述（与代码一致） |

## 四、全文

# 百科机制页文案草稿（首批四十页）

> 格式照 docs/encyclopedia.md；文案照 data/authoring/help_pages/crafting.json 的口吻。正文无阿拉伯数字、不写具体数值，只写规则的形状。
> 分类内 order 从零起顺排；bag 分类里已有的 crafting.json 没写 order（默认零），建议补成 4 以对应 114 的目录顺序（拖放 → 包 → 双击 → 整理 → 合成 → 槽 → 信物）。
> `related` 只写页 id 或 Glossary.TERMS 里的词条名；`see_items` 都是 data/authoring/items/ 里有的 id。

---

## flow 流程

### map_and_steps · 地图与走步
- category: flow  order: 0
- related: [node_types, countdown_and_closing, staging_zone, teleport]
- see_items: none
- sources: docs/architecture.md 5.6（移动规则与行动计数）、core/run/run_state.gd（step_to / relocate / stepped）、core/run/map_travel.gd、docs/reports/092-countdown-safe-stash-sale.md
text:
地图是一张点和路组成的图。每次只能走到相邻的一个点，路是双向的，走回头路没有限制；走一条路花掉它写着的行动点，通常是一步。走过的点可以再经过、再停留，但那里的事不会再发生第二次。

地图屏按 {key:B} 开背包，鼠标停在点上能看浮窗。踩上一个没用过的点，它的事立刻发生：战斗先进战前准备，搜索与商店开会话，事件给选项。有倒计时的图每花一个行动点就少一步，猎手与侵蚀也按步推进。

### search_point · 搜索点
- category: flow  order: 1
- related: [battle_and_prebattle, staging_zone, node_types]
- see_items: none
- sources: core/run/node_events.gd（_open_search / pause_search / _after_battle）、core/run/search_session.gd、docs/architecture.md 6.2、docs/reports/084-node-screens-and-prebattle.md 第五节
text:
踩上搜索点先过一屏事件，选「搜索」就开始搜一次，这一次的收获在搜索屏里一件件亮出来，亮了的直接拖进包或{zone:暂存区}。关掉搜索屏回到事件屏，可以再搜，也可以走；每个点能搜的次数有上限，搜满了只能离开。

每多搜一次，撞上敌人的概率就更高。掷中遭遇的那一次什么都翻不到，直接迎战，先过战前准备；打赢了会话接着开、还能继续搜，打输了这个点被余波摧毁、不能再搜，但这一场不扣体力。敌人的战利品和之前没拿的收获并成一份。走得越远、搜得越多，遭遇的敌人越强。

### battle_and_prebattle · 战斗与战前准备
- category: flow  order: 2
- related: [auto_battle, vitality, extraction_and_defeat]
- see_items: none
- sources: ui/game/prebattle_screen.gd、core/run/node_events.gd（pause_before_battle / _battle_at / _after_battle、LOSS_DEFAULT）、ui/battle/battle_view.gd、docs/architecture.md 7.1、data/authoring/node_rules/standard.json（loss_cost）
text:
踩上战斗点、事件里选了开打、搜索遭遇，都先到战前准备屏。左边是对手的棋盘与读数，和真打用的是同一份编译；右边是自己的棋盘与{zone:暂存区}，可以随便拖。拖出棋盘的东西不参战，打完还在暂存区里。棋盘上没有一件会出手的道具时「开战」是灰的。

开战之后整场战斗在那一瞬算完，回放只是重演，倍速和跳过不改结果，战斗中没有任何操作。打赢了对手的东西摆进战利品箱等你拿；打输了扣体力，输赢都算用过这个点，没有再打一次。精英扣得更多，核心输了直接战败。

### staging_zone · 暂存区
- category: flow  order: 3
- related: [drag_and_rotate, quick_place, settlement_and_warehouse]
- see_items: none
- sources: docs/architecture.md 3.4、core/inventory/item_stash.gd、core/run/modules/node_storage_module.gd、docs/reports/084-node-screens-and-prebattle.md 第 6 条、docs/reports/092-countdown-safe-stash-sale.md 第四节
text:
{zone:暂存区}是棋盘之外的一切空间：拖出棋盘放手就进去，右侧那一列只是它的清单，没有坐标、不用摆、不限件数。里面的东西对任何系统都不存在：不参战、不吃邻接、不算套装、撤离时也不带出去。装着东西的包进不去，先掏空。

它是这个点上的临时区。走出一个点时，暂存区里的东西留在那个点上，回到那个点又回到暂存区，地图上标得出哪些点存着东西。撤离时暂存区里没背出来的那几件在结算屏上会提一句，离开结算屏时按基地的出售比例一键卖掉。

### extraction_and_defeat · 撤离与失败
- category: flow  order: 4
- related: [vitality, safe_box, countdown_and_closing, settlement_and_warehouse]
- see_items: none
- sources: core/run/run_state.gd（try_extract / extract_after_boss）、core/run/events/outcomes/extract.gd、core/run/modules/countdown_module.gd、core/run/run_result.gd、core/meta/meta_state.gd（absorb）、docs/architecture.md 5.8 / 6.6 / 8.2
text:
中途撤离点在地图中段，核心打赢了也算撤离。踩上撤离点先过一段对话，选项里撤；有些撤离点收费，付不起撤不了；倒计时过半时离出生点最近的免费撤离点会关闭，地图上提前标着剩几步。撤离带走的是棋盘上的全部，含包；{zone:暂存区}里的不算。

失败有三种：体力归零、核心那一场打输、倒计时归零。失败什么都带不出去，钱也没了，只有保险箱里的东西照样送回基地。从仓库带进来的东西，撤了就回来，死了就是真没了，这就是这个循环。

### vitality · 体力
- category: flow  order: 5
- related: [battle_and_prebattle, rest_point, erosion, hunters]
- see_items: none
- sources: core/run/vitality.gd、docs/architecture.md 7.1 / 7.3（free_losses）、data/authoring/node_rules/standard.json（loss_cost：battle / elite / search / hunter）、core/run/hunters/hunter_def.gd（flee_fail_vitality）、core/run/erosion/effects/erode_spend_vitality.gd、data/authoring/techs/undaunted.json
text:
体力是这一局「还剩几条命」，和战斗里的生命、耐力不是一回事：那两样每场重置，体力跨战斗保留。输一场普通战斗扣体力，精英扣得更多，输给猎手也扣；归零就是战败。核心那一场是例外，输了不论剩多少体力都直接战败。

休息点能回体力，扎营多花行动点多回一些；有的角色或科技让输给节点敌人的头一次免罚；侵蚀区里走路、逃跑失败、某些事件也会扣。上限由角色定，章节与局外加成能加。{char}的体力在地图屏上一直看得见。

### settlement_and_warehouse · 结算与仓库
- category: flow  order: 6
- related: [warehouse, codex, safe_box, staging_zone]
- see_items: none
- sources: docs/architecture.md 8.1 / 8.2、ui/game/result_screen.gd、core/meta/meta_state.gd（absorb / keeps）、docs/reports/090-setup-stash.md、core/run/modules/countdown_module.gd（带入预算，094）、core/run/run_result.gd
text:
一局结束就进结算屏。撤离了，棋盘原样带回来，拖进{zone:仓库}或一键置入，带回来的每件在图鉴里计一次，剩的钱全部带出；没置入的可以留着，进开局屏时它们会放进那一屏的暂存区，拖上包就带走，不管的出发就没了。战败只有保险箱里的东西。

仓库是基地的一块格子，不要求包，所以包进不了仓库，只记进图鉴。仓库里的东西能在开局屏拖进初始包带进下一局；带入有价值预算，超了按比例换掉倒计时。结算屏还写着这一局的步数、几场胜负与信力节奏。

---

## bag 背包

### drag_and_rotate · 拖放与旋转
- category: bag  order: 0
- related: [bags, quick_place, staging_zone, 合成]
- see_items: none
- sources: docs/architecture.md 3.3.1（顶替式放置）/ 3.6、ui/inventory/drag_layer.gd（头注释：包可替换包、drop_outside_to_stash、旋转脱落）、ui/game/inventory_panel.gd（操作提示行）、core/inventory/grid_inventory.gd（rotate_bag）
text:
左键按住一件道具就拿起来，拖的时候按 {key:R} 顺时针转一格，右键或 {key:Esc} 取消放回原处。落点按物品的左上角算，预览有三种颜色：绿是干净落点，黄是压着别人、放手会把人顶出来，红是地形不许，出界、没被包覆盖、跨了两个包、包不收这类标签都算。

顶出来一件直接拿在手上，多于一件全部进{zone:暂存区}。包不参与顶替：往包上丢东西是放进包里，拖一个包压到另一个包上是替换，旧包连内容物摘下、内容物进暂存区。装着东西的包能整体拖走，但换了朝向之后挂不住的内容物会脱落进暂存区。

### bags · 包
- category: bag  order: 1
- related: [drag_and_rotate, grant_receive_slots, warehouse]
- see_items: [bag_small, bag_leather, bag_long, belt_potion]
- sources: docs/architecture.md 3.2（棋盘 + 包体、跨包、包在自由容器里只是普通物品、没有装备栏）、core/inventory/item_def.gd（is_bag / bag_accept_tags / bag_mods）、core/meta/meta_state.gd（keeps）
text:
棋盘开局全是不可用格，可用格来自放上去的包：先放包，再往包里放东西。包之间不能重叠，普通道具的每一格都得被某个包覆盖，碰到的每个包都得接受它的标签，有些包只收药剂或食物。只有包里的东西参战，没有装备栏，空间是唯一的约束。

一件东西可以横跨两个相邻的包，但跨包的东西不属于任何包，两边的包体加成都拿不到，拿起包时它也不跟着走。包躺在战利品箱或{zone:暂存区}里只是件普通异形物品，到棋盘上才是包。包不进局外的仓库，所以既带不回去也带不进来。
<!-- 待核：belt_potion 是否确为「只收药剂 / 食物」的包（架构 v2.24 提到药水带准入改 remedy / food），写进 see_items 前请对一下 items/belt_potion.json 的 is_bag 与 bag_accept_tags。 -->

### quick_place · 双击快速置入
- category: bag  order: 2
- related: [drag_and_rotate, shop, safe_box, tidy]
- see_items: none
- sources: ui/game/inventory_panel.gd（quick_move / quick_target）、ui/game/container_screen.gd、ui/game/shop_screen.gd、ui/game/safe_screen.gd、ui/game/altar_screen.gd、ui/game/setup_screen.gd（109）、ui/game/warehouse_panel.gd、ui/game/meta_screen.gd（出售页）、ui/game/tech_panel.gd、core/inventory/grid_inventory.gd（find_first_fit）
text:
双击一件道具，它自动找位挪到「对面」：{zone:暂存区}里的双击进棋盘，放不下会提示；棋盘上的双击进当前屏的容器，战利品箱、搜索收获箱、祭品台、保险箱都算，没有容器时进暂存区。战利品箱里双击一件，亮了的才动，先试棋盘，放不下进暂存区。

商店里双击商品就是买，自动找位、先包后暂存区，钱不够没反应。基地也一样：仓库和带回来的棋盘之间双击互放，出售页双击一件卖一件，科技页双击一件交给选中的节点。自动找位按行扫过去，每个位置先试原朝向再转。

### tidy · 整理
- category: bag  order: 3
- related: [warehouse, quick_place]
- see_items: none
- sources: core/inventory/grid_tidy.gd（KIND_ORDER、头注释）、docs/reports/109-drop-stash-prompt-and-battle-speed-setting.md 第三节、docs/reports/110-warehouse-expansion-tech-and-tidy-by-kind.md 第一节、ui/game/warehouse_panel.gd
text:
{zone:仓库}的「整理」把格子里的东西重排一遍：占用的聚到左上，空格聚到右下。顺序是先同类再大小：武器，盾与防具，信仰道具，药剂与食物，弹药、工具与试剂，材料、零件与宝石，最后是珍宝与其他；同类里占格多的先放、小件去填缝，同大小稀有度高的在前。

整理永远不丢东西：有一件放不下就整批放回原位，什么都不变。它只认不要求包的自由容器，棋盘上摆的是阵，不归它管；同容器内挪位不算置入，不会改信物的激活顺序。

### grant_receive_slots · 增益槽与受益槽
- category: bag  order: 5
- related: [bags, auto_battle, multipliers, 增益槽, 受益槽]
- see_items: [poison_arrows, longbow]
- sources: docs/architecture.md 4.2「邻接标记：增益与受益」「这一步是去重计数」「连结关系」（含 108 的 grant_rules）、core/battle/adjacency_profile.gd
text:
道具轮廓外的相邻格可能标着格位，邻居占住它就点亮。增益槽是「我给邻居」：站在这些格子上、标签符合的邻居各得一份写着的加成，有的还会挂上一条规则，比如毒箭挨着弓，弓每次出手就多带一层中毒。受益槽是「邻居给我」：每被点亮一格，自己得一份加成。

一件邻居只能点亮一个增益槽和一个受益槽，大件压住三格也只算一个；同类格位各格同质，谁占哪格没有区别。格位随物品一起旋转。通过槽连在一起的两件是连结的，配件能听见那把武器出手。这些加成在开战前算一次，{zone:暂存区}里的东西不算邻居。
<!-- 待核：「毒箭挨着弓」例子来自架构 4.2（108），请确认 items/poison_arrows.json 的 adjacency.grant_rules 确实挂在弓上；若不是，see_items 换成别的带增益槽的道具。 -->

### anchor_and_right_click · 信物与右键
- category: bag  order: 6
- related: [anchor_activation, switch_and_dormant, drag_and_rotate]
- see_items: [charm_brute, charm_sun, charm_nature, charm_earth]
- sources: docs/architecture.md 3.8（置入序号、激活、休眠、切换）、docs/reports/099-faith-reseat-proposal.md、core/inventory/item_def.gd（is_anchor / dormant_keeps_combat）、ui/game/inventory_panel.gd（提示行「右键信物 = 奉为主信仰」）
text:
信物是带着某位神印记、能激活信仰的那类道具，护符就是；赐福版的武器防具带印记但不是信物。棋盘上最后置入的那枚信物决定你现在信谁，别的神的信仰道具就休眠：战斗里不出手、不给也不吃邻接，占格照占。一枚信物都没有就是不信者。

切换不花钱、不进菜单：右键棋盘上的信物就把它奉为主信仰，或者把它拿起来再放回棋盘任意位置。取消拖拽和放不回去都不切。切换本身不算置入，不记信力；各神的信力各自记着，切回来还在。

---

## combat 战斗规则

### auto_battle · 自动战斗怎么跑
- category: combat  order: 0
- related: [stamina_and_cooldown, buffs_and_stacks, multipliers, battle_and_prebattle, 自发]
- see_items: none
- sources: docs/architecture.md 4.1 / 4.2 / 4.4（四层结构）/ 4.7（模拟循环、加时与衰竭）、core/battle/battle_sim.gd、core/battle/overtime_rules.gd、core/battle/compiler.gd
text:
开战前先把棋盘编译成战斗单位：角色基线加上每件参战道具，包体、增益槽与受益槽、套装、信力阶的加成在这一步算成初始属性。然后整场战斗一次算完，回放只是重演，没有任何操作。战斗是事件驱动的，没有帧：每件道具按自己的冷却周期自发出手，模拟直接跳到下一个会发生事的时刻。

每条规则分四层：什么时候触发、多久一次、付什么代价、做什么。同一时刻先处理到期的 buff 再处理出手。打到一定时间进入加时：双方受到的伤害逐步增加，再往后生命上限逐步下降，所以没有平局；同一刻双双倒下按倒下前血量、再按总伤害裁决。

### direct_damage_and_armor · 直接伤害与防护
- category: combat  order: 1
- related: [shield, buffs_and_stacks, multipliers, 直接伤害, 防护]
- see_items: [tower_shield, poisoned_knife]
- sources: core/battle/damage/damage_resolver.gd（五步、direct 与 armor）、core/battle/damage/damage_types.gd、docs/architecture.md 4.6（伤害类型表、只有直接攻击招致反应）、「标准轴」一节（106：直接伤害看来源、防护为负倒贴）、core/text/glossary.gd
text:
一切扣血都走同一条管线：先看类型能不能被护盾吸收，再过受伤前效果，减伤、免疫、反转都在这里，再按百分比与固定增减算，然后才轮到防护。防护只减直接伤害，也就是武器出手造成的那一下，固定减掉写着的数、减到零为止；为负是破绽，反而多挨。

buff 造成的伤害不是直接伤害：中毒、流血、灼烧都绕过防护，中毒与流血连护盾也无视。只有直接攻击会招致反应，反伤、吸血这类规则不会被持续伤害触发，所以两件反伤道具不会互相对轰。伤害类型和乘区是两回事：乘区放大伤害，类型决定它吃不吃护盾与防护。

### shield · 护盾
- category: combat  order: 2
- related: [direct_damage_and_armor, buffs_and_stacks, 护盾]
- see_items: [plate_cuirass, warding_charm]
- sources: docs/architecture.md 4.6「护盾」、core/battle/battle_stats.gd（RES_SHIELD / MAX_SHIELD）、core/text/glossary.gd「护盾」、docs/reports/085-tutorial2-forks.md（板甲一次性护盾、持符者叠盾）
text:
护盾是先于生命被扣的一层资源。开战时按护盾上限充满，之后不自己回复；带护盾上限的护甲越多，开战时这一层越厚，也有道具在战斗中往上叠。能被护盾吸收的伤害先扣护盾，扣完才扣血。

中毒和流血无视护盾，直接伤在里面；反伤与火焰照样被护盾吸收。受伤前效果看到的是护盾吸收之后剩下的那部分。战斗结束护盾清零，下一场重新按上限充。
<!-- 待核：「也有道具在战斗中往上叠」来自 085 持符者「护身符每秒叠护盾」；请确认 warding_charm 现在的规则仍是叠护盾，否则 see_items 只留 plate_cuirass。 -->

### buffs_and_stacks · buff 与叠层
- category: combat  order: 3
- related: [auto_battle, direct_damage_and_armor, 叠层, 永续, 中毒, 流血]
- see_items: none
- sources: core/battle/buff_def.gd、core/battle/stat_axes.gd、docs/architecture.md 4.5（如无说明永续可叠层、上限变动时当前值同量增加）、「标准轴」一节（系统层、净化只动内容层）、core/battle/overtime_rules.gd
text:
战斗里一切属性变化都由 buff 承载，包括生命上限。不特别说明时 buff 永续、可叠层：叠上就一直在，直到被清除或战斗结束，效果按层数累加；会过期的是例外，往往是不可叠层的那种。上限涨了当前值同量涨，上限降了当前值截到新上限。

作用于角色本身的通用增减走标准轴：加速与减速、强攻与虚弱、易伤与坚韧、回春与失血等等，正负层直接相抵，buff 栏里按层数画一格。加时叠的那几层记在系统层，净化只动内容层，所以解不掉。buff 自己也能带规则，灼烧每层每秒掉血就是这么来的。所有 buff 战斗结束全部清空。

### stamina_and_cooldown · 耐力与冷却
- category: combat  order: 4
- related: [haste, auto_battle, 耐力, 耗耐力, 冷却]
- see_items: none
- sources: docs/architecture.md 4.4「消耗：第四层，且故意不与频率原子」「资源回复：按时间懒结算」、core/battle/costs/resource_cost.gd、core/battle/costs/charge_cost.gd、core/battle/costs/uses_cost.gd、core/battle/cadences/cooldown_cadence.gd（next_time 首次按 now 起算）、core/battle/stat_axes.gd（STAMINA_COST 连乘）
text:
武器出手要花耐力，耐力按每秒回复速度自动补回，回复按时间线性结算。冷却到点时看当前耐力够不够实际消耗：不够就跳过这一次出手，冷却照常清零重走，等于实打实丢掉一次机会。带几把耗耐力的武器就是这样被耐力管着。

攒次数、每场限次、按概率这些门和耐力一样都在消耗层，不过就跳过、冷却照走。开战时每件道具从头起算一个完整冷却。耐力消耗有一条连乘轴：每层灵巧把当前消耗再省掉一小截，层数之间相乘而不是相加。

### haste · 急速
- category: combat  order: 5
- related: [stamina_and_cooldown, multipliers, 急速, 冷却]
- see_items: none
- sources: core/battle/cadences/cooldown_cadence.gd（快照语义、use_haste、冷却下限）、core/battle/battle_stats.gd（HASTE 默认一倍）、core/battle/stat_axes.gd（ATTACK_SPEED 作用于 haste 终值）、docs/architecture.md 4.3「上下限」、core/text/glossary.gd CATEGORY_NAMES（HASTE 乘区）
text:
急速是出手速度的倍率，基准是一倍：冷却的实际时长等于周期除以急速，急速越高冷却越短；冷却有下限，快到一定程度不再变快。它是一条属性，所以包体、邻接、信仰加成、急速药都能改它，这些加成在急速自己的乘区里相加。

冷却是快照语义：出手那一刻按当时的速率算死下一次时刻，之后不再重算，所以战斗中新来的急速只影响再下一次出手，正在走的这一轮不变快。作用于角色本身的加速与减速走标准轴，层数相抵之后再乘到急速的终值上。
<!-- 待核：架构 4.7「冷却按工作量计」与 cooldown_cadence.gd 的「快照语义」互相矛盾，这里按代码写；若后来改回按工作量，第二段要改。 -->

### multipliers · 乘区
- category: combat  order: 6
- related: [haste, buffs_and_stacks, direct_damage_and_armor]
- see_items: none
- sources: docs/architecture.md 4.3（结算公式、乘区分类是可扩展枚举、定点数与取整）、「标准轴」一节（结算是公式的最后一步）、core/battle/stat_math.gd、core/text/glossary.gd CATEGORY_NAMES（增伤 / 物理增伤 / 元素增伤 / 急速）
text:
每件道具的属性终值这样算：基础值乘上每个乘区的括号，括号里是一加该区加成之和，最后再加固定加值。同一乘区内的加成相加，不同乘区之间相乘，固定加值不吃任何百分比放大。现在的乘区有增伤、物理增伤、元素增伤、急速四类。

这意味着两份同区的加成只是相加，一份别区的才是相乘；固定加值前期强，后期随乘区堆叠自然贬值。一个乘区的减益总和低到负一倍以下，整区因子钳到零。单位级的标准轴是公式之外的最后一步，乘在道具级终值之上。中途不取整，只在落到血量或显示时才取整。

---

## faith 信仰

### anchor_activation · 信物与激活
- category: faith  order: 0
- related: [anchor_and_right_click, switch_and_dormant, faith_power_and_tiers]
- see_items: [charm_brute, charm_sun, charm_nature, charm_earth]
- sources: docs/architecture.md 3.8、docs/reports/093-faith-schools-proposal.md 8.7（护符与 faith_call 事件链）、docs/reports/113-prologue-3-faith-tutorial.md、core/inventory/item_def.gd（is_anchor）、core/meta/meta_state.gd（keeps 对信仰包的例外）
text:
信仰靠道具激活。信仰道具带着某位神的印记；其中能激活信仰的叫信物，护符、符号、遗物这一类，每位神至少有一枚一格的护符。把信物放进棋盘就算信了这位神，任何时刻只信一位，棋盘上最后置入的那枚信物说了算。

激活之后这位神的道具按阶解锁功能，别的神的道具休眠。信物多半是从地图上的祭坛事件里拿到的，也能跟着包带回仓库、下一局带进去就从这位神开始。把信物从{zone:暂存区}挪回棋盘也算置入，会重新决定激活的是谁。

### faith_power_and_tiers · 信力与阶
- category: faith  order: 1
- related: [anchor_activation, altar_offering, 信力]
- see_items: none
- sources: core/run/faith/faith_power.gd、core/run/faith/faith_def.gd（thresholds / tier_of）、core/run/faith/deeds/*.gd、core/run/faith/blessing.gd 与 core/battle/faith_bonus.gd（mode：tier / active / scaled）、core/run/faith/faith_tooltip.gd、docs/reports/093-faith-schools-proposal.md 8.1
text:
信力是按信仰要求的行为攒的点数，只给此刻激活的信仰记。每位神看的事不一样：有的看打出去和挨到的伤害，有的看道具出手、回血、置入或获得某类道具、踩点、赢下战斗。按场计的行为往往有每场上限。信力过了一道阈值就升一阶，阈值一道比一道高。

阶决定两样东西：信仰道具上写的按阶功能，与这位神的等级效果，到了的亮、没到的灰。有些加成不按阶而按信力累计，每攒够一截多一份、有上限。地图左上一直显示激活信仰的信力与阶；鼠标停在信仰上能看增长方式。各神的池子各自记，切换不清零。

### altar_offering · 神坛献祭
- category: faith  order: 2
- related: [special_rites, rest_point, faith_power_and_tiers]
- see_items: [bone_dice, bone_charm_bits]
- sources: core/run/modules/altar_module.gd（offer / is_open / _use）、core/run/faith/offering_rule.gd、core/run/faith/faith_def.gd（offering_value）、data/authoring/events/rest_default.json、ui/game/altar_screen.gd、docs/reports/093-faith-schools-proposal.md 七 / 8.2
text:
神坛只在休息点出现，而且只在激活了信仰时才有这个选项。献祭是把道具毁掉换信力：祭品台只收满足这位神规矩的道具，每位神爱的东西不同，有按标签的，有按体积的，也有看带不带某条属性的。一件道具满足几条规矩就结算几次，换多少看它的稀有度乘上倍率。

台上有东西时「献祭」亮起，先预览能加多少、会不会升阶。常规献祭不限次数，但和特殊操作共享这个休息点上的一次机会：做过特殊操作，这个神坛就关了。「返回」把台上的东西退回背包。神坛和歇脚是两份独立的机会，走开再回来还能用没用过的那份。

### special_rites · 特殊操作
- category: faith  order: 3
- related: [altar_offering, god_brute, god_sun, god_earth]
- see_items: none
- sources: core/run/faith/perks/altar_bless_perk.gd、altar_sacrifice_hp_perk.gd、altar_pray_fire_perk.gd、altar_train_board_perk.gd、altar_reshape_node_perk.gd、core/run/modules/altar_module.gd（actions / special / rituals / stat_bonus / axis_bonus）、docs/reports/093-faith-schools-proposal.md 七、docs/gods.md
text:
到了阶的神会在神坛上刷出特殊操作按钮，升阶当场多出来。各神都有「祈求赐福」：花一笔信力，把包里能被赐福的最值钱那件换成这位神的赐福版。再往上各神不同：蛮神献祭生命上限换耐力上限与急速，日神祈祷攒局内永久的火焰加成，大地之神锻炼加棋盘行数、或把当前点改造成别的类型。

做了一次特殊操作，这个休息点的神坛就关了，献祭也不能再做；想两样都要就得找下一个休息点。有的操作要先挑一项，比如改造此点要选类型；大地的改造在关掉神坛那一刻才发生。特殊操作改的数跟着这一局走，不进下一局。

### switch_and_dormant · 切换与休眠
- category: faith  order: 4
- related: [anchor_and_right_click, anchor_activation]
- see_items: none
- sources: docs/architecture.md 3.8（休眠、切换）、core/inventory/item_def.gd（dormant_keeps_combat）、core/run/faith/faith_power.gd（切换不清别的池子）、docs/reports/107-keyword-tips-and-style-tags-proposal.md（休眠的信仰道具文字变灰）
text:
换神不花钱：右键棋盘上另一枚信物，或者把它拿起来再放下。换了之后，原来那位神的道具进入休眠：战斗里不出手、不给也不吃邻接加成、不算套装；有通用效果的道具，比如盾的固定减伤、武器本身的攻击力，仍保留通用的那部分，只丢信力加成。只靠信仰起作用的东西休眠就彻底失效。

休眠的道具在棋盘上画灰、标着「休眠」。信力按神各记一池，切出去不清零，切回来接着攒；没激活的神不记。诸神之间天然互斥，所以带几枚信物其实是带了几种随时能切的流派，代价只是它们各占的格子。

### god_brute · 蛮神
- category: faith  order: 5
- related: [special_rites, faith_power_and_tiers, altar_offering]
- see_items: [charm_brute, strength_sigil, tibia_violence]
- sources: data/authoring/faiths/brute.json（deeds / offerings / perks / blessings）、docs/gods.md（蛮神各节）、core/run/faith/perks/low_hp_empower_perk.gd、smite_perk.gd、undying_perk.gd、docs/reports/093-faith-schools-proposal.md 8.3 / 8.6
text:
{faith:brute}是暴力与杀戮本身，石头砸下来也是暴力，北境蛮族信祂。信力看的是打出去和挨到的伤害，每场有上限；失去体力也算，输了也不白输。献祭爱骨制品、血肉、武器和大块的东西，骨制品与血肉的倍率尤其高。蛮神赐福武器，赐福版激活即增伤，再按信力累计加攻击。

一阶起血越少伤害越高；二阶可以在神坛上献祭生命上限换耐力上限与急速，能反复做，但生命上限有底；三阶在战前准备屏上花体力直接秒杀精英；四阶血归零后还能坚持一小段时间、期间耐力无限，到期血还是零才倒下，一场只一次。

### god_sun · 日神
- category: faith  order: 6
- related: [special_rites, faith_power_and_tiers, altar_offering]
- see_items: [charm_sun]
- sources: data/authoring/faiths/sun.json、docs/gods.md（日神各节）、core/run/faith/perks/enchant_weapons_perk.gd、altar_pray_fire_perk.gd、axis_boost_perk.gd、extra_drop_by_node_perk.gd、core/battle/stat_axes.gd（FIRE_DAMAGE / STAMINA_COST）
text:
{faith:sun}掌太阳、火与周期性的重复，西方蛮族信祂。信力看的是你造成的火焰伤害，每场有上限；还看道具成功出手的次数。献祭爱金属、火焰、宝石，以及体积正好为中的道具。日神赐福金属制品，赐福版激活即有急速，到了阶还省耐力。

一阶起开战时随机几把武器附上火焰伤害；二阶可以在神坛上祈祷，攒局内永久的火焰加成，越祈越快，放大所有火焰来源；三阶全部武器都附火，开战时还带几层灵巧让耐力消耗更省；四阶敌人必定额外掉一件，稀有度按点的类型定，核心掉的最好。

### god_nature · 自然之神
- category: faith  order: 7
- related: [special_rites, faith_power_and_tiers, altar_offering]
- see_items: [charm_nature, ration]
- sources: data/authoring/faiths/nature.json、docs/gods.md（自然之神各节）、core/run/faith/perks/altar_food_vitality_perk.gd、food_shield_perk.gd、food_double_perk.gd、overtime_regen_perk.gd、docs/reports/103-combat-rules-proposal.md（五阶改为加时回血）
text:
{faith:nature}管回归与容纳，和生命密切相关，信徒极广。信力看的是带自然印记的道具出手，以及战斗内的回血，都有每场上限。献祭爱自然之物、食物与防具。自然之神赐福防具和自然道具，赐福版激活即加生命，再按信力累计加防护。

一阶起开战就带着每秒回血；二阶在神坛上献祭食物时顺带恢复体力，每个神坛有上限；三阶开战时按包里的食物给护盾，越稀有的食物给得越多；四阶食物的效果翻倍，献祭食物回的体力也翻倍；五阶进入加时后大量回血。

### god_earth · 大地之神
- category: faith  order: 8
- related: [special_rites, faith_power_and_tiers, altar_offering]
- see_items: [charm_earth]
- sources: data/authoring/faiths/earth.json、docs/gods.md（大地之神各节）、core/run/faith/deeds/enter_node_deed.gd、item_triggered_deed.gd、core/run/faith/perks/altar_train_board_perk.gd、gift_on_enter_perk.gd、altar_reshape_node_perk.gd、docs/reports/093-faith-schools-proposal.md 8.7（护符是一格空心石匣）
text:
{faith:earth}管结构、秩序、体积与空间，信徒不多。信力看的是中体积及以上的道具出手，每场有上限；还看踩点，头一回踩上岔路给得多，再踩任何用过的点也给一点。献祭只收大块的东西，换的信力还要乘格子数。大地之神赐福中体积以上的道具，赐福版激活即加耐力上限。

一阶起开战的耐力上限更高；二阶在神坛上锻炼，棋盘每次加一行、不限次；三阶头一回踩上一个点就得到一件对应类型的道具，进{zone:暂存区}：战斗给武器、精英给防具、事件给符号或零件、核心给珍宝；四阶在神坛上把当前点改造成别的类型，不限次。大地的护符本身是一只一格的空心石匣，能装一件小东西。

### god_skill · 技巧之神
- category: faith  order: 9
- related: [faith_power_and_tiers, altar_offering]
- see_items: [charm_skill]
- sources: data/authoring/faiths/skill.json（thresholds 两道、deeds：item_acquired metal per_cell / distinct_items_fired weapon、offerings：metal / gear / has_stat crit_chance / crafted；无 perks、无 blessings）、core/run/faith/deeds/item_acquired_deed.gd、distinct_items_fired_deed.gd、docs/gods.md 第四节「占位」
text:
{faith:skill}管尺度、变形与结构，锻造、战斗技巧和各种手艺都归祂，矮人、盗贼与工匠信祂。信力看的是获得金属道具，按格子数给；还看一场战斗里出手过的不同武器有几种，每场有上限。献祭爱金属、防具、工艺品，带暴击属性的道具倍率最高。

这位神现在只有两道阈值，等级效果还没有加入，升阶暂时没有额外功能；赐福模板也还没有。护符能激活祂、攒信力，别的等作者定。
<!-- 待核：gods.md 第四节仍写「功能全在技巧之神赐福的盾牌上」（082 占位），但 skill.json 里没有 perks / blessings，本页按 JSON 写；上线前请确认该盾牌是否仍存在并带按阶功能，若有则第二段改口。 -->

### god_hunt · 狩猎之神
- category: faith  order: 10
- related: [faith_power_and_tiers, altar_offering, hunters]
- see_items: [charm_hunt]
- sources: data/authoring/faiths/hunt.json（thresholds 两道、deeds：battle by_type / first_place trophy rarity_pow、offerings：flesh / bone / trophy / leather；无 perks、无 blessings）、core/run/faith/deeds/battle_deed.gd、first_place_deed.gd、docs/gods.md 第四节「占位」
text:
{faith:hunt}管比较、差异与拆解，帝国不祭祀祂，民间猎人信祂。信力看的是打完一场战斗，按点的类型给：普通、精英、猎手、核心一级比一级多；每局头一回把一种猎获品置入背包也给，越稀有给得越多。献祭爱血肉、骨制品、皮革，猎获品的倍率最高。

这位神现在只有两道阈值，等级效果还没有加入，升阶暂时没有额外功能；赐福模板也还没有。护符能激活祂、攒信力，别的等作者定。
<!-- 待核：同上，gods.md 写「功能全在狩猎之神赐福的长弓上」，hunt.json 无 perks；按 JSON 写。另「猎获品」对应标签 trophy，请对一下 TAG_NAMES 的中文定名。 -->

---

## map 地图

### node_types · 节点类型
- category: map  order: 0
- related: [random_node, shop, rest_point, safe_box, search_point, extraction_and_defeat]
- see_items: [spyglass]
- sources: docs/architecture.md 5.4「节点类型」/ 5.5 / 5.8、core/run/node_events.gd（_proceed 各分支）、docs/reports/092-countdown-safe-stash-sale.md 第三节（保险箱点）、docs/reports/088-author-twelfth-batch.md（望远镜开浮窗）、docs/text-placeholders.md 第 3 节
text:
出生点是开局站的地方。普通战斗与精英战斗要打一场；搜索点能翻几次；事件点发生一段对话；商店买卖；休息点回体力、有神坛；随机点踩上才揭开是哪种；撤离点是出口；保险箱点放进去的东西视为已带出；核心是这一章的头目，打赢直接结算离场。

每个点的事只发生一次，用过就变灰，之后只能穿行。地图越往里越肥也越险，撤离点在中段，核心在最深处。鼠标停在点上有浮窗，战斗点能看见对手的配置；浮窗要拿到望远镜之后才开。

### random_node · 随机点
- category: map  order: 1
- related: [node_types, battle_and_prebattle, search_point]
- see_items: none
- sources: core/run/node_events.gd（reveal / exploration）、docs/architecture.md 6.2（随机点）/ 6.0（探索度抬档）、data/authoring/node_rules/standard.json（random_weights）
text:
随机点生成时是空的，踩上去才按权重揭成一种：战斗、搜索、商店、休息或事件，不会变成精英或核心。揭成什么由这个点自己的种子决定，同一局同一个点每次揭开都一样，只是事先看不见。

揭成战斗时敌人是当场造的，按探索度抬档：走得越远、搜得越多，这里的对手越强。揭开之后它就是那种点，浮窗与规则都照那种点走。

### shop · 商店
- category: map  order: 2
- related: [quick_place, node_types]
- see_items: none
- sources: core/run/shop_session.gd、ui/game/shop_screen.gd、core/run/node_events.gd（reopen_shop）、docs/architecture.md 6.6、core/run/economy_rules.gd、data/authoring/techs/bargain.json
text:
商店的货架是一格格栏位，商品是真的道具，看得见尺寸。把商品拖进自己的包就是买，放手时收钱，钱不够弹回架上；双击也是买，自动找位。把自己的东西拖进出售区就是卖，回定价的一部分。价格按道具的价值乘倍数，深处的店货更稀有。

刷新花钱换一批，每刷一次更贵。商店可以回头再逛：走了再回来，货架、刷新次数和卖掉的格子都还记着，刷新价不重置。包与珍宝不上架。局外的加成能让商店便宜一点。

### rest_point · 休息点
- category: map  order: 3
- related: [altar_offering, vitality, node_types]
- see_items: none
- sources: data/authoring/events/rest_default.json、core/run/node_events.gd（_proceed rest / use_altar / settle_rest / rest_part_used）、core/run/node_rules.gd（rest_restore）、docs/architecture.md 5.4.2（coverage、高危区不放休息区）
text:
休息点上先过一屏：歇一会儿回体力；扎营多花几个行动点、多回一些；激活了信仰还有「神坛」一项；「继续赶路」不算用掉。歇脚和神坛是两份独立的机会，各用各的，现在不用可以留着，走开再回来还能用剩下的那份，两份都用完这个点才变灰。

回多少由章节配置定，不同章节可能不同。地图生成时保证任何点离最近的休息点不超过一定步数，但高危区里不放休息点，岔进去就别指望在里面喘气。

### safe_box · 保险箱
- category: map  order: 4
- related: [extraction_and_defeat, quick_place, tech_tree]
- see_items: none
- sources: core/run/modules/safe_module.gd、ui/game/safe_screen.gd、core/run/safe_placer.gd、core/run/run_result.gd（safe_items）、core/meta/meta_state.gd（absorb）、docs/reports/092-countdown-safe-stash-sale.md 第三 / 七节、data/authoring/techs/safe_box.json
text:
保险箱点上有一只小格子，放进去的东西视为已带出：不管这一局撤离还是失败，结算时都送回基地，结算屏单独一格画着它们。拖着放或棋盘上双击进箱，箱里双击回棋盘；包放不进去，局外不留包。

关上保险箱或走开，里面有东西就锁上，送回基地、不能再改，这个点随之变灰；空着关不算关，回来还能开。箱子的大小由局外规则定，科技能扩格。保险箱点落在地图偏中央的位置，那里没有敌人。

### countdown_and_closing · 倒计时与撤离点关闭
- category: map  order: 5
- related: [map_and_steps, extraction_and_defeat, safe_box]
- see_items: none
- sources: core/run/modules/countdown_module.gd、core/run/paid_extracts.gd（mark_closing / closes_at）、core/run/run_state.gd（try_extract 查 extract_closed）、docs/reports/092-countdown-safe-stash-sale.md 第一 / 二 / 七节、docs/reports/094（带入预算，见 countdown_module.gd 注释）
text:
有倒计时的图只有这么多行动点：走一步按那条路的代价减，原地耗时也减；归零就是行动失败，当场按战败结算，只有保险箱里的带得出。上限和地图规模正相关，地图屏顶上一直写着剩多少，剩得少时变色提醒。

倒计时过半时，离出生点最近的免费撤离点关闭。从开局起它下面就挂着「剩几步关闭」的牌子，关了画红叉，站在上面也撤不了。从仓库带进来的东西有价值预算，超出的部分按比例换掉倒计时，开局屏上写着。

### hunters · 猎手
- category: map  order: 6
- related: [vitality, battle_and_prebattle, erosion]
- see_items: none
- sources: core/run/hunters/hunter_system.gd、hunter_def.gd（visibility / sense_range / engage_range / territory_radius / flee_*）、behaviors/*、losses/*、core/run/mechanics/hunter_mechanic.gd、docs/reports/071-hunters-core.md、docs/architecture.md 8.5、data/authoring/techs/scouting.json
text:
猎手是进阶难度才有的机制：地图上会动的单位，不和节点互动，只找你。你每走一步它们动一回合，各在自己的领地里按自己的性子走，靠近、远离、游荡、埋伏或巡逻，互不进对方的领地。有的一直看得见，有的靠近才看见，有的隐形，侦察能让隐形的提前显形。

进了感知范围地图日志会说一句；够得着就先弹一屏「迎战 / 逃跑」。逃跑按成功率掷，没逃掉扣体力照打。迎战的对手按你当时的段位现造，打赢它死、掉落更多；打输按它的定义扣体力，它可能退走、消失，或把你赶回上一个点并驻守。

### erosion · 侵蚀
- category: map  order: 7
- related: [vitality, countdown_and_closing, extraction_and_defeat]
- see_items: none
- sources: core/run/erosion/erosion_field.gd、erosion_effect.gd（四道门）、effects/erode_spend_vitality.gd / erode_damage_item.gd / erode_drain_money.gd、core/run/mechanics/erosion_mechanic.gd、docs/architecture.md 5.7、docs/reports/075-erosion.md
text:
侵蚀是进阶难度才有的机制：从某个行动点起，地图从最外一圈开始逐层向内被侵蚀，每隔一段再进一层。推进前几步会预警，快被侵蚀的那一圈闪红环，地图上写着下一档还有几步。

被侵蚀的点永远能走，只是有代价：走进去扣体力，越深扣越多；侵蚀得深了还可能毁掉包里最值钱的一件，有的难度还丢钱。最内一圈也被侵蚀后进入终局，更重的效果从此生效。出口在外面、宝藏在里面、外面正在烂掉，每一步都在问值不值得再深入。

### teleport · 传送点
- category: map  order: 8
- related: [map_and_steps, staging_zone]
- see_items: none
- sources: docs/reports/076-phase8-plan-and-portals.md 第二节、core/map/map_navigator.gd（portal 边解析成 teleport 意图）、core/run/map_travel.gd、core/map/generators/ring_map_config.gd（portal_count / portal_cost / portal_min_steps）、docs/architecture.md 5.6
text:
传送点是一种特殊的路：两端可以隔得很远，走它不经过途中任何点，花的是这条路自己写着的行动点，通常比走一步多。地图上画成紫色虚线。

传送和走一步是同一套结算：花行动点、侵蚀推进、目的地的事照常发生，离开的点上{zone:暂存区}里的东西照样留在那里。有没有传送点、花几点，由这一章的地图配置定，有的图一条也没有。

---

## meta 局外

### warehouse · 仓库
- category: meta  order: 0
- related: [tidy, tech_tree, settlement_and_warehouse, codex]
- see_items: none
- sources: docs/architecture.md 8.1 / 8.2、core/meta/meta_state.gd（warehouse / keeps / grant）、core/meta/meta_rules.gd（warehouse_size / first_kit / sell_ratio）、ui/game/warehouse_panel.gd、ui/game/meta_screen.gd（出售页）、data/authoring/techs/warehouse.json
text:
{zone:仓库}是基地里的一块格子，不要求包，所有格子都能用；撤离带回来的东西在这里置入，开局时从这里拖进初始包带进下一局。放得进初始包的就是带的，没有第二套规则数件数；带回仓库的只有非包道具，包只记图鉴。

仓库空着时第一局会发一套开局装备。仓库有「整理」，格子多了能上下滚动；出售页按稀有度一键卖或双击卖，钱进局外攒着。科技「仓库扩建」让它往下长，里面的东西原地不动。

### tech_tree · 科技
- category: meta  order: 1
- related: [warehouse, safe_box]
- see_items: [steel_ingot, hardwood_plank, rivet_box]
- sources: core/meta/tech_def.gd、core/meta/tech_effect.gd、core/meta/tech_service.gd、data/authoring/techs/*.json（warehouse / safe_box / pack / endurance / sinew / undaunted / thorough_search / luck / bargain / scouting）、ui/game/tech_panel.gd、docs/reports/110-warehouse-expansion-tech-and-tidy-by-kind.md、docs/reports/118-tech-tree.md
text:
科技是局外的成长，排成一棵树：底下是根，往上长，前置都至少点了一级才能点上面的。每个节点有一级或几级，每级要钱，高一些的级还要建材；建材是没有战斗属性的材料，从搜索与掉落里来。右边面板写着名称、现在与下一级的效果、费用。

上交即消耗：双击仓库里的一件或拖进上交区，交给选中的节点，可以跨几局分批交，交了不能退；材料齐了、钱也够，「升级」才亮，钱在按下时一次扣。现有的科技给仓库加行、给保险箱扩格，或在每一局开局时带来一条局外加成：体力上限、开局钱、多搜几次、商店便宜、掉落更好、侦察、免罚头一次败仗。

### codex · 图鉴
- category: meta  order: 2
- related: [warehouse, achievements, settlement_and_warehouse]
- see_items: [spyglass]
- sources: core/meta/meta_state.gd（codex / keepsakes / absorb）、ui/game/meta_screen.gd（_build_codex）、ui/game/codex_tile.gd、docs/reports/089-save-slots-and-codex-grid.md 第三节、docs/reports/088-author-twelfth-batch.md（特殊道具）、core/meta/achievement_def.gd（codex_lit / codex_has）
text:
图鉴记的是带出过的道具：撤离成功时棋盘上的每件各计一次，保险箱里的也计，点亮之后右上角写着累计件数。它不代表东西还在仓库里，只是见过并带回来过。基地的图鉴页按稀有度排成缩略图网格，没获得的画灰，停在一格上看属性。

赐福版算在内。特殊道具另列一段：望远镜这类不进背包、代表一种能力的东西，拿到就点亮。有些成就看图鉴点亮的数量，或有没有某一件。

### achievements · 成就
- category: meta  order: 3
- related: [codex, save_slots]
- see_items: none
- sources: core/meta/achievements.gd、core/meta/achievement_def.gd（kind / amount / target / grants / hidden）、data/authoring/achievements/*.json（first_extract / extract_3 / big_haul / boss_slayer / collector_10 / fallen_thrice / spyglass_bearer）、ui/game/meta_screen.gd（成就页）
text:
成就是局外的里程碑，看的是跨局累计的数：撤离几次、战败几次、单局背出的价值、图鉴点亮多少、击败核心、拿到某件特殊道具等等。一局结算之后和读档之后各查一次，新完成的在地图日志里报一句。

有的成就给解锁：开出新的道具、地图或难度，比如背出足够的价值解锁进阶难度。成就页写着途径与进度，能按全部、已解锁、未解锁切；隐藏成就完成前只显示问号。「全部解锁」开着时成就不计。

### save_slots · 存档位
- category: meta  order: 4
- related: [achievements, warehouse]
- see_items: none
- sources: core/settings/save_slots.gd、ui/game/slots_screen.gd、core/run/game_flow.gd（use_slot / continue_game / start_new_game / backup_notice）、docs/reports/089-save-slots-and-codex-grid.md 第二节、docs/architecture.md 7.2（读不出来先备份）、docs/reports/109（倒速进设置）
text:
有三个存档位，每一位是一份独立的局外进度，加上可能有的一局进行中的存档。主菜单的「继续」读当前位接着玩；「读取存档」换位，有存档的能载入或删除，删除要点两次确认；「新的游戏」在空位上开一份新的，三位都满了会带你去读取存档屏删一个。

一局的进度在走步时自动存，读档回来接着走和没存过一样，停在战前准备屏或事件屏上也原样恢复。战斗倍速、语言这类设置不跟存档位走，所有位共用。存档读不出来时会先备份再从零开始，不会悄悄覆盖。

---

## 待核清单

1. **bags**：`belt_potion` 是否仍是「只收药剂 / 食物」的包，决定 see_items 留不留它。
2. **grant_receive_slots**：「毒箭挨着弓、弓每击附中毒」出自架构 4.2（108），请对 `items/poison_arrows.json` 的 `grant_rules`。
3. **shield**：「有道具在战斗中往上叠护盾」出自 085 的持符者 / 护身符，请确认 `warding_charm` 现在的规则。
4. **haste**：架构 4.7 写「冷却按工作量计（变速不丢进度）」，而 `cooldown_cadence.gd` 写「快照语义：后来的急速只影响再下一次」。本页按代码写，二者有一处要改。
5. **god_skill / god_hunt**：`skill.json` / `hunt.json` 没有 `perks` 与 `blessings`，本页写「等级效果尚未加入」；`docs/gods.md` 第四节仍记着 082 占位的「盾牌 / 长弓按阶功能」，请确认哪边是现状。另「猎获品」是否是标签 `trophy` 的官方中文名。
6. **rest_point**：「回多少由章节配置定」对应 `NodeRules.rest_restore`，但 `node_rules/standard.json` 里没显式写这个键（走默认值），文案不受影响，提一下。
7. **crafting.json 的 order**：现为空（默认零），与 drag_and_rotate 撞位；建议补 `"order": 4`，本稿 bag 分类的 order 已为它留了 4。
8. **node_types**：「浮窗要拿到望远镜之后才开」是 088 的规则（`ChapterDef.node_tooltips` + keepsake），序章二发望远镜；若自由模式现已默认开浮窗，删这半句。
9. **special_rites**：「祈求赐福 = 包里能被赐福的最值钱那件（棋盘优先、其次暂存区）」按 `altar_bless_perk.gd`；113 的教程文案写的是「棋盘上一件武器」，两边口径不同，请定一个。
