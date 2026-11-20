"""报告 343 的人工部分：分组、补充用途 / 出处（审计数不到的）、纯占位判定、推荐用法。"""
import json, os

A = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'data', 'authoring', 'items')


def _tags(i):
    return json.load(open(os.path.join(A, i + '.json'), encoding='utf-8')).get('tags', [])


def group_of(i, kind):
    if kind != '素材':
        return kind
    t = _tags(i)
    for tag, g in [('clockwork', '素材·机关'), ('beast_part', '素材·兽材'), ('mineral', '素材·矿物'), ('plant', '素材·草木'),
                   ('magic', '素材·魔法'), ('reagent', '素材·药剂'), ('crafted', '素材·工艺')]:
        if tag in t:
            return g
    return '素材·其他'


# 除了出售、铸炉、献祭以外没有任何专门用途的素材 / 杂物（数据核过：配方、铁匠铺指定件与材料格、科技、事件、委托都不认）
PLACEHOLDER = {
    'barbarian_necklace', 'beast_tail', 'beast_tusk_root', 'clay_bowls', 'clay_pot', 'copper_ore', 'datura_flower',
    'dense_basalt', 'fire_gland', 'frost_gland', 'glazed_vase', 'granite_mortar', 'gravestone_shard', 'honey_jar',
    'mint_bundle', 'pine_resin', 'seasoned_timber', 'shock_sac', 'silk_bolt', 'straight_ash_branch', 'tapestry',
    'wolf_heart', 'wool_cloth', 'sealed_wine_jar',
}

_BOUNTY = '精英 / 核心首领的额外奖励（科技开启后）'
_BULLION = '局内商店的金银格（35%，外环银、内环金）'
EXTRA_SOURCES = {
    'gold_bar': [_BULLION], 'gold_ingot': [_BULLION], 'gold_nugget': [_BULLION],
    'silver_bar': [_BULLION], 'silver_ingot_large': [_BULLION], 'silver_nugget': [_BULLION],
    'clay_figure': [_BOUNTY], 'stone_figurine': [_BOUNTY], 'wooden_idol': [_BOUNTY],
    'glazed_inkstone': [_BOUNTY], 'warped_obsidian': [_BOUNTY],
    'charm_brute': ['信仰召唤事件（序章三、各章）'], 'charm_sun': ['信仰召唤事件（序章三、各章）'],
    'charm_nature': ['信仰召唤事件'], 'charm_earth': ['信仰召唤事件'],
    'charm_hunt': ['暂无发放渠道（只有图鉴页）'], 'charm_skill': ['暂无发放渠道（只有图鉴页）'],
    'jimie_core_fire': ['寂灭试炼（废墟，带全黑法杖）'], 'jimie_core_lightning': ['寂灭试炼（沙漏，带全黑法杖）'],
    'jimie_core_ice': ['预留给以后的章节，现在拿不到'], 'jimie_core_poison': ['预留给以后的章节，现在拿不到'],
    'pale_shard': ['成就「首领杀手」解锁后才进池'],
    'spyglass': ['序章二、序章三的章节奖励'],
    'ticket_standard': ['魔法废墟核心首领必掉'], 'ticket_elite': ['机关沙漏核心首领必掉'],
    'forge_token': ['休息点铸炉：三件道具铸成'],
    'commission_letter': ['委托「无人署名的信」接单时发'],
    'poxiao_token': ['铁匠特殊对话（破晓不在任何地方时）'],
    'douxing': ['彩蛋道具（作者定）'],
}
EXTRA_USES = {
    'charm_brute': ['信仰锚点（蛮神）'], 'charm_earth': ['信仰锚点（大地之神）'], 'charm_hunt': ['信仰锚点（狩猎之神）'],
    'charm_nature': ['信仰锚点（自然之神）'], 'charm_skill': ['信仰锚点（技巧之神）'], 'charm_sun': ['信仰锚点（日神）'],
    'thorn_seed': ['自然之神锚点，会生长'], 'moonherb_seed': ['自然之神锚点，会生长'], 'ironwood_sapling': ['自然之神锚点，会生长'],
    'gold_bar': ['基地按面值全额回收'], 'gold_ingot': ['基地按面值全额回收'], 'gold_nugget': ['基地按面值全额回收'],
    'silver_bar': ['基地按面值全额回收'], 'silver_ingot_large': ['基地按面值全额回收'], 'silver_nugget': ['基地按面值全额回收'],
    'clay_figure': ['基地按面值全额回收'], 'stone_figurine': ['基地按面值全额回收'], 'wooden_idol': ['基地按面值全额回收'],
    'glazed_inkstone': ['基地按面值全额回收'], 'warped_obsidian': ['基地按面值全额回收'],
    'jimie_core_fire': ['寂灭之路（三）：献祭换红武'], 'jimie_core_ice': ['寂灭之路（三）：献祭换红武'],
    'jimie_core_lightning': ['寂灭之路（三）：献祭换红武'], 'jimie_core_poison': ['寂灭之路（三）：献祭换红武'],
    'spyglass': ['特殊道具：节点浮窗看得更多'],
    'ticket_standard': ['换高级出征预设'], 'ticket_elite': ['换高级出征预设'],
    'forge_token': ['拖到武器上附魔'],
    'ration': ['上板：耐力上限与回复'], 'smoked_fish': ['上板：耐力上限与回复'], 'salted_meat': ['上板：耐力上限与回复'],
    'field_rations': ['上板：耐力、生命上限'],
    'antidote_kit': ['上板：战斗中解毒'], 'antidote_satchel': ['上板：战斗中解毒'], 'bandage': ['上板：战斗中止血 / 回复'],
    'bandage_roll': ['上板：战斗中止血 / 回复'], 'bitter_root': ['上板：受毒伤减半'], 'healing_draught': ['上板：战斗中回复'],
    'panacea': ['上板：战斗中解全部'], 'salve': ['上板：战斗中回复'], 'strong_salve': ['上板：战斗中回复'],
    'styptic_dressing': ['上板：战斗中止血'], 'poison_vial': ['上板时也能施毒'], 'wound_salt': ['上板时也能施流血'],
    'viper_gland': ['上板时也能施毒'],
}

