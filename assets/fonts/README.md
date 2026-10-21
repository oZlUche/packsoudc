# 打包字体（168）

| 文件 | 来源 | 版本 | 用在哪 |
|---|---|---|---|
| `serif_regular.otf` | 思源宋体 Noto Serif CJK SC Regular（github.com/notofonts/noto-cjk） | 2.003 | 正文、读数、按钮（`UiPalette.cjk_font()`，主题默认字体） |
| `serif_bold.otf` | 思源宋体 Noto Serif CJK SC Bold | 2.003 | 粗体：名字、数字、富文本 `[b]`（`cjk_font_bold()`） |
| `zhuque_fangsong.ttf` | 朱雀仿宋 Zhuque Fangsong（github.com/TrionesType/zhuque） | 0.212 技术预览 | 标题、名牌、叠层标题条（`title_font()`） |
| `mashanzheng.ttf` | 马善政 Ma Shan Zheng（github.com/googlefonts/mashanzheng） | 2.003 | 大标题：章节名、宝箱屏说明（`display_font()`，变体 `LabelDisplay`） |
| `cinzel_bold.ttf` | Cinzel Bold（github.com/NDISCOVER/Cinzel，Google Fonts） | 2.000 | 224：结算账单的数字（`numeral_font()`）。只裁数字、I V X 和 `+ − - % / · —` 空格，不按字集裁 |

五个文件四款字体，都是 SIL Open Font License 1.1，授权原文在 `LICENSES/`，随游戏一起分发。

## 子集与改名

四个文件都是**按文案裁过字的子集**（`charset.txt` 是字集，一行一个字），原始字体（每份思源宋体 25 MB）不入库，放在共享目录 `art/fonts/chosen/` 与作者机器上。

170 定稿（作者 2026-10-14 挑 A）：正文从霞鹜文楷（168 时裁字后改名 PackSDC Kai）换成思源宋体 Regular / Bold。思源宋体、朱雀仿宋、马善政都没有保留字体名，子集照原名，不改名。

缺字不会出方块：正文后备系统字体，朱雀仿宋后备思源宋体 Bold，马善政后备朱雀仿宋，Cinzel 后备思源宋体 Bold。

## 重裁

文案里新加了字，`tests/ui/test_fonts_168.gd` 的覆盖用例与 `tools/check_content.gd` 会红，列出缺的字。重裁：

```sh
python3 -m pip install fonttools              # 一次
python3 tools/font_charset.py                  # 重写 charset.txt
tools/subset_fonts.sh [原始字体目录]           # 默认 /mnt/project-files/art/fonts/chosen
```

提交四个子集与 `charset.txt`。导入参数（`.import`）：灰度抗锯齿、轻微 hinting、子像素定位、不用 MSDF、随窗口缩放。
