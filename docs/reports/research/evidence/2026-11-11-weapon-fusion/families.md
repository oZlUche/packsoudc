# 304 附表：武器家族路线图（按配方边连通）

口径：节点 = 带 `weapon` 标签的作者道具（不含赐福异体）；边 = 一张配方，输出是武器、输入里有武器。
材料 / 磨刀石等非武器输入写在边上，不当节点；`A + B → C` 是一张配方，不是两条独立路径。
链长 = 从该节点沿配方能走到的最长步数（每张配方 1 步）。独立武器（无任何配方边）单列在最后。

## 家族 1：匕首（18 把）

起点：匕首(白)；终点：涂毒匕首(紫), 焰纹骨钢矛(金), 焰牙(金), 霜牙(金), 雷纹噬血双刀(金)；最长链：4 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `fuse_quenched_dagger` | 相邻拼接 | knife 匕首(白) + whetstone 磨刀石(绿) | — | quenched_dagger 淬火匕首(绿) |
| `fuse_short_spear` | 相邻拼接 | wooden_stick 木棍(白) + knife 匕首(白) | — | short_spear 短矛(绿) |
| `fuse_twin_blades` | 相邻拼接 | knife 匕首(白) + knife 匕首(白) | — | twin_blades 双刀(绿) |
| `anvil_bone_spear` | 升级（局内砧 / 局外铁匠铺同表） | short_spear 短矛(绿) | bone≥绿 | bone_spear 骨矛(蓝) |
| `anvil_bonefang_dagger` | 升级（局内砧 / 局外铁匠铺同表） | quenched_dagger 淬火匕首(绿) | bone≥绿 | bonefang_dagger 骨牙匕首(蓝) |
| `anvil_bonefang_twin_blades` | 升级（局内砧 / 局外铁匠铺同表） | twin_blades 双刀(绿) | bone≥绿 | bonefang_twin_blades 骨牙双刀(蓝) |
| `anvil_iron_spear` | 升级（局内砧 / 局外铁匠铺同表） | short_spear 短矛(绿) | metal≥绿 | iron_spear 铁矛(蓝) |
| `anvil_steel_stiletto` | 升级（局内砧 / 局外铁匠铺同表） | quenched_dagger 淬火匕首(绿) | metal≥绿 | steel_stiletto 钢刺(蓝) |
| `anvil_steel_twin_blades` | 升级（局内砧 / 局外铁匠铺同表） | twin_blades 双刀(绿) | metal≥绿 | steel_twin_blades 钢双刀(蓝) |
| `anvil_bloodbone_spike` | 升级（局内砧 / 局外铁匠铺同表） | bonefang_dagger 骨牙匕首(蓝) | metal≥蓝 | bloodbone_spike 噬血骨刺(紫) |
| `anvil_bloodbone_spike_2` | 升级（局内砧 / 局外铁匠铺同表） | steel_stiletto 钢刺(蓝) | bone≥蓝 | bloodbone_spike 噬血骨刺(紫) |
| `anvil_bloodthirst_twin_blades` | 升级（局内砧 / 局外铁匠铺同表） | bonefang_twin_blades 骨牙双刀(蓝) | metal≥蓝 | bloodthirst_twin_blades 噬血双刀(紫) |
| `anvil_bloodthirst_twin_blades_2` | 升级（局内砧 / 局外铁匠铺同表） | steel_twin_blades 钢双刀(蓝) | bone≥蓝 | bloodthirst_twin_blades 噬血双刀(紫) |
| `anvil_bonesteel_spear` | 升级（局内砧 / 局外铁匠铺同表） | bone_spear 骨矛(蓝) | metal≥蓝 | bonesteel_spear 骨钢矛(紫) |
| `anvil_bonesteel_spear_2` | 升级（局内砧 / 局外铁匠铺同表） | iron_spear 铁矛(蓝) | bone≥蓝 | bonesteel_spear 骨钢矛(紫) |
| `poisoned_knife` | 拖上去合（局内） | knife 匕首(白) + poison_vial 毒药瓶(绿) | — | poisoned_knife 涂毒匕首(紫) |
| `anvil_flame_bonesteel_spear` | 升级（局内砧 / 局外铁匠铺同表） | bonesteel_spear 骨钢矛(紫) | crystal:fire≥紫 | flame_bonesteel_spear 焰纹骨钢矛(金) |
| `anvil_flame_fang` | 升级（局内砧 / 局外铁匠铺同表） | bloodbone_spike 噬血骨刺(紫) | crystal:fire≥紫 | flame_fang 焰牙(金) |
| `anvil_frost_fang` | 升级（局内砧 / 局外铁匠铺同表） | bloodbone_spike 噬血骨刺(紫) | crystal:frost≥紫 | frost_fang 霜牙(金) |
| `anvil_thunder_bloodthirst_twin_blades` | 升级（局内砧 / 局外铁匠铺同表） | bloodthirst_twin_blades 噬血双刀(紫) | crystal:lightning≥紫 | thunder_bloodthirst_twin_blades 雷纹噬血双刀(金) |

