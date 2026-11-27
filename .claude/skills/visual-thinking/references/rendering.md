# 字体与渲染

精确的关系图优先使用可编辑 SVG，并交付可见的 PNG。可以使用当前环境已有的可靠渲染工具；下面的脚本是可选助手，不是额外的必装系统。

## 字体

样例使用：

```css
font-family: "PingFang SC", "Noto Sans CJK SC", "Source Han Sans SC", "Microsoft YaHei", "Helvetica Neue", sans-serif;
```

macOS 通常可用首选字体；其他系统需安装合适的中文字体。后备名称不会自动下载字体，也不能保证各系统字宽一致。本仓库不附带字体文件。换字体后，重新检查断行、节点内文字与标签遮挡，不能只看“文件生成成功”。

SVG 使用明确的 viewBox 与尺寸；文本保留为文字便于编辑。正文、关系标签与来源分层，来源即便用小字也要在目标显示尺寸可读。构图与字号层级以整图预览判断，不生成额外设备适配版。

## 可选 Node.js 渲染器

需要 Node.js、Playwright 以及 Chromium 或本机 Chrome。先检查当前环境是否已提供依赖：可用 `node -p "require.resolve('playwright')"` 探测当前Node路径；若环境提供依赖位置查询工具，优先读取其返回路径并设置NODE_PATH，不扫描整台机器。示例缓存目录只有在执行下方安装命令后才会存在，不能假定其他用户已经安装在那里。已有Playwright就复用；确实没有时可在独立工具目录安装，避免把node_modules打包进skill。下面命令为 macOS/Linux shell 示例：

```sh
npm install --prefix "$HOME/.cache/visual-thinking-render" playwright
NODE_PATH="$HOME/.cache/visual-thinking-render/node_modules" node -e "require('playwright').chromium.executablePath()"
```

若准备使用 Playwright 自带的 Chromium，再运行：

```sh
"$HOME/.cache/visual-thinking-render/node_modules/.bin/playwright" install chromium
```

在 skill 根目录中渲染，输出到临时目录：

```sh
NODE_PATH="$HOME/.cache/visual-thinking-render/node_modules" node scripts/render-svg.cjs assets/examples/confirmation-gate.svg /tmp/confirmation-gate.png
```

使用已经安装的 Chrome 时，追加 `--channel chrome`；用 `--scale 1` 降低输出像素尺寸。Windows 可设置相应的 NODE_PATH 环境变量并换用本机输出路径；该系统尚未实测。依赖版本和浏览器须按使用环境维护，本仓库不承诺跨版本像素一致。

脚本会等待字体、按 viewBox 渲染、报告布局诊断与声明的字体栈。报告中的 width/height 是画布尺寸；PNG 的实际像素尺寸约为画布尺寸乘以 scale（默认 2）。退出码 0 表示渲染成功且没有出界或布局疑点；2 表示图片已生成但存在出界或布局疑点；1 表示参数或渲染失败。可访问性提示单独报告，不改变退出码。它拒绝脚本、外部资源、嵌入图片与外部字体，适合本 skill 的自包含几何 SVG，不作为通用 SVG 转换器。

## 仍需肉眼检查

打开整图以及拥挤局部，检查中文缺字、文字互相遮挡、标签背景盖住其他节点、箭头终点和边界歧义。脚本可检查下述显式标注的几何，仍无法判断结构含义或中文实际使用了哪个字体。诊断为零不等于排版通过。

检查后再在聊天里直接展示 PNG，并按需附 SVG。无法打开预览时如实说明，不宣称完成视觉检查。

## 主题应用

为新 SVG 放置一个专用空样式块 `<style data-vt-theme=""></style>`，图形属性引用[主题变量](skins.md)。然后运行：

```sh
node scripts/apply-theme.cjs draft.svg themed.svg monochrome
```

也可用 `color-blocks` 或 `sticker-board`。输入与输出须为不同文件；脚本只替换专用样式块，不推断普通 SVG 的颜色含义，也不移动元素。正常绘图时可直接从 themes.json 取值，不强制经过脚本。

## 诊断标注

文字越界与文字包围盒相交检查适用于可见的 text。几何含义无法可靠地从样式猜出，新图需要更细检查时可显式标注：

```xml
<circle id="decision" data-node="" cx="160" cy="160" r="70"/>
<text x="130" y="168" data-in-node="decision" data-padding="6">条件</text>
<path id="route" data-edge="" data-from="decision" data-to="next"
      d="M230 160H360"/>
```

`data-node` 标注节点的几何边界，`data-edge` 标注关系的几何路径；标在 circle、rect、ellipse、path、line 等具体几何元素上，不标在 g 上。示例中的 `next` 也应是实际存在且标注过的节点。端点节点不计为路径穿越障碍，但端点文字仍检查。`data-padding` 是渲染页面 CSS 像素中的留白；变换后的包围盒与实际几何一起判断。data 属性仅供诊断，不改变图片外观。

关系标签必须用底色断开线条时，可以标注：

```xml
<rect id="label-bg" data-label-mask="relation" data-for-edge="route"
      x="260" y="135" width="90" height="40"/>
<text id="relation" data-edge-label="route" x="268" y="160">需要</text>
```

指定标签允许覆盖其对应的线，但遮罩靠近其他文字或节点仍会提示。不要只为消除提示而乱加标注。实际有意叠放的两个元素可用 `data-allow-overlap="另一个元素的id"` 和 `data-overlap-reason="具体原因"` 声明；这只豁免该对元素，不豁免整组。背景与装饰几何可标 `data-decoration`，不冒充经过语义检查的节点。表格分隔线可标 `data-decoration="grid"`：行列坐标承担结构，网格本身不是关系箭头。不要为了消除诊断而断开本来有意义的共享边界。

多行文字推荐显式 tspan，便于按行检查。小字与来源的文字层级由实际构图决定，不设自动字号门槛。

## 报告的解释与边界

报告包含：

- `overflow`：文字超出画布；`issues`：碰撞、路径穿字、节点内边距、遮罩候选与标注错误。
- `coverage`：已标注的节点、边、遮罩和未检查几何数量。旧 SVG 未标注时不能宣称连线与遮罩通过。
- `accessibility`：标题、描述与名称引用是否存在，不代表已完成屏幕阅读器实测。

文字相交依赖浏览器包围盒，旋转、特殊字体、裁剪或透明叠放可能产生误报；路径按长度采样，最多 10000 个间隔，极长路径的细小碰撞可能漏检。描边厚度、箭头标记和滤镜的全部绘制范围未纳入；遮罩提示采用保守包围盒，不判断绘制顺序。节点留白按文字包围盒采样，不是所有复杂凹形的严格包含证明。符号意义、因果关系与视觉美感仍需人工检查。

新增 SVG 使用独立的 title 与 desc，根节点设置 role="img"、aria-labelledby 指向标题，aria-describedby 指向结构描述。描述说明主要对象、关系与可做的操作；不能只重复标题。PNG 交付时配简短替代文字。

## 回归测试

已有 Node.js、Playwright 和浏览器环境时，从 skill 根目录运行：

```sh
node --test tests/layout.test.cjs
```

使用系统 Chrome 时设置 `VT_BROWSER_CHANNEL=chrome`，Playwright 不在当前依赖路径时设置 NODE_PATH。测试覆盖有意交叠、文字碰撞、曲线、端点、遮罩、坐标变换和换肤结构不变。测试使用程序内自绘夹具，不把故意有问题的图放进示例图库。行为试用另见[验证方法](evaluation.md)。