# 推荐用法：只写用到哪个新系统、怎么用（【苗圃】【食堂】【交料】常规委托上交目标，【倾向】地图协会材料倾向，【报酬】阵营报酬池，【铁匠】锻造缺口）
REC = {
    # 矿物
    'copper_ore': '【铁匠】补「铜锭 = 铜矿石 ×2」冶炼（对齐银矿石）；【交料】短单；【倾向】矿物',
    'dense_basalt': '【铁匠】新增「石 ≥优良」材料格；【交料】地图协会《核实矿脉》样本；【倾向】矿物',
    'flint': '【交料】短单首选（最常见）；【倾向】矿物',
    'gravestone_shard': '【交料】地图协会《提交路标》的路标石；【倾向】矿物',
    'iron_ore': '【交料】常规单主力；【倾向】矿物的代表产物',
    'raw_salt': '【食堂】「盐渍根汤」主料；【交料】短单；【倾向】矿物',
    'silver_ore': '【报酬】协会 / 地图协会；【倾向】矿物里的高档',
    # 草木
    'beeswax': '【苗圃】不种（蜂产品）；【食堂】封存类菜的辅料；【交料】常规单',
    'datura_flower': '【苗圃】信赖档「药材以外」的第二批药草；【交料】灰灯药包长单',
    'dried_herbs': '【苗圃】「苦叶草」的产物（两局两份）；【交料】灰灯短单',
    'honey_jar': '【食堂】「香根薄饼」甜辅料；【报酬】灰灯民用包',
    'ironwood_branch': '【苗圃】代言档第二畦的长周期树（与铁木苗呼应）；【报酬】军团',
    'mint_bundle': '【苗圃】「香根」上线前的现成厨房辅料；【食堂】配料；【交料】短单',
    'oak_log': '【交料】短单；【倾向】草木',
    'pine_resin': '【交料】短单首选（最常见、最便宜）；【倾向】草木',
    'straight_ash_branch': '【铁匠】新增「木 ≥优良」材料格（短弓、圆盾）；【苗圃】树苗候选',
    'wooden_stick': '【交料】短单；【倾向】草木',
    # 兽材
    'antler': '【报酬】猎盟；【交料】常规单',
    'beast_claw': '【报酬】猎盟；【交料】长单',
    'beast_fang': '【交料】兽材短单；【报酬】猎盟',
    'beast_hide': '【交料】军团 / 猎盟常规单（皮甲、扛重都要）',
    'beast_tail': '【铁匠】新增「皮 ≥优良」材料格；【交料】猎盟电鳗清剿的附带交件',
    'beast_tusk_root': '【食堂】「酸麦炖肉」高档配料；【交料】猎盟长单',
    'bone_charm_bits': '【报酬】猎盟',
    'bone_dice': '【报酬】灰灯夜市高价收购；铁匠骨格已认',
    'fine_fur': '【报酬】猎盟（长弓要它）',
    'fire_gland': '【交料】协会《样本归档》元素样本；【报酬】协会',
    'frost_gland': '【交料】协会元素样本；【报酬】协会',
    'shock_sac': '【交料】协会元素样本；【报酬】协会',
    'viper_gland': '【报酬】猎盟；灰灯药包高难单',
    'wolf_heart': '【食堂】特色菜配料（50 档自带辅料）；【交料】猎盟',
    # 机关
    'brass_gear': '【交料】沙漏章常规单；【报酬】军团',
    'gear_arm': '【交料】沙漏章清剿附带；铁匠只有一格能认，用途偏弱',
    'mainspring': '【报酬】军团（钟摆刃要它）',
    'steam_vent': '【交料】沙漏章长单',
    # 魔法
    'crystal_shards': '【报酬】协会主力；【交料】协会短单；【倾向】魔法',
    'pale_shard': '保持成就解锁，不进任何池',
    'jimie_core_fire': '剧情专属，不动', 'jimie_core_ice': '剧情专属，不动',
    'jimie_core_lightning': '剧情专属，不动', 'jimie_core_poison': '剧情专属，不动',
    # 药剂
    'poison_vial': '【交料】灰灯药包；局内拼合已用',
    'wound_salt': '【报酬】军团',
    # 工艺
    'barbarian_necklace': '【交料】猎盟 / 军团「蛮兵清剿」的战利凭证',
    'clay_bowls': '【食堂】《开伙》剧情交料（备碗）；【交料】灰灯短单',
    'clay_pot': '【苗圃】种苗成本的一部分（育苗盆）；【食堂】《开伙》交料',
    'copper_ingot': '【报酬】军团；【交料】常规单',
    'gilded_goblet': '【报酬】使团借展；灰灯夜市收购',
    'glazed_vase': '【交料】使团高难长单（易碎、要背回）；灰灯夜市收购',
    'granite_mortar': '【食堂】《开伙》厨具；【铁匠】「石 ≥优良」格',
    'hardwood_plank': '【报酬】军团（科技瓶颈材料）',
    'linen_bolt': '【苗圃】「绳麻」的次级产物；【交料】灰灯短单',
    'mithril_ingot': '不进报酬池（有科技门槛）',
    'nail_keg': '【报酬】军团（科技成本）',
    'oil_lamp': '【报酬】灰灯民用包；铁匠只一格能认，用途偏弱',
    'rivet_box': '【报酬】军团（科技成本）',
    'rope_coil': '【苗圃】「绳麻」的产物（三局一束）；【交料】短单',
    'seasoned_timber': '【铁匠】「木 ≥优良」格；或作科技低档的硬木板替代',
    'silk_bolt': '【报酬】使团；【交料】灰灯高难长单',
    'silver_ingot': '【报酬】协会',
    'steel_ingot': '【报酬】军团首选（科技最缺）',
    'tanned_leather': '【报酬】军团；【交料】常规单',
    'tapestry': '【交料】使团高难长单（大件，背回难）；借展厅候选',
    'whetstone': '【交料】常规单',
    'wool_cloth': '【交料】灰灯短单；驮具作坊（背架）的材料候选',
    # 药品 / 食物
    'antidote_kit': '【报酬】灰灯', 'antidote_satchel': '【报酬】灰灯', 'bandage': '【报酬】灰灯；【交料】短单',
    'bandage_roll': '【报酬】灰灯', 'bitter_root': '【苗圃】「苦叶草」的第二产物候选', 'healing_draught': '【报酬】灰灯高难单',
    'panacea': '不进报酬池（合成终点）', 'salve': '【报酬】灰灯；【交料】短单', 'strong_salve': '【报酬】灰灯',
    'styptic_dressing': '【报酬】灰灯',
    'field_rations': '【报酬】军团', 'ration': '【食堂】「酸麦炖肉」底料；【报酬】灰灯', 'salted_meat': '【食堂】底料；【报酬】军团',
    'smoked_fish': '【食堂】底料；【报酬】灰灯',
    'sealed_wine_jar': '【食堂】配酒（加价换更长效果）；【报酬】灰灯',
    # 贵重品
    'clay_figure': '【报酬】使团；高难交料', 'stone_figurine': '【报酬】使团', 'wooden_idol': '【报酬】使团',
    'glazed_inkstone': '【报酬】协会代言档', 'warped_obsidian': '【交料】协会《样本归档》高档样本',
    'gold_bar': '不进报酬池（就是钱）', 'gold_ingot': '不进报酬池（就是钱）', 'gold_nugget': '不进报酬池（就是钱）',
    'silver_bar': '不进报酬池（就是钱）', 'silver_ingot_large': '不进报酬池（就是钱）', 'silver_nugget': '不进报酬池（就是钱）',
    'poxiao_token': '剧情专属，不动',
    # 信物与特殊
    'charm_hunt': '猎盟剧情发放（补上缺的来源）', 'charm_skill': '协会或军团剧情发放（补上缺的来源）',
    'charm_brute': '保持现状', 'charm_earth': '保持现状', 'charm_nature': '保持现状', 'charm_sun': '保持现状',
    'thorn_seed': '【苗圃】首单「试种种苗」可直接发它', 'moonherb_seed': '【苗圃】信赖档种苗候选',
    'ironwood_sapling': '【苗圃】代言档第二畦候选',
    'spyglass': '保持现状', 'douxing': '彩蛋道具（作者定），不算材料，保持现状',
    'ticket_standard': '保持现状', 'ticket_elite': '保持现状', 'forge_token': '保持现状', 'commission_letter': '保持现状',
}