```
knife 匕首(白)
  └  + whetstone → quenched_dagger 淬火匕首(绿)
    └  + 〔bone≥绿〕 → bonefang_dagger 骨牙匕首(蓝)
      └  + 〔metal≥蓝〕 → bloodbone_spike 噬血骨刺(紫)
        └  + 〔crystal:fire≥紫〕 → flame_fang 焰牙(金)
        └  + 〔crystal:frost≥紫〕 → frost_fang 霜牙(金)
    └  + 〔metal≥绿〕 → steel_stiletto 钢刺(蓝)
      └  + 〔bone≥蓝〕 → bloodbone_spike 噬血骨刺(紫)
        └  + 〔crystal:fire≥紫〕 → flame_fang 焰牙(金)
        └  + 〔crystal:frost≥紫〕 → frost_fang 霜牙(金)
  └  + wooden_stick → short_spear 短矛(绿)
    └  + 〔bone≥绿〕 → bone_spear 骨矛(蓝)
      └  + 〔metal≥蓝〕 → bonesteel_spear 骨钢矛(紫)
        └  + 〔crystal:fire≥紫〕 → flame_bonesteel_spear 焰纹骨钢矛(金)
    └  + 〔metal≥绿〕 → iron_spear 铁矛(蓝)
      └  + 〔bone≥蓝〕 → bonesteel_spear 骨钢矛(紫)
        └  + 〔crystal:fire≥紫〕 → flame_bonesteel_spear 焰纹骨钢矛(金)
  └  → twin_blades 双刀(绿)
    └  + 〔bone≥绿〕 → bonefang_twin_blades 骨牙双刀(蓝)
      └  + 〔metal≥蓝〕 → bloodthirst_twin_blades 噬血双刀(紫)
        └  + 〔crystal:lightning≥紫〕 → thunder_bloodthirst_twin_blades 雷纹噬血双刀(金)
    └  + 〔metal≥绿〕 → steel_twin_blades 钢双刀(蓝)
      └  + 〔bone≥蓝〕 → bloodthirst_twin_blades 噬血双刀(紫)
        └  + 〔crystal:lightning≥紫〕 → thunder_bloodthirst_twin_blades 雷纹噬血双刀(金)
  └  + poison_vial → poisoned_knife 涂毒匕首(紫)
```

## 家族 2：制式短剑（18 把）

起点：制式短剑(白)；终点：铁木钢剑(紫), 焰纹骨钢阔剑(金), 霜纹骨钢双手剑(金), 霜纹龙骑枪(金)；最长链：4 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `smith_shortsword` | 打造（铁匠铺） | hardwood_plank 硬木板(蓝) + iron_ore 铁矿石(绿) | — | shortsword 制式短剑(白) |
| `fuse_broadsword` | 相邻拼接 | shortsword 制式短剑(白) + whetstone 磨刀石(绿) | — | broadsword 阔剑(绿) |
| `fuse_greatsword` | 相邻拼接 | shortsword 制式短剑(白) + shortsword 制式短剑(白) | — | greatsword 双手剑(绿) |
| `fuse_long_spear` | 相邻拼接 | wooden_stick 木棍(白) + shortsword 制式短剑(白) | — | long_spear 长枪(绿) |
| `anvil_bone_broadsword` | 升级（局内砧 / 局外铁匠铺同表） | broadsword 阔剑(绿) | bone≥绿 | bone_broadsword 骨柄阔剑(蓝) |
| `anvil_bone_greatsword` | 升级（局内砧 / 局外铁匠铺同表） | greatsword 双手剑(绿) | bone≥绿 | bone_greatsword 骨柄双手剑(蓝) |
| `anvil_hardwood_spear` | 升级（局内砧 / 局外铁匠铺同表） | long_spear 长枪(绿) | wood≥绿 | hardwood_spear 硬木长枪(蓝) |
| `anvil_ironwood_broadsword` | 升级（局内砧 / 局外铁匠铺同表） | broadsword 阔剑(绿) | wood≥绿 | ironwood_broadsword 铁木阔剑(蓝) |
| `anvil_steel_broadsword` | 升级（局内砧 / 局外铁匠铺同表） | broadsword 阔剑(绿) | metal≥绿 | steel_broadsword 钢阔剑(蓝) |
| `anvil_steel_greatsword` | 升级（局内砧 / 局外铁匠铺同表） | greatsword 双手剑(绿) | metal≥绿 | steel_greatsword 钢双手剑(蓝) |
| `anvil_steel_spear` | 升级（局内砧 / 局外铁匠铺同表） | long_spear 长枪(绿) | metal≥绿 | steel_spear 钢枪(蓝) |
| `anvil_bonesteel_broadsword` | 升级（局内砧 / 局外铁匠铺同表） | bone_broadsword 骨柄阔剑(蓝) | metal≥蓝 | bonesteel_broadsword 骨钢阔剑(紫) |
| `anvil_bonesteel_broadsword_2` | 升级（局内砧 / 局外铁匠铺同表） | steel_broadsword 钢阔剑(蓝) | bone≥蓝 | bonesteel_broadsword 骨钢阔剑(紫) |
| `anvil_bonesteel_greatsword` | 升级（局内砧 / 局外铁匠铺同表） | bone_greatsword 骨柄双手剑(蓝) | metal≥蓝 | bonesteel_greatsword 骨钢双手剑(紫) |
| `anvil_bonesteel_greatsword_2` | 升级（局内砧 / 局外铁匠铺同表） | steel_greatsword 钢双手剑(蓝) | bone≥蓝 | bonesteel_greatsword 骨钢双手剑(紫) |
| `anvil_dragoon_lance` | 升级（局内砧 / 局外铁匠铺同表） | steel_spear 钢枪(蓝) | wood≥蓝 | dragoon_lance 龙骑枪(紫) |
| `anvil_dragoon_lance_2` | 升级（局内砧 / 局外铁匠铺同表） | hardwood_spear 硬木长枪(蓝) | metal≥蓝 | dragoon_lance 龙骑枪(紫) |
| `anvil_ironwood_steel_sword` | 升级（局内砧 / 局外铁匠铺同表） | ironwood_broadsword 铁木阔剑(蓝) | metal≥蓝 | ironwood_steel_sword 铁木钢剑(紫) |
| `anvil_ironwood_steel_sword_2` | 升级（局内砧 / 局外铁匠铺同表） | steel_broadsword 钢阔剑(蓝) | wood≥蓝 | ironwood_steel_sword 铁木钢剑(紫) |
| `anvil_flame_bonesteel_broadsword` | 升级（局内砧 / 局外铁匠铺同表） | bonesteel_broadsword 骨钢阔剑(紫) | crystal:fire≥紫 | flame_bonesteel_broadsword 焰纹骨钢阔剑(金) |
| `anvil_frost_bonesteel_greatsword` | 升级（局内砧 / 局外铁匠铺同表） | bonesteel_greatsword 骨钢双手剑(紫) | crystal:frost≥紫 | frost_bonesteel_greatsword 霜纹骨钢双手剑(金) |
| `anvil_frost_dragoon_lance` | 升级（局内砧 / 局外铁匠铺同表） | dragoon_lance 龙骑枪(紫) | crystal:frost≥紫 | frost_dragoon_lance 霜纹龙骑枪(金) |

