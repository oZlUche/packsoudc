# 打包字体（168）

| 文件 | 来源 | 版本 | 用在哪 |
|---|---|---|---|
| `wenkai_regular.ttf` | 霞鹜文楷 LXGW WenKai Regular（github.com/lxgw/LxgwWenKai） | 1.530 | 正文、读数、按钮（`UiPalette.cjk_font()`，主题默认字体） |
| `wenkai_medium.ttf` | 霞鹜文楷 Medium | 1.530 | 粗体：富文本 `[b]`（`cjk_font_bold()`） |
| `zhuque_fangsong.ttf` | 朱雀仿宋 Zhuque Fangsong（github.com/TrionesType/zhuque） | 0.212 技术预览 | 标题、名牌、叠层标题条（`title_font()`） |
| `mashanzheng.ttf` | 马善政 Ma Shan Zheng（github.com/googlefonts/mashanzheng） | 2.003 | 大标题：主菜单游戏名、章节名、宝箱屏说明（`display_font()`，变体 `LabelDisplay`） |

三款都是 SIL Open Font License 1.1，授权原文在 `LICENSES/`，随游戏一起分发。

## 子集与改名

四个文件都是**按文案裁过字的子集**（`charset.txt` 是字集，一行一个字），原始字体（每份文楷 25 MB）不入库，放在共享目录 `art/fonts/chosen/` 与作者机器上。

霞鹜文楷的授权保留了字体名「霞鹜 / 霞鶩 / 落霞孤鹜 / 落霞孤鶩 / LXGW」，附加许可只放行网页字体用的子集。游戏里带的子集是修改版，所以裁完把字体名改成 **PackSDC Kai**（`subset_fonts.sh` 里那一步），版权与授权那几条名字记录原样留着。朱雀仿宋、马善政没有保留字体名，不改。

缺字不会出方块：文楷后备系统字体，朱雀仿宋后备文楷 Medium，马善政后备朱雀仿宋。

## 重裁

文案里新加了字，`tests/ui/test_fonts_168.gd` 的覆盖用例与 `tools/check_content.gd` 会红，列出缺的字。重裁：

```sh
python3 -m pip install fonttools              # 一次
python3 tools/font_charset.py                  # 重写 charset.txt
tools/subset_fonts.sh [原始字体目录]           # 默认 /mnt/project-files/art/fonts/chosen
```

提交四个子集与 `charset.txt`。导入参数（`.import`）：灰度抗锯齿、轻微 hinting、子像素定位、不用 MSDF、随窗口缩放。
