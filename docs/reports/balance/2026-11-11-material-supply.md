# 材料供给审计（303 第 2 步）

章节 free_mode, clockwork_hourglass；敌人携带与材料节点按种子 1..6 生成的图数；奖励池只算事件真用到的，按深度 1.0、难度 3 取候选上限。

| 结论 | 格数 | 含义 |
|---|---|---|
| ok | 207 | 不要门槛拿得到，至少两种渠道 |
| thin | 0 | 不要门槛拿得到，但只有一种渠道 |
| gated | 2 | 要解锁成就 / 科技之后才拿得到 |
| no_source | 0 | 有道具，来源全无（断路或只有自产的环） |
| no_item | 0 | 库里没有顶得上的道具 |

## 要看的格（非 ok）

| 配方 | 级 / 科技 | 格 | 结论 | 顶得上的（不要门槛拿得到的加粗） | 渠道 |
|---|---|---|---|---|---|
| anvil_imperial_sword | 3 | mithril_sword ×1 | gated | mithril_sword(3)[ach_extract_3] | enemy, market, search, shop |
| anvil_imperial_sword | 3 | metal ≥ 4 | gated | pale_shard(4)[ach_boss] | enemy |

## 材质格的低概率候选

材质类格里不要门槛拿得到、但搜索 / 材料节点份额都低于 0.5% 且没有别的渠道的道具。

- 没有

## 材质 × 稀有度的供给

配方材质格用到的每种材质、每一档：库里几件（不要门槛拿得到的几件），每章普通搜索里这一档合计份额，和份额最高的材料节点。

| 材质 | 档 | 件（可得 / 库里） | free_mode 搜索 / 最好的节点 | clockwork_hourglass 搜索 / 最好的节点 |
|---|---|---|---|---|
| bone | 0 | 1 / 1 | 1.2% / remains 6.8% | 1.2% / remains 6.8% |
| bone | 1 | 2 / 2 | 1.5% / grove 9.7% | 1.5% / — |
| bone | 2 | 2 / 2 | 0.7% / grove 4.9% | 0.7% / remains 2.0% |
| bone | 3 | 1 / 1 | 0.1% / grove 0.6% | 0.1% / remains 0.5% |
| crystal:fire | 2 | 1 / 1 | 0.4% / runes 12.7% | 0.4% / runes 12.7% |
| crystal:fire | 3 | 1 / 1 | 0.1% / runes 3.4% | 0.1% / runes 3.4% |
| crystal:fire | 4 | 1 / 1 | 0.0% / runes 0.8% | 0.0% / runes 0.8% |
| crystal:frost | 2 | 1 / 1 | 0.4% / runes 12.7% | 0.4% / runes 12.7% |
| crystal:frost | 3 | 1 / 1 | 0.1% / runes 3.4% | 0.1% / runes 3.4% |
| crystal:frost | 4 | 1 / 1 | 0.0% / runes 0.8% | 0.0% / runes 0.8% |
| crystal:lightning | 2 | 1 / 1 | 0.4% / runes 12.7% | 0.4% / runes 12.7% |
| crystal:lightning | 3 | 1 / 1 | 0.1% / runes 3.4% | 0.1% / runes 3.4% |
| crystal:lightning | 4 | 1 / 1 | 0.0% / runes 0.8% | 0.0% / runes 0.8% |
| metal | 0 | 1 / 1 | 1.2% / mine 18.2% | 1.2% / mine 18.2% |
| metal | 1 | 5 / 5 | 3.7% / remains 16.3% | 3.7% / remains 16.3% |
| metal | 2 | 7 / 7 | 2.6% / remains 12.2% | 2.6% / remains 12.2% |
| metal | 3 | 2 / 2 | 0.2% / remains 1.1% | 0.2% / remains 1.1% |
| metal | 4 | 0 / 1 | 0.0% / — | 0.0% / — |
| stone | 0 | 3 / 3 | 3.7% / mine 54.5% | 3.7% / mine 54.5% |
| stone | 1 | 4 / 4 | 2.9% / remains 12.2% | 2.9% / remains 12.2% |
| wood | 0 | 3 / 3 | 3.7% / grove 24.3% | 3.7% / — |
| wood | 1 | 2 / 2 | 1.5% / grove 4.9% | 1.5% / remains 4.1% |
| wood | 2 | 2 / 2 | 0.7% / grove 2.4% | 0.7% / remains 2.0% |