```
shortsword 制式短剑(白)
  └  + whetstone → broadsword 阔剑(绿)
    └  + 〔bone≥绿〕 → bone_broadsword 骨柄阔剑(蓝)
      └  + 〔metal≥蓝〕 → bonesteel_broadsword 骨钢阔剑(紫)
        └  + 〔crystal:fire≥紫〕 → flame_bonesteel_broadsword 焰纹骨钢阔剑(金)
    └  + 〔wood≥绿〕 → ironwood_broadsword 铁木阔剑(蓝)
      └  + 〔metal≥蓝〕 → ironwood_steel_sword 铁木钢剑(紫)
    └  + 〔metal≥绿〕 → steel_broadsword 钢阔剑(蓝)
      └  + 〔bone≥蓝〕 → bonesteel_broadsword 骨钢阔剑(紫)
        └  + 〔crystal:fire≥紫〕 → flame_bonesteel_broadsword 焰纹骨钢阔剑(金)
      └  + 〔wood≥蓝〕 → ironwood_steel_sword 铁木钢剑(紫)
  └  → greatsword 双手剑(绿)
    └  + 〔bone≥绿〕 → bone_greatsword 骨柄双手剑(蓝)
      └  + 〔metal≥蓝〕 → bonesteel_greatsword 骨钢双手剑(紫)
        └  + 〔crystal:frost≥紫〕 → frost_bonesteel_greatsword 霜纹骨钢双手剑(金)
    └  + 〔metal≥绿〕 → steel_greatsword 钢双手剑(蓝)
      └  + 〔bone≥蓝〕 → bonesteel_greatsword 骨钢双手剑(紫)
        └  + 〔crystal:frost≥紫〕 → frost_bonesteel_greatsword 霜纹骨钢双手剑(金)
  └  + wooden_stick → long_spear 长枪(绿)
    └  + 〔wood≥绿〕 → hardwood_spear 硬木长枪(蓝)
      └  + 〔metal≥蓝〕 → dragoon_lance 龙骑枪(紫)
        └  + 〔crystal:frost≥紫〕 → frost_dragoon_lance 霜纹龙骑枪(金)
    └  + 〔metal≥绿〕 → steel_spear 钢枪(蓝)
      └  + 〔wood≥蓝〕 → dragoon_lance 龙骑枪(紫)
        └  + 〔crystal:frost≥紫〕 → frost_dragoon_lance 霜纹龙骑枪(金)
```

## 家族 3：手斧（16 把）

