# 百科（114）

暂停菜单（Esc）和主菜单里的「百科」。框架由报告 114 定，**机制页的文案由别的线程写**，这里说怎么写。

## 两类页

| 类 | 来源 | 写不写 |
|---|---|---|
| 机制页 | `data/authoring/help_pages/<id>.json` → `data/help_pages/<id>.tres`（`HelpPageDef`） | 手写 |
| 词条页 | 固定词条（`Glossary.TERMS`）、非内部标签、伤害类型、道具里出现的 buff、属性 / 乘区 / 时机 | 自动生成，文字跟着定义改 |

属性、乘区、时机和固定词条同名的（急速、冷却、自发……）不另开页。还没有说明的词条页显示「这一页的说明还没写。」

## 机制页的字段

```json
{
  "id": "crafting",
  "display_name": "合成",
  "display_names": {"en": "Crafting"},
  "category": "bag",
  "order": 0,
  "text": "正文，占位符与样式码照用（docs/text-placeholders.md），不写阿拉伯数字",
  "texts": {"en": "..."},
  "related": ["另一页的 id", "或固定词条名"],
  "see_items": ["道具 id"]
}
```

- `category`：`flow` 流程、`bag` 背包、`combat` 战斗规则、`faith` 信仰、`map` 地图、`meta` 局外。目录按这个顺序，分类里按 `order`。
- `id` 不能带冒号（冒号留给生成的词条页：`term:` `tag:` `dtype:` `buff:` `stat:` `cat:` `trigger:`）。
- 正文里出现的词条名 / 页标题自动画成链接；机制页标题压过同名词条（「合成」跳机制页）。
- `see_items` 里图鉴没点亮的道具写「？」。
- 导入时查：分类、标题与正文不空、`see_items` 是真道具、文本里的 `{item:}` `{enemy:}` `{faith:}` 存在、`related` 指得到（页 id 或词条名）、没有裸数字。

## 首批要写的页（方案 114 第五节）

流程：地图与走步、搜索点、战斗与战前准备、暂存区、撤离与失败、体力、结算与仓库。
背包：拖放与旋转、包、双击快速置入、整理、合成（已有）、增益槽与受益槽、信物与右键。
战斗规则：自动战斗怎么跑、直接伤害与防护、护盾、buff 与叠层、耐力与冷却、急速、乘区。
信仰：信物与激活、信力与阶、神坛献祭、特殊操作、切换与休眠、各神一页。
地图：节点类型、随机点、商店、休息点、保险箱、倒计时与撤离点关闭、猎手、侵蚀。
局外：仓库、科技、图鉴、成就、存档位。

## 代码

`core/text/help_page_def.gd`（定义）、`core/text/encyclopedia.gd`（页表、目录、搜索、渲染与链接）、`ui/game/encyclopedia_screen.gd`（屏）、`GameFlow.encyclopedia()` / `show_encyclopedia(page)`、`MapScreen.pause_encyclopedia(page)`。打开时可带 `page` 直接定位。