## 全部格

| 配方 | 格 | 结论 | 顶得上的件数（不要门槛 / 全开 / 库里） | 渠道 |
|---|---|---|---|---|
| anvil_barbarian_scimitar | scimitar ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_barbarian_scimitar | bone ≥ 1 | ok | 5 / 5 / 5 | enemy, market, node, search, shop |
| anvil_berserker_twin_axes | bone_twin_axes ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_berserker_twin_axes | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_berserker_twin_axes_2 | steel_twin_axes ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_berserker_twin_axes_2 | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_bloodbone_spike | bonefang_dagger ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bloodbone_spike | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_bloodbone_spike_2 | steel_stiletto ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bloodbone_spike_2 | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_bloodletter | cleaver ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bloodletter | bone ≥ 1 | ok | 5 / 5 / 5 | enemy, market, node, search, shop |
| anvil_bloodoath_axe | bone_battle_axe ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bloodoath_axe | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_bloodoath_axe_2 | steel_axe ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bloodoath_axe_2 | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_bloodoath_scimitar | barbarian_scimitar ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_bloodoath_scimitar | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_bloodthirst_twin_blades | bonefang_twin_blades ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bloodthirst_twin_blades | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_bloodthirst_twin_blades_2 | steel_twin_blades ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bloodthirst_twin_blades_2 | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_bone_battle_axe | battle_axe ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bone_battle_axe | bone ≥ 1 | ok | 5 / 5 / 5 | enemy, market, node, search, shop |
| anvil_bone_broadsword | broadsword ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_bone_broadsword | bone ≥ 1 | ok | 5 / 5 / 5 | enemy, market, node, search, shop |
| anvil_bone_great_axe | great_axe ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bone_great_axe | bone ≥ 1 | ok | 5 / 5 / 5 | enemy, market, node, search, shop |
| anvil_bone_great_club | great_club ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_bone_great_club | bone ≥ 1 | ok | 5 / 5 / 5 | enemy, market, node, search, shop |
| anvil_bone_greatsword | greatsword ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bone_greatsword | bone ≥ 1 | ok | 5 / 5 / 5 | enemy, market, node, search, shop |
| anvil_bone_pole_axe | pole_axe ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bone_pole_axe | bone ≥ 1 | ok | 5 / 5 / 5 | enemy, market, node, search, shop |
| anvil_bone_spear | short_spear ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bone_spear | bone ≥ 1 | ok | 5 / 5 / 5 | enemy, market, node, search, shop |
| anvil_bone_twin_axes | twin_axes ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bone_twin_axes | bone ≥ 1 | ok | 5 / 5 / 5 | enemy, market, node, search, shop |
| anvil_bonefang_dagger | quenched_dagger ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bonefang_dagger | bone ≥ 1 | ok | 5 / 5 / 5 | enemy, market, node, search, shop |
| anvil_bonefang_twin_blades | twin_blades ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_bonefang_twin_blades | bone ≥ 1 | ok | 5 / 5 / 5 | enemy, market, node, search, shop |
| anvil_boneiron_club | bone_great_club ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_boneiron_club | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_boneiron_club_2 | spiked_club ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_boneiron_club_2 | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_bonesteel_broadsword | bone_broadsword ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_bonesteel_broadsword | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_bonesteel_broadsword_2 | steel_broadsword ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_bonesteel_broadsword_2 | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_bonesteel_greatsword | bone_greatsword ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_bonesteel_greatsword | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_bonesteel_greatsword_2 | steel_greatsword ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_bonesteel_greatsword_2 | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_bonesteel_spear | bone_spear ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_bonesteel_spear | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_bonesteel_spear_2 | iron_spear ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_bonesteel_spear_2 | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_composite_bow | longbow ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_composite_bow | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_composite_bow_2 | horn_bow ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_composite_bow_2 | wood ≥ 2 | ok | 2 / 2 / 2 | market, node, pool, search, shop |
| anvil_dragonbone_siege_spear | siege_spear ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_dragonbone_siege_spear | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_dragoon_lance | steel_spear ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_dragoon_lance | wood ≥ 2 | ok | 2 / 2 / 2 | market, node, pool, search, shop |
| anvil_dragoon_lance_2 | hardwood_spear ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_dragoon_lance_2 | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_execution_blade | decapitator_blade ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_execution_blade | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_executioner_axe | bone_great_axe ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_executioner_axe | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_executioner_axe_2 | steel_great_axe ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_executioner_axe_2 | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_flame_berserker_twin_axes | berserker_twin_axes ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_flame_berserker_twin_axes | crystal:fire ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_flame_bonesteel_broadsword | bonesteel_broadsword ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_flame_bonesteel_broadsword | crystal:fire ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_flame_bonesteel_spear | bonesteel_spear ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_flame_bonesteel_spear | crystal:fire ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_flame_composite_bow | composite_bow ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_flame_composite_bow | crystal:fire ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_flame_execution_blade | execution_blade ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_flame_execution_blade | crystal:fire ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_flame_executioner_axe | executioner_axe ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_flame_executioner_axe | crystal:fire ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_flame_fang | bloodbone_spike ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_flame_fang | crystal:fire ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_flame_meteor_maul | meteor_maul ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_flame_meteor_maul | crystal:fire ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_frost_bloodoath_axe | bloodoath_axe ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_frost_bloodoath_axe | crystal:frost ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_frost_bonesteel_greatsword | bonesteel_greatsword ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_frost_bonesteel_greatsword | crystal:frost ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_frost_dragoon_lance | dragoon_lance ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_frost_dragoon_lance | crystal:frost ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_frost_fang | bloodbone_spike ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_frost_fang | crystal:frost ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_granite_maul | stone_maul ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_granite_maul | stone ≥ 1 | ok | 4 / 4 / 4 | enemy, market, node, pool, search, shop |
| anvil_halberd | pole_axe ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_halberd | metal ≥ 1 | ok | 14 / 15 / 15 | enemy, market, node, pool, search, shop |
| anvil_hardwood_spear | long_spear ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_hardwood_spear | wood ≥ 1 | ok | 4 / 4 / 4 | enemy, market, node, pool, search, shop |
| anvil_heavy_crossbow | steel_crossbow ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_heavy_crossbow | wood ≥ 2 | ok | 2 / 2 / 2 | market, node, pool, search, shop |
| anvil_heavy_crossbow_2 | steel_crossbow ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_heavy_crossbow_2 | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_horn_bow | shortbow ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_horn_bow | bone ≥ 1 | ok | 5 / 5 / 5 | enemy, market, node, search, shop |
| anvil_horse_halberd | halberd ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_horse_halberd | bone ≥ 2 | ok | 3 / 3 / 3 | enemy, market, node, search, shop |
| anvil_horse_halberd_2 | bone_pole_axe ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_horse_halberd_2 | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_imperial_sword | mithril_sword ×1 | gated | 0 / 1 / 1 | enemy, market, search, shop |
| anvil_imperial_sword | metal ≥ 4 | gated | 0 / 1 / 1 | enemy |
| anvil_iron_spear | short_spear ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_iron_spear | metal ≥ 1 | ok | 14 / 15 / 15 | enemy, market, node, pool, search, shop |
| anvil_ironwood_broadsword | broadsword ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_ironwood_broadsword | wood ≥ 1 | ok | 4 / 4 / 4 | enemy, market, node, pool, search, shop |
| anvil_ironwood_steel_sword | ironwood_broadsword ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_ironwood_steel_sword | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_ironwood_steel_sword_2 | steel_broadsword ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_ironwood_steel_sword_2 | wood ≥ 2 | ok | 2 / 2 / 2 | market, node, pool, search, shop |
| anvil_longbow | shortbow ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_longbow | wood ≥ 1 | ok | 4 / 4 / 4 | enemy, market, node, pool, search, shop |
| anvil_meteor_maul | siege_hammer ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_meteor_maul | metal ≥ 3 | ok | 2 / 3 / 3 | enemy, node, pool, search, shop |
| anvil_meteor_maul_2 | granite_maul ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_meteor_maul_2 | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_siege_hammer | warhammer ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_siege_hammer | metal ≥ 1 | ok | 14 / 15 / 15 | enemy, market, node, pool, search, shop |
| anvil_spiked_club | great_club ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_spiked_club | metal ≥ 1 | ok | 14 / 15 / 15 | enemy, market, node, pool, search, shop |
| anvil_steel_axe | battle_axe ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_steel_axe | metal ≥ 1 | ok | 14 / 15 / 15 | enemy, market, node, pool, search, shop |
| anvil_steel_bow | longbow ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_steel_bow | metal ≥ 2 | ok | 9 / 10 / 10 | enemy, market, node, pool, search, shop |
| anvil_steel_broadsword | broadsword ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_steel_broadsword | metal ≥ 1 | ok | 14 / 15 / 15 | enemy, market, node, pool, search, shop |
| anvil_steel_crossbow | light_crossbow ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_steel_crossbow | metal ≥ 1 | ok | 14 / 15 / 15 | enemy, market, node, pool, search, shop |
| anvil_steel_great_axe | great_axe ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_steel_great_axe | metal ≥ 1 | ok | 14 / 15 / 15 | enemy, market, node, pool, search, shop |
| anvil_steel_greatsword | greatsword ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_steel_greatsword | metal ≥ 1 | ok | 14 / 15 / 15 | enemy, market, node, pool, search, shop |
| anvil_steel_spear | long_spear ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_steel_spear | metal ≥ 1 | ok | 14 / 15 / 15 | enemy, market, node, pool, search, shop |
| anvil_steel_stiletto | quenched_dagger ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_steel_stiletto | metal ≥ 1 | ok | 14 / 15 / 15 | enemy, market, node, pool, search, shop |
| anvil_steel_twin_axes | twin_axes ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_steel_twin_axes | metal ≥ 1 | ok | 14 / 15 / 15 | enemy, market, node, pool, search, shop |
| anvil_steel_twin_blades | twin_blades ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_steel_twin_blades | metal ≥ 1 | ok | 14 / 15 / 15 | enemy, market, node, pool, search, shop |
| anvil_thunder_bloodthirst_twin_blades | bloodthirst_twin_blades ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| anvil_thunder_bloodthirst_twin_blades | crystal:lightning ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_thunder_boneiron_club | boneiron_club ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_thunder_boneiron_club | crystal:lightning ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_thunder_heavy_crossbow | heavy_crossbow ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_thunder_heavy_crossbow | crystal:lightning ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_thunder_horse_halberd | horse_halberd ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_thunder_horse_halberd | crystal:lightning ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| anvil_thunder_siege_spear | dragonbone_siege_spear ×1 | ok | 1 / 1 / 1 | market, search, shop |
| anvil_thunder_siege_spear | crystal:lightning ≥ 3 | ok | 2 / 2 / 2 | enemy, node, search, shop |
| smith_bloodletter | bone_charm_bits ×1 | ok | 1 / 1 / 1 | enemy, market, node, search, shop |
| smith_bloodletter | steel_ingot ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search |
| smith_bloodletter | whetstone ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search |
| smith_cleaver | copper_ingot ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search |
| smith_cleaver | iron_ore ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search, shop |
| smith_festering_blade | steel_ingot ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search |
| smith_festering_blade | viper_gland ×1 | ok | 1 / 1 / 1 | enemy, node, search, shop |
| smith_festering_blade | wound_salt ×1 | ok | 1 / 1 / 1 | enemy, market, node, search, shop |
| smith_grand_magus_staff | fire_crystal_high ×1 | ok | 1 / 1 / 1 | node, search, shop |
| smith_grand_magus_staff | magus_staff ×1 | ok | 1 / 1 / 1 | market, search, shop |
| smith_grand_magus_staff | mithril_ingot ×2 | ok | 1 / 1 / 1 | node, search |
| smith_leather_armor | beast_hide ×1 | ok | 1 / 1 / 1 | enemy, market, node, search, shop |
| smith_leather_armor | tanned_leather ×2 | ok | 1 / 1 / 1 | enemy, market, node, search |
| smith_longbow | fine_fur ×1 | ok | 1 / 1 / 1 | market, node, search, shop |
| smith_longbow | ironwood_branch ×2 | ok | 1 / 1 / 1 | market, node, search, shop |
| smith_longbow | rope_coil ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search, shop |
| smith_longsword | steel_ingot ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search |
| smith_longsword | tanned_leather ×1 | ok | 1 / 1 / 1 | enemy, market, node, search |
| smith_mage_staff | fire_crystal_low ×1 | ok | 1 / 1 / 1 | node, search, shop |
| smith_mage_staff | silver_ingot ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search |
| smith_mage_staff | wooden_stick ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search, shop |
| smith_magic_staff | crystal_shards ×2 | ok | 1 / 1 / 1 | market, node, search, shop |
| smith_magic_staff | wooden_stick ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search, shop |
| smith_magus_staff | fire_crystal ×1 | ok | 1 / 1 / 1 | enemy, node, search, shop |
| smith_magus_staff | ironwood_branch ×1 | ok | 1 / 1 / 1 | market, node, search, shop |
| smith_magus_staff | mithril_ingot ×1 | ok | 1 / 1 / 1 | node, search |
| smith_mithril_ingot | silver_ingot ×3 | ok | 1 / 1 / 1 | enemy, market, node, pool, search |
| smith_mithril_sword | fire_crystal_low ×1 | ok | 1 / 1 / 1 | node, search, shop |
| smith_mithril_sword | longsword ×1 | ok | 1 / 1 / 1 | enemy, market, search, shop |
| smith_mithril_sword | mithril_ingot ×2 | ok | 1 / 1 / 1 | node, search |
| smith_pendulum_blade | brass_gear ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search, shop |
| smith_pendulum_blade | mainspring ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search, shop |
| smith_pendulum_blade | steel_ingot ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search |
| smith_plate_cuirass | rivet_box ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search |
| smith_plate_cuirass | steel_ingot ×2 | ok | 1 / 1 / 1 | enemy, market, node, pool, search |
| smith_plate_cuirass | tanned_leather ×1 | ok | 1 / 1 / 1 | enemy, market, node, search |
| smith_round_shield | copper_ingot ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search |
| smith_round_shield | hardwood_plank ×1 | ok | 1 / 1 / 1 | market, node, pool, search |
| smith_shortbow | ironwood_branch ×1 | ok | 1 / 1 / 1 | market, node, search, shop |
| smith_shortbow | rope_coil ×1 | ok | 1 / 1 / 1 | enemy, market, node, pool, search, shop |
| smith_shortsword | hardwood_plank ×1 | ok | 1 / 1 / 1 | market, node, pool, search |
| smith_shortsword | iron_ore ×2 | ok | 1 / 1 / 1 | enemy, market, node, pool, search, shop |
| smith_silver_ingot | silver_ore ×2 | ok | 1 / 1 / 1 | enemy, market, node, search, shop |
| smith_warhammer | iron_ore ×2 | ok | 1 / 1 / 1 | enemy, market, node, pool, search, shop |
| smith_warhammer | oak_log ×1 | ok | 1 / 1 / 1 | enemy, market, node, search, shop |