起点：手斧(白)；终点：焰纹狂战双斧(金), 霜纹血誓斧(金), 雷纹斩马戟(金)；最长链：4 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `fuse_battle_axe` | 相邻拼接 | hand_axe 手斧(白) + whetstone 磨刀石(绿) | — | battle_axe 战斧(绿) |
| `fuse_pole_axe` | 相邻拼接 | wooden_stick 木棍(白) + hand_axe 手斧(白) | — | pole_axe 长柄斧(绿) |
| `fuse_twin_axes` | 相邻拼接 | hand_axe 手斧(白) + hand_axe 手斧(白) | — | twin_axes 双斧(绿) |
| `anvil_bone_battle_axe` | 升级（局内砧 / 局外铁匠铺同表） | battle_axe 战斧(绿) | bone≥绿 | bone_battle_axe 兽骨战斧(蓝) |
| `anvil_bone_pole_axe` | 升级（局内砧 / 局外铁匠铺同表） | pole_axe 长柄斧(绿) | bone≥绿 | bone_pole_axe 骨柄长柄斧(蓝) |
| `anvil_bone_twin_axes` | 升级（局内砧 / 局外铁匠铺同表） | twin_axes 双斧(绿) | bone≥绿 | bone_twin_axes 兽骨双斧(蓝) |
| `anvil_halberd` | 升级（局内砧 / 局外铁匠铺同表） | pole_axe 长柄斧(绿) | metal≥绿 | halberd 戟(蓝) |
| `anvil_steel_axe` | 升级（局内砧 / 局外铁匠铺同表） | battle_axe 战斧(绿) | metal≥绿 | steel_axe 钢斧(蓝) |
| `anvil_steel_twin_axes` | 升级（局内砧 / 局外铁匠铺同表） | twin_axes 双斧(绿) | metal≥绿 | steel_twin_axes 钢双斧(蓝) |
| `anvil_berserker_twin_axes` | 升级（局内砧 / 局外铁匠铺同表） | bone_twin_axes 兽骨双斧(蓝) | metal≥蓝 | berserker_twin_axes 狂战双斧(紫) |
| `anvil_berserker_twin_axes_2` | 升级（局内砧 / 局外铁匠铺同表） | steel_twin_axes 钢双斧(蓝) | bone≥蓝 | berserker_twin_axes 狂战双斧(紫) |
| `anvil_bloodoath_axe` | 升级（局内砧 / 局外铁匠铺同表） | bone_battle_axe 兽骨战斧(蓝) | metal≥蓝 | bloodoath_axe 血誓斧(紫) |
| `anvil_bloodoath_axe_2` | 升级（局内砧 / 局外铁匠铺同表） | steel_axe 钢斧(蓝) | bone≥蓝 | bloodoath_axe 血誓斧(紫) |
| `anvil_horse_halberd` | 升级（局内砧 / 局外铁匠铺同表） | halberd 戟(蓝) | bone≥蓝 | horse_halberd 斩马戟(紫) |
| `anvil_horse_halberd_2` | 升级（局内砧 / 局外铁匠铺同表） | bone_pole_axe 骨柄长柄斧(蓝) | metal≥蓝 | horse_halberd 斩马戟(紫) |
| `anvil_flame_berserker_twin_axes` | 升级（局内砧 / 局外铁匠铺同表） | berserker_twin_axes 狂战双斧(紫) | crystal:fire≥紫 | flame_berserker_twin_axes 焰纹狂战双斧(金) |
| `anvil_frost_bloodoath_axe` | 升级（局内砧 / 局外铁匠铺同表） | bloodoath_axe 血誓斧(紫) | crystal:frost≥紫 | frost_bloodoath_axe 霜纹血誓斧(金) |
| `anvil_thunder_horse_halberd` | 升级（局内砧 / 局外铁匠铺同表） | horse_halberd 斩马戟(紫) | crystal:lightning≥紫 | thunder_horse_halberd 雷纹斩马戟(金) |

```
hand_axe 手斧(白)
  └  + whetstone → battle_axe 战斧(绿)
    └  + 〔bone≥绿〕 → bone_battle_axe 兽骨战斧(蓝)
      └  + 〔metal≥蓝〕 → bloodoath_axe 血誓斧(紫)
        └  + 〔crystal:frost≥紫〕 → frost_bloodoath_axe 霜纹血誓斧(金)
    └  + 〔metal≥绿〕 → steel_axe 钢斧(蓝)
      └  + 〔bone≥蓝〕 → bloodoath_axe 血誓斧(紫)
        └  + 〔crystal:frost≥紫〕 → frost_bloodoath_axe 霜纹血誓斧(金)
  └  + wooden_stick → pole_axe 长柄斧(绿)
    └  + 〔bone≥绿〕 → bone_pole_axe 骨柄长柄斧(蓝)
      └  + 〔metal≥蓝〕 → horse_halberd 斩马戟(紫)
        └  + 〔crystal:lightning≥紫〕 → thunder_horse_halberd 雷纹斩马戟(金)
    └  + 〔metal≥绿〕 → halberd 戟(蓝)
      └  + 〔bone≥蓝〕 → horse_halberd 斩马戟(紫)
        └  + 〔crystal:lightning≥紫〕 → thunder_horse_halberd 雷纹斩马戟(金)
  └  → twin_axes 双斧(绿)
    └  + 〔bone≥绿〕 → bone_twin_axes 兽骨双斧(蓝)
      └  + 〔metal≥蓝〕 → berserker_twin_axes 狂战双斧(紫)
        └  + 〔crystal:fire≥紫〕 → flame_berserker_twin_axes 焰纹狂战双斧(金)
    └  + 〔metal≥绿〕 → steel_twin_axes 钢双斧(蓝)
      └  + 〔bone≥蓝〕 → berserker_twin_axes 狂战双斧(紫)
        └  + 〔crystal:fire≥紫〕 → flame_berserker_twin_axes 焰纹狂战双斧(金)
```

