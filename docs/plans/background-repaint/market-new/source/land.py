"""Ground and atmospheric backing for the north-facing market view."""

from pathlib import Path
import random


def build_market_land():
    rng = random.Random(59317)
    far_y = 49
    painted = STAGE >= 5
    sky = mat("远景 · 晴空", "#85b5cd")
    board = mesh(
        "远景画幕 · 连续山脊与天空",
        [(-53, far_y, -7), (55, far_y, -7), (55, far_y, 39), (-53, far_y, 39)],
        [(0, 1, 2, 3)],
        sky,
    )
    sky.use_nodes = True
    nodes = sky.node_tree.nodes
    links = sky.node_tree.links
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (0.29, 0.57, 0.75, 1)
    links.new(emission.outputs[0], nodes.get("Material Output").inputs["Surface"])
    board.visible_shadow = False
    board.visible_diffuse = False
    board.visible_glossy = False
    if painted:
        # The main script may execute this module or run it from a Blender text block.
        roots = [
            Path(str(globals().get(k, ".")))
            for k in ("SOURCE_DIR", "SOURCE", "SRC", "__file__", "ROOT", "OUT")
        ]
        roots += [Path.cwd(), Path(bpy.path.abspath("//"))]
        options = []
        for root in roots:
            root = root.parent if root.suffix else root
            options.extend(
                root / rel / ("distant-country.jpg" if STAGE >= 7 else "distant-blocks.jpg")
                for rel in ("", "source", "docs/plans/background-repaint/market-new/source")
            )
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(
            str(next(p for p in options if p.is_file())), check_existing=True
        )
        uv = board.data.uv_layers.new(name="画幕")
        for loop, coord in zip(
            board.data.polygons[0].loop_indices, [(0, 0), (1, 0), (1, 1), (0, 1)]
        ):
            uv.data[loop].uv = coord
        links.new(tex.outputs["Color"], emission.inputs["Color"])
    else:
        for index, (depth, height, color) in enumerate(
            ((48.8, 5.7, "#95abba"), (48.6, 3.6, "#818e89"))
        ):
            points = []
            for j in range(35):
                x = -53 + 3.2 * j
                crest = (
                    height + 0.5 * math.sin(x * 0.14 + index) + 0.35 * math.sin(x * 0.36 + index)
                )
                points.extend([(x, depth, -2), (x, depth, crest)])
            ridge = mesh(
                "远景 · 低丘大形",
                points,
                [(j, j + 2, j + 3, j + 1) for j in range(0, len(points) - 2, 2)],
                mat("远山" + str(index), color),
            )
            ridge.visible_shadow = False

    ground = mat("地表 · 夯土、车辙与路肩", "#aa895c", "plain")
    ground.use_nodes = True
    nodes, links = ground.node_tree.nodes, ground.node_tree.links
    shader = nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = 0.96
    tint = nodes.new("ShaderNodeVertexColor")
    tint.layer_name = "soil"
    links.new(tint.outputs["Color"], shader.inputs["Base Color"])
    if painted:
        position = nodes.new("ShaderNodeTexCoord")

        def grain(scale, detail):
            noise = nodes.new("ShaderNodeTexNoise")
            noise.inputs["Scale"].default_value = scale
            noise.inputs["Detail"].default_value = detail
            links.new(position.outputs["Object"], noise.inputs["Vector"])
            return noise.outputs["Fac"]

        mottling = nodes.new("ShaderNodeMixRGB")
        mottling.blend_type = "SOFT_LIGHT"
        mottling.inputs[0].default_value = 0.86
        links.new(tint.outputs[0], mottling.inputs[1])
        links.new(grain(0.9, 5), mottling.inputs[2])
        links.new(mottling.outputs[0], shader.inputs["Base Color"])
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.22
        bump.inputs["Distance"].default_value = 0.045
        links.new(grain(42, 2), bump.inputs["Height"])
        links.new(bump.outputs[0], shader.inputs["Normal"])
    if STAGE >= 7:
        # Mix two world-space projections on a broad noise field, so repeated
        # brush marks never advance in a regular grid across the foreground.
        world = nodes.new("ShaderNodeNewGeometry").outputs["Position"]
        painted_soil = bpy.data.images.load(
            str(Path(SOURCE) / "soil-paint.jpg"), check_existing=True
        )
        strokes = nodes.new("ShaderNodeMixRGB")
        links.new(grain(0.34, 1.5), strokes.inputs[0])
        for slot, scale, angle in [(1, 0.26, 0.31), (2, 0.19, -1.08)]:
            transform = nodes.new("ShaderNodeMapping")
            transform.inputs["Scale"].default_value = (scale, scale, scale)
            transform.inputs["Rotation"].default_value[2] = angle
            links.new(world, transform.inputs["Vector"])
            sample = nodes.new("ShaderNodeTexImage")
            sample.image = painted_soil
            links.new(transform.outputs[0], sample.inputs["Vector"])
            links.new(sample.outputs["Color"], strokes.inputs[slot])
        value = nodes.new("ShaderNodeRGBToBW")
        links.new(strokes.outputs[0], value.inputs[0])
        brush_values = nodes.new("ShaderNodeMapRange")
        brush_values.inputs["From Min"].default_value = 0.09
        brush_values.inputs["From Max"].default_value = 0.39
        brush_values.inputs["To Min"].default_value = 0.20
        brush_values.inputs["To Max"].default_value = 0.82
        links.new(value.outputs[0], brush_values.inputs["Value"])
        wear = nodes.new("ShaderNodeAttribute")
        wear.attribute_name = "ground_paint_strength"
        glaze = nodes.new("ShaderNodeMixRGB")
        glaze.blend_type = "OVERLAY"
        links.new(wear.outputs["Fac"], glaze.inputs[0])
        links.new(mottling.outputs[0], glaze.inputs[1])
        links.new(brush_values.outputs[0], glaze.inputs[2])
        links.new(glaze.outputs[0], shader.inputs["Base Color"])
    if STAGE >= 7:
        # Let the far terrain dissolve into the continuous painted foothills.
        # The baked plate remains physically behind both the road and fence.
        geo = nodes.new("ShaderNodeNewGeometry")
        axis = nodes.new("ShaderNodeSeparateXYZ")
        links.new(geo.outputs["Position"], axis.inputs[0])
        ramp = nodes.new("ShaderNodeMapRange")
        ramp.interpolation_type = "SMOOTHERSTEP"
        ramp.inputs["From Min"].default_value = 19
        ramp.inputs["From Max"].default_value = 48
        links.new(axis.outputs["Y"], ramp.inputs[0])
        trans = nodes.new("ShaderNodeBsdfTransparent")
        mix = nodes.new("ShaderNodeMixShader")
        links.new(ramp.outputs[0], mix.inputs[0])
        links.new(shader.outputs[0], mix.inputs[1])
        links.new(trans.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], nodes.get("Material Output").inputs[0])

    def center(y):
        u = max(0, min(1, (y + 7) / 18))
        return 0.7 + 3.5 * u * u * (3 - 2 * u)

    def roadwidth(y):
        return 1.675 + max(0, -y - 1) * 0.023

    def wave(y):
        return (
            math.sin(y * 1.61) * 0.06 + 0.09 * math.sin(y * 0.72 + 0.5) + 0.055 * math.sin(y * 3.23)
        )

    offsets = [
        -65,
        -19,
        -9,
        -4,
        -2,
        -1.42,
        -1.17,
        -1,
        -0.86,
        -0.66,
        -0.51,
        -0.40,
        -0.2,
        0,
        0.22,
        0.41,
        0.53,
        0.67,
        0.86,
        1,
        1.17,
        1.42,
        2,
        4,
        9,
        19,
        65,
    ]

    def linear(hexcolor):
        return tuple(
            ((int(hexcolor[i : i + 2], 16) / 255 + 0.055) / 1.055) ** 2.4 for i in (0, 2, 4)
        )

    shoulder = linear("a69366")
    verge = linear("ad966b")
    dust = linear("c6aa7e")
    rut = linear("ae936b" if STAGE >= 8 else "b99e74")
    verts, faces, colors = [], [], []
    for j in range(174):
        y = -22 + j * 0.41
        for k, v in enumerate(offsets):
            x = center(y) + v * roadwidth(y) + wave(y + (3 if v > 0 else 0)) * min(1, abs(v) * 1.5)
            a = abs(v)
            c = (
                shoulder
                if a > 1.3
                else verge if a > 1 else rut if 0.46 < a < 0.6 and STAGE >= 6 else dust
            )
            factor = (
                (1.0 + 0.032 * math.sin(y * 1.24 + k * 2.1) + 0.022 * rng.uniform(-1, 1))
                if painted
                else 1
            )
            z = -0.048 + (0.012 * math.sin(x * 0.8 + y * 0.43) if painted else 0)
            if STAGE >= 8:
                z = -0.048  # Firm level standing areas, with wheel ruts inside the travelled lane.
            if painted and 0.46 < a < 0.6:
                z -= 0.012
            verts.append((x, y, z))
            colors.append(tuple(t * factor for t in c) + (1,))
            if j and k:
                n = len(verts) - 1
                w = len(offsets)
                faces.append((n - w - 1, n - w, n, n - 1))
    earth = mesh("地面 · 同一条土路穿过营门", verts, faces, ground)
    vertex_color = earth.data.color_attributes.new(name="soil", type="FLOAT_COLOR", domain="POINT")
    vertex_color.data.foreach_set("color", [v for color in colors for v in color])
    if STAGE >= 8:
        # The top dressing meets wheel treads, prop feet and tent stakes at grade.
        for v in earth.data.vertices:
            v.co.z += 0.048
    for f in earth.data.polygons:
        f.use_smooth = True
    if STAGE < 7:
        return
    paint_strength = earth.data.attributes.new("ground_paint_strength", "FLOAT", "POINT")
    strengths = [0.22 + 0.50 * min(1, max(0, (abs(offset) - 0.68) / 0.73)) for offset in offsets]
    paint_strength.data.foreach_set("value", strengths * (len(verts) // len(offsets)))

    # Batch small pieces by material to keep the source scene easy to inspect.
    stones = [([], []) for _ in range(3)]
    grass = [([], []) for _ in range(2)]
    for _ in range(96 if STAGE >= 8 else 52):
        y = rng.uniform(-15, 24)
        side = rng.choice([-1, 1])
        x = center(y) + side * (roadwidth(y) + rng.uniform(0.20, 5.8))
        for _ in range(rng.randint(2, 7)):
            xx, yy = x + rng.uniform(-0.39, 0.39), y + rng.uniform(-0.42, 0.42)
            radius = rng.uniform(0.022, 0.089)
            vv, ff = rng.choice(stones)
            n = len(vv)
            for iz in range(2):
                for a in range(5):
                    angle = a * 2 * math.pi / 5 + 0.28 * iz
                    r = radius * rng.uniform(0.6, 1.2) * (1 - 0.57 * iz)
                    vv.append(
                        (
                            xx + math.cos(angle) * r,
                            yy + math.sin(angle) * r * 0.77,
                            -0.055 + iz * radius * 0.6,
                        )
                    )
            ff.append(tuple(n + 5 + i for i in range(5)))
            ff.extend((n + i, n + (i + 1) % 5, n + 5 + (i + 1) % 5, n + 5 + i) for i in range(5))
        if rng.random() < 0.45:
            for _ in range(rng.randint(5, 13)):
                xx, yy = x + rng.uniform(-0.08, 0.08), y + rng.uniform(-0.08, 0.08)
                angle = rng.uniform(0, 2 * math.pi)
                h = rng.uniform(0.058, 0.19)
                dx, dy = math.sin(angle) * 0.012, math.cos(angle) * 0.012
                vv, ff = rng.choice(grass)
                n = len(vv)
                vv.extend(
                    (
                        (xx - dx, yy + dy, -0.045),
                        (xx + dx, yy - dy, -0.045),
                        (xx + dy * h * 50, yy + dx * h * 50, h - 0.045),
                    )
                )
                ff.append((n, n + 1, n + 2))
    for group, palette, name in [
        (stones, ["#958775", "#b7a489", "#a59679"], "路肩 · 风蚀石"),
        (grass, ["#868651", "#a1955b"], "路肩 · 秋草"),
    ]:
        for i, ((vv, ff), c) in enumerate(zip(group, palette)):
            if vv:
                detail = mesh(name + str(i), vv, ff, mat(name + str(i), c))
                if STAGE >= 8:
                    detail.location.z += 0.048


build_market_land()
