肖像（157）：`enemies/<敌人 id>.png`、`characters/<角色 id>.png`。没图的放占位剪影。

214（作者 2026-10-20）：源图 **256×256**，正方形；各处按位子缩放 —— 铭牌肖像位 96、开局角色卡大头像 160。文件名就是 id，放进目录即生效。

214 定稿（作者 2026-10-20 15:26 选乙「罗马铜币侧像」）：每张是一整枚币，圆外透明，侧像朝右；金属分阵营 —— 角色金、人类青铜、机关黄铜配铜绿、魔兽银。圆框 `assets/ui/portrait_frame.png` 盖在币缘最外一圈上，不外扩。
导入要开 `mipmaps/generate`（新图的 `.import` 照抄已有的）：缩到 96 / 160 / 32，不开 mipmap 币缘细纹会起锯齿。
`@2x`（512）只留在美术源目录（`art/portraits/final/`），游戏不读。

365（作者 2026-11-21）：敌人头像按 A 难度分档换金属 —— 普通敌人 A0 铜、A1–A3 银、A4+ 金；精英 A0–A3 银、A4+ 金；首领一律金。取代 214 的「金属分阵营」。
做法是两层叠：`enemies/relief/<敌人 id>.png` 只有轮廓和光影（黑白半透明，底透明），叠在 `coins/coin_<bronze|silver|gold>.png` 币底上，最外再盖 `assets/ui/portrait_frame_<同一金属>.png`（作者选 B：外圈跟着底换色）。三张都是 256，圆心对齐，直接叠。
生成脚本：`/mnt/project-files/art/portraits/tiers365/gen_tiers.py`（`python3 gen_tiers.py all`）。