## 家族 4：粗制弓（7 把）

起点：粗制弓(白)；终点：钢弓(紫), 焰纹复合弓(金)；最长链：4 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `fuse_shortbow` | 相邻拼接 | crude_bow 粗制弓(白) + tanned_leather 熟皮革(绿) | — | shortbow 短弓(绿) |
| `smith_shortbow` | 打造（铁匠铺） | ironwood_branch 铁木枝(蓝) + rope_coil 麻绳卷(白) | — | shortbow 短弓(绿) |
| `anvil_horn_bow` | 升级（局内砧 / 局外铁匠铺同表） | shortbow 短弓(绿) | bone≥绿 | horn_bow 角弓(蓝) |
| `anvil_longbow` | 升级（局内砧 / 局外铁匠铺同表） | shortbow 短弓(绿) | wood≥绿 | longbow 长弓(蓝) |
| `smith_longbow` | 打造（铁匠铺） | fine_fur 细毛皮(蓝) + ironwood_branch 铁木枝(蓝) + rope_coil 麻绳卷(白) | — | longbow 长弓(蓝) |
| `anvil_composite_bow` | 升级（局内砧 / 局外铁匠铺同表） | longbow 长弓(蓝) | bone≥蓝 | composite_bow 复合弓(紫) |
| `anvil_composite_bow_2` | 升级（局内砧 / 局外铁匠铺同表） | horn_bow 角弓(蓝) | wood≥蓝 | composite_bow 复合弓(紫) |
| `anvil_steel_bow` | 升级（局内砧 / 局外铁匠铺同表） | longbow 长弓(蓝) | metal≥蓝 | steel_bow 钢弓(紫) |
| `anvil_flame_composite_bow` | 升级（局内砧 / 局外铁匠铺同表） | composite_bow 复合弓(紫) | crystal:fire≥紫 | flame_composite_bow 焰纹复合弓(金) |

```
crude_bow 粗制弓(白)
  └  + tanned_leather → shortbow 短弓(绿)
    └  + 〔bone≥绿〕 → horn_bow 角弓(蓝)
      └  + 〔wood≥蓝〕 → composite_bow 复合弓(紫)
        └  + 〔crystal:fire≥紫〕 → flame_composite_bow 焰纹复合弓(金)
    └  + 〔wood≥绿〕 → longbow 长弓(蓝)
      └  + 〔bone≥蓝〕 → composite_bow 复合弓(紫)
        └  + 〔crystal:fire≥紫〕 → flame_composite_bow 焰纹复合弓(金)
      └  + 〔metal≥蓝〕 → steel_bow 钢弓(紫)
```

## 家族 5：棍棒（6 把）

起点：棍棒(白)；终点：雷纹骨铁大棒(金)；最长链：4 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `fuse_great_club` | 相邻拼接 | club 棍棒(白) + club 棍棒(白) | — | great_club 大棒(绿) |
| `anvil_bone_great_club` | 升级（局内砧 / 局外铁匠铺同表） | great_club 大棒(绿) | bone≥绿 | bone_great_club 兽骨大棒(蓝) |
| `anvil_spiked_club` | 升级（局内砧 / 局外铁匠铺同表） | great_club 大棒(绿) | metal≥绿 | spiked_club 钉头大棒(蓝) |
| `anvil_boneiron_club` | 升级（局内砧 / 局外铁匠铺同表） | bone_great_club 兽骨大棒(蓝) | metal≥蓝 | boneiron_club 骨铁大棒(紫) |
| `anvil_boneiron_club_2` | 升级（局内砧 / 局外铁匠铺同表） | spiked_club 钉头大棒(蓝) | bone≥蓝 | boneiron_club 骨铁大棒(紫) |
| `anvil_thunder_boneiron_club` | 升级（局内砧 / 局外铁匠铺同表） | boneiron_club 骨铁大棒(紫) | crystal:lightning≥紫 | thunder_boneiron_club 雷纹骨铁大棒(金) |

```
club 棍棒(白)
  └  → great_club 大棒(绿)
    └  + 〔bone≥绿〕 → bone_great_club 兽骨大棒(蓝)
      └  + 〔metal≥蓝〕 → boneiron_club 骨铁大棒(紫)
        └  + 〔crystal:lightning≥紫〕 → thunder_boneiron_club 雷纹骨铁大棒(金)
    └  + 〔metal≥绿〕 → spiked_club 钉头大棒(蓝)
      └  + 〔bone≥蓝〕 → boneiron_club 骨铁大棒(紫)
        └  + 〔crystal:lightning≥紫〕 → thunder_boneiron_club 雷纹骨铁大棒(金)
```

