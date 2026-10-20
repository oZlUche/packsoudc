# 界面音效第一批（204）来源

云端连不上 kenney.nl 和 freesound，这一批是为本项目自己合成的原创音效，没有用任何外部素材。生成脚本是 `src/synth.py`（numpy 合成 + ffmpeg 转 Vorbis），本项目自有，可按 CC0 处理。

| 文件 | 来源 | 作者 | 许可 |
|---|---|---|---|
| ui_press_1.ogg | 原创合成，src/synth.py `press(1, 1.00, 1.00)` | 美术设计 thread（本项目） | CC0 / 项目自有 |
| ui_press_2.ogg | 原创合成，src/synth.py `press(2, 1.05, 0.92)` | 美术设计 thread（本项目） | CC0 / 项目自有 |
| ui_press_3.ogg | 原创合成，src/synth.py `press(3, 0.95, 1.08)` | 美术设计 thread（本项目） | CC0 / 项目自有 |
| ui_open.ogg | 原创合成，src/open2.py `open_b()`（第二版"搭扣"，2026-10-19 替换第一版） | 美术设计 thread（本项目） | CC0 / 项目自有 |
| ui_close.ogg | 原创合成，src/synth.py `ui_close()` | 美术设计 thread（本项目） | CC0 / 项目自有 |

规格：Vorbis .ogg，44.1 kHz，单声道，不循环；按钮 110 ms，开 240 ms，关 250 ms；头部无静音（0.5 ms 内起音）；解码后峰值 −2.6～−3.1 dBFS。

备选（不在游戏里）：美术目录 `alt/` 下有第一版 ui_open_v1.ogg 和第二版候选 ui_open_a.ogg（翻页）、ui_open_c.ogg（双响），同样原创合成、项目自有。

# 第二批音效（背包 / 战利品 / 战斗）来源

全部为本项目原创合成，没有用任何外部素材。生成脚本 `src/synth2.py`（numpy 合成 + ffmpeg 转 Vorbis），本项目自有，可按 CC0 处理。作者：音效 thread（本项目），2026-10-19。

- 37 个 cue × 3 个版本：`<cue 点换下划线>_v1.ogg`（推荐）、`_v2`（轻亮）、`_v3`（厚重），清单见 `cues.json`。
- 规格：Vorbis .ogg，44.1 kHz，单声道，不循环；头部无静音；峰值约 −3 dBFS（翻牌按稀有度 −7 → −3 dBFS 渐强）。
- 试听页：https://claude.ai/artifact/HB8CbMLDeaoV8uzbKdQttP

## 第三轮（round3/）
用 Kenney 的 CC0 素材包（RPG Audio、Impact Sounds、Casino Audio，作者 Kenney Vleugels，kenney.nl，Creative Commons CC0）剪辑、叠加、变调而成，原包放在 `art/audio/sources/kenney/`，处理脚本 `src/synth2c.py`。署名非必须，但游戏 CREDITS 里写上 Kenney。
`round3/battle_start.ogg` 是第二轮合成的号角（src/synth2b.py `win(3)`），原创、项目自有。

# 第二批音效定稿（38 个，2026-10-20）

文件名 = cue 名点换下划线。完整来源和作者名单见上级目录 CREDITS.md；游戏 CREDITS 里写上 Kenney 和用到的 freesound 作者（CC0，署名非必须）。

