# 043 · M3-5 章节定义走内容管线

> 阶段 4 · M3 ｜ 架构文档 5.3、10（v1.42）｜ 计划见[报告 027](archive/027-m3-plan.md)

## 产出

| 文件 | 职责 |
|---|---|
| `core/run/chapter_def.gd` | `ChapterDef`：id、display_name、map_source。侵蚀、敌人池、掉落表到时候各加一个字段 |
| `core/authoring/content_paths.gd` | 加 `chapters`，导入顺序排最后 |
| `core/authoring/content_importer.gd` | `import_chapter` + `_validate_chapter`；三样通用能力（见下） |
| `core/authoring/content_exporter.gd` | `export_chapter`；对应的三样 |
| `tools/import_content.gd` | `_build` 多一个分支 |
| `tools/gen_sample_chapter.gd` | 把 `RingMapConfig.sample(6)` 倒成 `data/authoring/chapters/chapter_01.json` |
| `data/authoring/chapters/chapter_01.json` → `data/chapters/chapter_01.tres` | 第一章（数值占位） |
| `ui/map_editor/map_editor.gd` | 「章节」栏：载入 / 存回 |
| `tests/test_chapter_pipeline.gd` | 4 组 |

## 走现有管线，不另开一条路

计划 027 说这一步是对「导入器不认识具体类型」的第一次真实检验：它此前只喂过道具、增益、套装三种同源的东西。
章节配置的结构完全不同 —— `MapSource` 里套 `Resource` 类型的 `generator_config`，里面是 `Array[RingSpec]`、
`Array[RouteStyle]`、`Array[MapScaleProfile]`、`ZoneRules`、`DangerZoneSpec`，字段里有枚举、`Vector2`、
字典里套数组。`import_chapter` 本身八行，`_fill` 一个字没改，喂进去了。

但管线补了三样**通用**的东西，都是「章节碰巧先踩到」而不是「为章节开的例外」：

1. **`Vector2`。** 以前只有 `Vector2i`。`RouteStyle.risk_band` 是 `Vector2`，导成 `[x, y]`。
   它是单精度：`1.2` 存进去是 `1.2000000476837`，原样写出去 JSON 读回来的 double 就不等于它了，
   资产与作者数据的比对当场红。按六位小数写 —— 作者写的本来就是六位以内的数。
2. **字典里整数值的浮点两头都写成整数。** JSON 没有整数：`{"shop": [0, 1]}` 读回来是 `[0.0, 1.0]`，
   再导出就成了 `[0.0, 1.0]`，「导出→导入→再导出」的文本变了。第一版只在导入时归一，
   结果 `type_risk` 里的 `1.0` 被写成 `1` 而原文是 `1.0`，还是不一致。改成**两头都归一**
   （`MapGraph.normalize`，约定和地图存档一样：要小数就别写成整数值），往返才是不动点。
3. **声明成引擎基类的字段按 `type` 造类。** `generator_config: Resource` —— 导入器以前只认 `class_name` 过的类
   或注册表里的抽象基类，`Resource` 两边都不是。现在 JSON 里 `"type": "RingMapConfig"` 说造哪个类，
   造出来还得真是那个基类的东西（`"type": "ItemDef"` 会被拒）；导出器反过来在实例的类不等于声明的类时写上 `type`。

## 校验比引擎严格

- 没有 id、没有 map_source → 错。
- 随机生成：生成器没登记 → 错（报错列出已登记的）；没有配置 → 错；配置的类不是那个生成器 `default_config()` 的类 → 错。
  装错类的配置到开局才炸，那时离文件已经很远了。
- 载入预设：文件不在 → 错。
- 打错字段名 → 错，不是静默当默认值（这是 `_fill` 本来就有的）。

## 编辑器

地图编辑器左栏多了「章节」一行：下拉列出 `data/authoring/chapters/` 里的章；「载入」把那一章的生成器与配置
装进编辑器并生成一张；「存回」把当前的生成器 + 配置写回那一章 —— 存之前再导一遍（和命令行同一套校验），
作者数据 JSON 与引擎资产 `.tres` 一起写，不必再手动导入。参数表单本来就是反射的，章节配置一进来就能改。

## 验证

```
bash tools/test.sh
通过  3371 项断言，30 个套件（111 秒）
```

- 往返：导出的 JSON 带 `type`、Vector2 是 `[x, y]`；过一遍 JSON 文本导回来，六个环、三种风格、Vector2、
  字典里的配额（整数没变浮点）、高危区、三档规模都在；**再导出一次文本逐字节相同**。
- 导入前后的章节用同一个对局种子生成的是同一张图 —— 配置一个字段都没丢。
- 六种错误各报各的。
- 仓库里的 `chapter_01.json` 导得进、往返逐字节相同；`chapter_01.tres` 读出来与作者数据一致
  （`.tres` 会重排字典键的顺序，比的是解析后的字典），生成得出图。改了 JSON 忘了导入，这条会红。

## 遗留

- `ErosionSchedule`、`EnemyDef`、`LootTable` 还没有类，到第 7 阶段 / M4 各加一个字段。
- 编辑器「存回」只写随机生成的章；预设模式的章用「预设」栏。
- `chapter_01.json` 的数值全是 `sample()` 的占位。

## 下一步

M3-6：渲染与地图沙盒（布局求解：径向边垂直于切线；从章节开局、挑出生点、一步一步走）。