## 家族 6：伐木斧（6 把）

起点：伐木斧(白)；终点：焰纹刽子手巨斧(金)；最长链：4 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `fuse_great_axe` | 相邻拼接 | felling_axe 伐木斧(白) + whetstone 磨刀石(绿) | — | great_axe 巨斧(绿) |
| `anvil_bone_great_axe` | 升级（局内砧 / 局外铁匠铺同表） | great_axe 巨斧(绿) | bone≥绿 | bone_great_axe 兽骨巨斧(蓝) |
| `anvil_steel_great_axe` | 升级（局内砧 / 局外铁匠铺同表） | great_axe 巨斧(绿) | metal≥绿 | steel_great_axe 钢巨斧(蓝) |
| `anvil_executioner_axe` | 升级（局内砧 / 局外铁匠铺同表） | bone_great_axe 兽骨巨斧(蓝) | metal≥蓝 | executioner_axe 刽子手巨斧(紫) |
| `anvil_executioner_axe_2` | 升级（局内砧 / 局外铁匠铺同表） | steel_great_axe 钢巨斧(蓝) | bone≥蓝 | executioner_axe 刽子手巨斧(紫) |
| `anvil_flame_executioner_axe` | 升级（局内砧 / 局外铁匠铺同表） | executioner_axe 刽子手巨斧(紫) | crystal:fire≥紫 | flame_executioner_axe 焰纹刽子手巨斧(金) |

```
felling_axe 伐木斧(白)
  └  + whetstone → great_axe 巨斧(绿)
    └  + 〔bone≥绿〕 → bone_great_axe 兽骨巨斧(蓝)
      └  + 〔metal≥蓝〕 → executioner_axe 刽子手巨斧(紫)
        └  + 〔crystal:fire≥紫〕 → flame_executioner_axe 焰纹刽子手巨斧(金)
    └  + 〔metal≥绿〕 → steel_great_axe 钢巨斧(蓝)
      └  + 〔bone≥蓝〕 → executioner_axe 刽子手巨斧(紫)
        └  + 〔crystal:fire≥紫〕 → flame_executioner_axe 焰纹刽子手巨斧(金)
```

## 家族 7：石锤 / 战锤（6 把）

起点：石锤(绿), 战锤(绿)；终点：焰纹陨铁大锤(金)；最长链：3 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `fuse_stone_maul` | 相邻拼接 | wooden_stick 木棍(白) + flint 燧石(白) | — | stone_maul 石锤(绿) |
| `smith_warhammer` | 打造（铁匠铺） | iron_ore 铁矿石(绿) + oak_log 橡木原木(白) | — | warhammer 战锤(绿) |
| `anvil_granite_maul` | 升级（局内砧 / 局外铁匠铺同表） | stone_maul 石锤(绿) | stone≥绿 | granite_maul 花岗石锤(蓝) |
| `anvil_siege_hammer` | 升级（局内砧 / 局外铁匠铺同表） | warhammer 战锤(绿) | metal≥绿 | siege_hammer 破城锤(蓝) |
| `anvil_meteor_maul` | 升级（局内砧 / 局外铁匠铺同表） | siege_hammer 破城锤(蓝) | metal≥紫 | meteor_maul 陨铁大锤(紫) |
| `anvil_meteor_maul_2` | 升级（局内砧 / 局外铁匠铺同表） | granite_maul 花岗石锤(蓝) | metal≥蓝 | meteor_maul 陨铁大锤(紫) |
| `anvil_flame_meteor_maul` | 升级（局内砧 / 局外铁匠铺同表） | meteor_maul 陨铁大锤(紫) | crystal:fire≥紫 | flame_meteor_maul 焰纹陨铁大锤(金) |

```
stone_maul 石锤(绿)
  └  + 〔stone≥绿〕 → granite_maul 花岗石锤(蓝)
    └  + 〔metal≥蓝〕 → meteor_maul 陨铁大锤(紫)
      └  + 〔crystal:fire≥紫〕 → flame_meteor_maul 焰纹陨铁大锤(金)
warhammer 战锤(绿)
  └  + 〔metal≥绿〕 → siege_hammer 破城锤(蓝)
    └  + 〔metal≥紫〕 → meteor_maul 陨铁大锤(紫)
      └  + 〔crystal:fire≥紫〕 → flame_meteor_maul 焰纹陨铁大锤(金)
```

## 家族 8：手弩（5 把）