- bag_bump.ogg ← ogg/bag_bump_v1.ogg：原创合成（src/synth2.py），项目自有
- bag_invalid.ogg ← ogg/bag_invalid_v1.ogg：原创合成（src/synth2.py），项目自有
- bag_land_heavy.ogg ← ogg/bag_land_heavy_v3.ogg：原创合成（src/synth2.py），项目自有
- bag_land_light.ogg ← ogg/bag_land_light_v1.ogg：原创合成（src/synth2.py），项目自有
- bag_pick_cloth.ogg ← round4/bag_pick_cloth_d1.ogg：freesound CC0 录音剪辑（src/synth2d.py，编号见上文第四轮）
- bag_pick_leather.ogg ← ogg/bag_pick_leather_v1.ogg：原创合成（src/synth2.py），项目自有
- bag_pick_metal.ogg ← ogg/bag_pick_metal_v3.ogg：原创合成（src/synth2.py），项目自有
- bag_place_cloth.ogg ← ogg/bag_place_cloth_v1.ogg：原创合成（src/synth2.py），项目自有
- bag_place_leather.ogg ← ogg/bag_place_leather_v1.ogg：原创合成（src/synth2.py），项目自有
- bag_place_metal.ogg ← ogg/bag_place_metal_v1.ogg：原创合成（src/synth2.py），项目自有
- bag_rotate.ogg ← round4/bag_rotate_d2.ogg：freesound CC0 录音剪辑（src/synth2d.py，编号见上文第四轮）
- battle_armor_break.ogg ← round4/battle_armor_break_d3.ogg：freesound CC0 录音剪辑（src/synth2d.py，编号见上文第四轮）
- battle_block.ogg ← round4/battle_block_d3.ogg：freesound CC0 录音剪辑（src/synth2d.py，编号见上文第四轮）
- battle_buff_down.ogg ← round5/battle_buff_down_e3.ogg：Kenney Interface Sounds minimize_006（CC0）变调
- battle_buff_up.ogg ← round4/battle_buff_up_d4.ogg：freesound CC0 录音剪辑（src/synth2d.py，编号见上文第四轮）
- battle_crit.ogg ← ogg/battle_crit_v3.ogg：原创合成（src/synth2.py），项目自有
- battle_fall.ogg ← round4/battle_fall_d3.ogg：freesound CC0 录音剪辑（src/synth2d.py，编号见上文第四轮）
- battle_hit_bleed.ogg ← ogg/battle_hit_bleed_v1.ogg：原创合成（src/synth2.py），项目自有
- battle_hit_fire.ogg ← ogg/battle_hit_fire_v1.ogg：原创合成（src/synth2.py），项目自有
- battle_hit_ice.ogg ← ogg/battle_hit_ice_v3.ogg：原创合成（src/synth2.py），项目自有
- battle_hit_lightning.ogg ← ogg/battle_hit_lightning_v1.ogg：原创合成（src/synth2.py），项目自有
- battle_hit_physical.ogg ← round4/battle_hit_physical_d4.ogg：freesound CC0 录音剪辑（src/synth2d.py，编号见上文第四轮）
- battle_hit_poison.ogg ← ogg/battle_hit_poison_v1.ogg：原创合成（src/synth2.py），项目自有
- battle_lose.ogg ← round5/battle_lose_e1.ogg：Kenney Music Jingles jingles_SAX07（CC0）加混响
- battle_reaction_1.ogg ← ogg/battle_reaction_1_v1.ogg：原创合成（src/synth2.py），项目自有
- battle_reaction_2.ogg ← ogg/battle_reaction_2_v1.ogg：原创合成（src/synth2.py），项目自有
- battle_reaction_3.ogg ← round4/battle_reaction_3_d4.ogg：freesound CC0 录音剪辑（src/synth2d.py，编号见上文第四轮）
- battle_reaction_4.ogg ← ogg/battle_reaction_4_v1.ogg：原创合成（src/synth2.py），项目自有
- battle_start.ogg ← round4/battle_start_d2.ogg：freesound CC0 录音剪辑（src/synth2d.py，编号见上文第四轮）
- battle_win.ogg ← round4/battle_win_d4.ogg：freesound CC0 录音剪辑（src/synth2d.py，编号见上文第四轮）
- loot_flip_r0.ogg ← ogg/loot_flip_r0_v1.ogg：原创合成（src/synth2.py），项目自有
- loot_flip_r1.ogg ← ogg/loot_flip_r1_v1.ogg：原创合成（src/synth2.py），项目自有
- loot_flip_r2.ogg ← ogg/loot_flip_r2_v1.ogg：原创合成（src/synth2.py），项目自有
- loot_flip_r3.ogg ← ogg/loot_flip_r3_v1.ogg：原创合成（src/synth2.py），项目自有
- loot_flip_r4.ogg ← ogg/loot_flip_r4_v1.ogg：原创合成（src/synth2.py），项目自有
- loot_flip_r5.ogg ← ogg/loot_flip_r5_v1.ogg：原创合成（src/synth2.py），项目自有
- loot_flip_done.ogg ← ogg/loot_flip_done_v1.ogg：原创合成（src/synth2.py），项目自有
- loot_take_all.ogg ← round4/loot_take_all_d1.ogg：freesound CC0 录音剪辑（src/synth2d.py，编号见上文第四轮）

## 用到的外部素材
- Kenney（kenney.nl）Music Jingles、Interface Sounds，CC0。
- freesound 337868「small-metal-hit-07.wav」作者 newagesoup，CC0，https://freesound.org/people/newagesoup/sounds/337868/
- freesound 369081「VSH-10-fist-thump-metal pipe-short.wav」作者 newagesoup，CC0，https://freesound.org/people/newagesoup/sounds/369081/
- freesound 369134「VSH-34-knuckle-rattle-metal pipe-short.wav」作者 newagesoup，CC0，https://freesound.org/people/newagesoup/sounds/369134/
- freesound 420673「Basic Melee Hit」作者 SypherZent，CC0，https://freesound.org/people/SypherZent/sounds/420673/
- freesound 422633「Break something (ice/glass/...)」作者 Aurelon，CC0，https://freesound.org/people/Aurelon/sounds/422633/
- freesound 455183「metal hit 2.wav」作者 deleted_user_4541234，CC0，https://freesound.org/people/deleted_user_4541234/sounds/455183/
- freesound 456966「Success Fanfare Trumpets.mp3」作者 FunWithSound，CC0，https://freesound.org/people/FunWithSound/sounds/456966/
- freesound 504626「BODY FALL - V HVY - DIRT」作者 leonelmail，CC0，https://freesound.org/people/leonelmail/sounds/504626/
- freesound 539956「war horn.wav」作者 adharca，CC0，https://freesound.org/people/adharca/sounds/539956/
- freesound 577965「rpgPowerup.wav」作者 colorsCrimsonTears，CC0，https://freesound.org/people/colorsCrimsonTears/sounds/577965/
- freesound 609569「GrabItemCloth.wav」作者 CJspellsfish，CC0，https://freesound.org/people/CJspellsfish/sounds/609569/
- freesound 674826「Tablesmack.wav」作者 Tomasek1a，CC0，https://freesound.org/people/Tomasek1a/sounds/674826/
- freesound 828802「Paper Page Flip」作者 OnlyOz，CC0，https://freesound.org/people/OnlyOz/sounds/828802/
- freesound 849845「Backpack Quick Grabbing」作者 MrGlitchedRed，CC0，https://freesound.org/people/MrGlitchedRed/sounds/849845/
