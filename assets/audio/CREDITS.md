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