起点：手弩(白)；终点：雷纹重弩(金)；最长链：4 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `fuse_light_crossbow` | 相邻拼接 | hand_crossbow 手弩(白) + wooden_stick 木棍(白) | — | light_crossbow 轻弩(绿) |
| `anvil_steel_crossbow` | 升级（局内砧 / 局外铁匠铺同表） | light_crossbow 轻弩(绿) | metal≥绿 | steel_crossbow 钢弩(蓝) |
| `anvil_heavy_crossbow` | 升级（局内砧 / 局外铁匠铺同表） | steel_crossbow 钢弩(蓝) | wood≥蓝 | heavy_crossbow 重弩(紫) |
| `anvil_heavy_crossbow_2` | 升级（局内砧 / 局外铁匠铺同表） | steel_crossbow 钢弩(蓝) | bone≥蓝 | heavy_crossbow 重弩(紫) |
| `anvil_thunder_heavy_crossbow` | 升级（局内砧 / 局外铁匠铺同表） | heavy_crossbow 重弩(紫) | crystal:lightning≥紫 | thunder_heavy_crossbow 雷纹重弩(金) |

```
hand_crossbow 手弩(白)
  └  + wooden_stick → light_crossbow 轻弩(绿)
    └  + 〔metal≥绿〕 → steel_crossbow 钢弩(蓝)
      └  + 〔wood≥蓝〕 → heavy_crossbow 重弩(紫)
        └  + 〔crystal:lightning≥紫〕 → thunder_heavy_crossbow 雷纹重弩(金)
      └  + 〔bone≥蓝〕 → heavy_crossbow 重弩(紫)
        └  + 〔crystal:lightning≥紫〕 → thunder_heavy_crossbow 雷纹重弩(金)
```

## 家族 9：斩首巨刃（3 把）

起点：斩首巨刃(蓝)；终点：焰纹处刑巨刃(金)；最长链：2 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `anvil_execution_blade` | 升级（局内砧 / 局外铁匠铺同表） | decapitator_blade 斩首巨刃(蓝) | bone≥蓝 | execution_blade 处刑巨刃(紫) |
| `anvil_flame_execution_blade` | 升级（局内砧 / 局外铁匠铺同表） | execution_blade 处刑巨刃(紫) | crystal:fire≥紫 | flame_execution_blade 焰纹处刑巨刃(金) |

```
decapitator_blade 斩首巨刃(蓝)
  └  + 〔bone≥蓝〕 → execution_blade 处刑巨刃(紫)
    └  + 〔crystal:fire≥紫〕 → flame_execution_blade 焰纹处刑巨刃(金)
```

## 家族 10：长剑（3 把）

起点：长剑(绿)；终点：帝国佩剑(金)；最长链：2 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `smith_longsword` | 打造（铁匠铺） | steel_ingot 钢锭(蓝) + tanned_leather 熟皮革(绿) | — | longsword 长剑(绿) |
| `smith_mithril_sword` | 打造（铁匠铺） | fire_crystal_low 火焰晶石(蓝) + longsword 长剑(绿) + mithril_ingot 秘银锭(紫) | — | mithril_sword 秘银附魔长剑(紫) |
| `anvil_imperial_sword` | 升级（局内砧 / 局外铁匠铺同表） | mithril_sword 秘银附魔长剑(紫) | metal≥金 | imperial_sword 帝国佩剑(金) |

```
longsword 长剑(绿)
  └  + fire_crystal_low + mithril_ingot → mithril_sword 秘银附魔长剑(紫)
    └  + 〔metal≥金〕 → imperial_sword 帝国佩剑(金)
```

## 家族 11：弯刀（3 把）

起点：弯刀(绿)；终点：血誓弯刀(紫)；最长链：2 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `anvil_barbarian_scimitar` | 升级（局内砧 / 局外铁匠铺同表） | scimitar 弯刀(绿) | bone≥绿 | barbarian_scimitar 蛮族大弯刀(蓝) |
| `anvil_bloodoath_scimitar` | 升级（局内砧 / 局外铁匠铺同表） | barbarian_scimitar 蛮族大弯刀(蓝) | bone≥蓝 | bloodoath_scimitar 血誓弯刀(紫) |

```
scimitar 弯刀(绿)
  └  + 〔bone≥绿〕 → barbarian_scimitar 蛮族大弯刀(蓝)
    └  + 〔bone≥蓝〕 → bloodoath_scimitar 血誓弯刀(紫)
```

## 家族 12：破城矛（3 把）

起点：破城矛(蓝)；终点：雷纹破城矛(金)；最长链：2 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `anvil_dragonbone_siege_spear` | 升级（局内砧 / 局外铁匠铺同表） | siege_spear 破城矛(蓝) | bone≥蓝 | dragonbone_siege_spear 龙骨破城矛(紫) |
| `anvil_thunder_siege_spear` | 升级（局内砧 / 局外铁匠铺同表） | dragonbone_siege_spear 龙骨破城矛(紫) | crystal:lightning≥紫 | thunder_siege_spear 雷纹破城矛(金) |

```
siege_spear 破城矛(蓝)
  └  + 〔bone≥蓝〕 → dragonbone_siege_spear 龙骨破城矛(紫)
    └  + 〔crystal:lightning≥紫〕 → thunder_siege_spear 雷纹破城矛(金)
```

## 家族 13：剁刀（2 把）

起点：剁刀(绿)；终点：放血刀(蓝)；最长链：1 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `smith_cleaver` | 打造（铁匠铺） | copper_ingot 铜锭(绿) + iron_ore 铁矿石(绿) | — | cleaver 剁刀(绿) |
| `anvil_bloodletter` | 升级（局内砧 / 局外铁匠铺同表） | cleaver 剁刀(绿) | bone≥绿 | bloodletter 放血刀(蓝) |
| `smith_bloodletter` | 打造（铁匠铺） | bone_charm_bits 碎骨串(蓝) + steel_ingot 钢锭(蓝) + whetstone 磨刀石(绿) | — | bloodletter 放血刀(蓝) |

```
cleaver 剁刀(绿)
  └  + 〔bone≥绿〕 → bloodletter 放血刀(蓝)
```

## 家族 14：魔导杖（2 把）

起点：魔导杖(紫)；终点：大魔导杖(金)；最长链：1 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `smith_magus_staff` | 打造（铁匠铺） | fire_crystal 火焰魔晶石(紫) + ironwood_branch 铁木枝(蓝) + mithril_ingot 秘银锭(紫) | — | magus_staff 魔导杖(紫) |
| `smith_grand_magus_staff` | 打造（铁匠铺） | fire_crystal_high 火焰魔晶核(金) + magus_staff 魔导杖(紫) + mithril_ingot 秘银锭(紫) | — | grand_magus_staff 大魔导杖(金) |

```
magus_staff 魔导杖(紫)
  └  + fire_crystal_high + mithril_ingot → grand_magus_staff 大魔导杖(金)
```

## 家族 22：溃烂之刃（1 把）

起点：溃烂之刃(紫)；终点：溃烂之刃(紫)；最长链：0 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `smith_festering_blade` | 打造（铁匠铺） | steel_ingot 钢锭(蓝) + viper_gland 蝰蛇毒腺(紫) + wound_salt 创口盐(绿) | — | festering_blade 溃烂之刃(紫) |

```
festering_blade 溃烂之刃(紫)
```

## 家族 27：法师杖（1 把）

起点：法师杖(蓝)；终点：法师杖(蓝)；最长链：0 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `smith_mage_staff` | 打造（铁匠铺） | fire_crystal_low 火焰晶石(蓝) + silver_ingot 银锭(蓝) + wooden_stick 木棍(白) | — | mage_staff 法师杖(蓝) |

```
mage_staff 法师杖(蓝)
```

## 家族 28：魔法杖（1 把）

起点：魔法杖(绿)；终点：魔法杖(绿)；最长链：0 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `smith_magic_staff` | 打造（铁匠铺） | crystal_shards 碎晶(白) + wooden_stick 木棍(白) | — | magic_staff 魔法杖(绿) |

```
magic_staff 魔法杖(绿)
```

## 家族 29：钟摆刃（1 把）

起点：钟摆刃(蓝)；终点：钟摆刃(蓝)；最长链：0 步

| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |
|---|---|---|---|---|
| `smith_pendulum_blade` | 打造（铁匠铺） | brass_gear 黄铜齿轮(蓝) + mainspring 主发条(蓝) + steel_ingot 钢锭(蓝) | — | pendulum_blade 钟摆刃(蓝) |

```
pendulum_blade 钟摆刃(蓝)
```

## 无任何配方关系的武器（18 把）

| id | 名字 | 颜色 | 标签 |
|---|---|---|---|
| `tibia_violence` | 胫骨大棒 | 绿 | weapon,melee,faith:brute |
| `blessed_longbow` | 狩猎之神赐福的长弓 | 紫 | weapon,faith:hunt,ranged,rapid |
| `bengshan` | 崩山 | 红 | weapon,melee,burst,two_hand,heavy,unique |
| `bengshan_lesser` | 崩山 | 红 | weapon,melee,burst,two_hand,heavy,lesser |
| `chana` | 刹那 | 红 | weapon,melee,rapid,dagger,bleed,unique |
| `chana_lesser` | 刹那 | 红 | weapon,melee,rapid,dagger,bleed,lesser |
| `duanshui` | 断水 | 红 | weapon,melee,burst,one_hand,unique |
| `duanshui_lesser` | 断水 | 红 | weapon,melee,burst,one_hand,lesser |
| `guanri` | 贯日 | 红 | weapon,melee,burst,polearm,unique |
| `guanri_lesser` | 贯日 | 红 | weapon,melee,burst,polearm,lesser |
| `jimie` | 寂灭 | 红 | weapon,melee,staff,magic,unique |
| `jimie_lesser` | 寂灭 | 红 | weapon,melee,staff,magic,lesser |
| `poxiao` | 破晓 | 红 | weapon,ranged,burst,unique |
| `poxiao_lesser` | 破晓 | 红 | weapon,ranged,burst,lesser |
| `shuangsheng` | 双生 | 红 | weapon,melee,rapid,dual,unique |
| `shuangsheng_lesser` | 双生 | 红 | weapon,melee,rapid,dual,lesser |
| `zhuixing` | 坠星 | 红 | weapon,ranged,rapid,unique |
| `zhuixing_lesser` | 坠星 | 红 | weapon,ranged,rapid,lesser |
