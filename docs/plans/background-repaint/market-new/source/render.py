"""Run in Blender: STAGE=3 blender -b -P source/render.py (set MARKET_ART to study directory)."""

import bpy, math, os, time
from pathlib import Path
from mathutils import Vector
from math import radians

ROOT = Path(os.environ.get("MARKET_ART", Path(__file__).resolve().parent.parent))
SOURCE = ROOT / "source"
STAGE = int(os.environ.get("STAGE", 3))
out = Path(os.environ.get("RENDER_OUT", ROOT / "build"))
out.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def lin(x):
    x = int(x, 16) / 255
    return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4


def rgb(s):
    s = s.strip("#")
    return tuple(lin(s[i : i + 2]) for i in (0, 2, 4)) + (1,)


def mat(name, hexcolor, kind="plain"):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    col = rgb(hexcolor)
    m.diffuse_color = col
    m.use_nodes = True
    tree = m.node_tree
    n = tree.nodes
    l = tree.links
    bs = n.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = col
    bs.inputs["Roughness"].default_value = 0.45 if kind == "metal" else 0.8
    if kind == "metal":
        bs.inputs["Metallic"].default_value = 0.45
    if STAGE >= 7 and kind != "plain":
        tex = n.new("ShaderNodeTexCoord")
        vm = n.new("ShaderNodeVectorMath")
        vm.operation = "MULTIPLY"
        vm.inputs[1].default_value = (1.4, 8, 10) if kind == "wood" else (3, 3, 3)
        l.new(tex.outputs["Generated"], vm.inputs[0])
        if kind == "wood":
            m["structural_wood"] = True
            att = n.new("ShaderNodeAttribute")
            att.attribute_name = "local_grain"
            vm.inputs[1].default_value = (1, 1, 1)
            l.new(att.outputs["Vector"], vm.inputs[0])
        noise = n.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 4.8
        noise.inputs["Detail"].default_value = 3
        l.new(vm.outputs[0], noise.inputs[0])
        r = n.new("ShaderNodeValToRGB")
        for i, k in enumerate((0.66, 1.23)):
            e = r.color_ramp.elements[i]
            e.position = (0.23, 0.78)[i]
            e.color = tuple(min(1, v * k) for v in col[:3]) + (1,)
        l.new(noise.outputs["Fac"], r.inputs[0])
        l.new(r.outputs["Color"], bs.inputs["Base Color"])
        bump = n.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.13
        bump.inputs["Distance"].default_value = 0.023
        l.new(noise.outputs["Fac"], bump.inputs["Height"])
        l.new(bump.outputs[0], bs.inputs["Normal"])
    if kind == "cloth" and STAGE >= 7:
        from runpy import run_path

        enhance_fabric = run_path(str(SOURCE / "fabric.py"))["enhance_fabric"]
        enhance_fabric(tree, bs, tex, r.outputs["Color"], SOURCE)
    if kind == "cloth" and STAGE >= 5:
        scatter = n.new("ShaderNodeBsdfTranslucent")
        scatter.inputs[0].default_value = col
        mix = n.new("ShaderNodeMixShader")
        mix.inputs[0].default_value = 0.27
        l.new(bs.outputs[0], mix.inputs[1])
        l.new(scatter.outputs[0], mix.inputs[2])
        l.new(mix.outputs[0], n.get("Material Output").inputs[0])
    return m


def mesh(name, verts, faces, material):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    if material:
        me.materials.append(material)
    return ob


def box(name, loc, dims, material):
    x, y, z = [i / 2 for i in dims]
    ob = mesh(
        name,
        [
            (-x, -y, -z),
            (x, -y, -z),
            (x, y, -z),
            (-x, y, -z),
            (-x, -y, z),
            (x, -y, z),
            (x, y, z),
            (-x, y, z),
        ],
        [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)],
        material,
    )
    ob.location = loc
    if STAGE >= 7 and min(dims) > 0.045:
        mod = ob.modifiers.new("Softly worn edge", "BEVEL")
        mod.width = min(0.025, min(dims) * 0.09)
        mod.segments = 2
        mod = ob.modifiers.new("Face normals", "WEIGHTED_NORMAL")
    return ob


def beam(name, start, end, width, material):
    a, b = Vector(start), Vector(end)
    d = b - a
    dims = (width, width) if isinstance(width, (int, float)) else tuple(width)
    o = box(name, (a + b) / 2, (*dims, d.length), material)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return o


groups = {}
for group in ["land", "gate", "tents", "cargo"]:
    before = set(scene.objects)
    path = SOURCE / (group + ".py")
    exec(compile(path.read_text(), str(path), "exec"), dict(globals(), __file__=str(path)))
    groups[group] = set(scene.objects) - before
if STAGE >= 7:
    for group in groups.values():
        for ob in group:
            if ob.type != "MESH" or not ob.data.materials:
                continue
            m = ob.data.materials[0]
            if not m or not m.get("structural_wood"):
                continue
            coords = [v.co.copy() for v in ob.data.vertices]
            if not coords:
                continue
            spans = [max(v[k] for v in coords) - min(v[k] for v in coords) for k in range(3)]
            axis = spans.index(max(spans))
            a = ob.data.attributes.new("local_grain", "FLOAT_VECTOR", "POINT")
            for item, v in zip(a.data, coords):
                item.vector = [v[k] * (0.9 if k == axis else 9) for k in range(3)]
near_standard = {o for o in groups["gate"] if o.get("near_standard")}
groups["gate"] -= near_standard
groups["cargo"] |= near_standard
camdat = bpy.data.cameras.new("Perspective")
cam = bpy.data.objects.new("Market camera", camdat)
scene.collection.objects.link(cam)


def point(ob, target):
    ob.rotation_euler = (Vector(target) - ob.location).to_track_quat("-Z", "Y").to_euler()


cam.location = (0, -22, 4.2)
point(cam, (0.7, 12, 2.25))
camdat.lens = 28.25
camdat.clip_end = 1600
scene.camera = cam
if STAGE >= 5:
    # Broad warm bounce from sunlit earth seen by each opening.
    for i, (pos, aim, power, size) in enumerate(
        [
            ((-10, -3.9, 1.1), (-10, 1, 1.15), 235, 3.5),
            ((-8, 2.6, 1.05), (-8, 5.8, 1.3), 145, 2.6),
            ((11, -1.7, 1.2), (11, 3.2, 1.25), 260, 3.5),
            ((-6, -10, 0.8), (-6, -7, 1.1), 40, 2.8),
        ]
    ):
        lamp = bpy.data.lights.new("Soil bounce " + str(i), "AREA")
        lamp.energy = power
        lamp.shape = "DISK"
        lamp.size = size
        lamp.color = (1, 0.81, 0.59)
        o = bpy.data.objects.new(lamp.name, lamp)
        scene.collection.objects.link(o)
        o.location = pos
        point(o, aim)
        if STAGE >= 8:
            receivers = bpy.data.collections.new("Bounce receivers " + str(i))
            for item in groups["cargo" if i == 3 else "tents"]:
                receivers.objects.link(item)
            o.light_linking.receiver_collection = receivers
world = bpy.data.worlds.new("Open sky fill")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (0.62, 0.78, 1, 1)
bg.inputs[1].default_value = 0.58
sun = bpy.data.lights.new("Afternoon sun", "SUN")
sun.energy = 3.5
sun.angle = radians(3)
sun.color = (1, 0.88, 0.73)
ob = bpy.data.objects.new("Sun / front left", sun)
scene.collection.objects.link(ob)
ob.location = (-15, -12, 22)
point(ob, (0, 0, 0))
scene.render.engine = "CYCLES"
scene.cycles.samples = 32 if STAGE >= 5 else 2
scene.cycles.use_denoising = False
scene.cycles.max_bounces = 3
scene.render.threads_mode = "FIXED"
scene.render.threads = 4
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.resolution_percentage = 100 if STAGE >= 6 else 75
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "AgX"


def render(file):
    scene.render.filepath = str(file)
    bpy.ops.render.render(write_still=True)


if os.environ.get("SURVEY_ONLY"):
    pass
elif STAGE == 3:
    scene.render.engine = "CYCLES"
    scene.view_settings.view_transform = "Standard"
    clay = mat("White model", "#eee7d2")
    scene.view_layers[0].material_override = clay
    emission = clay.node_tree.nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (0.9, 0.86, 0.77, 1)
    clay.node_tree.links.new(
        emission.outputs[0], clay.node_tree.nodes.get("Material Output").inputs[0]
    )
    earth = next(o for o in groups["land"] if o.name.startswith("地面"))
    # Flag the longitudinal mesh edges that bound the walkable lane.
    for edge in earth.data.edges:
        a, b = edge.vertices
        if abs(a - b) == 27 and a % 27 in (7, 19):
            edge.use_freestyle_mark = True

    scene.render.use_freestyle = True
    scene.render.line_thickness = 0.72
    ls = scene.view_layers[0].freestyle_settings.linesets[0]
    ls.linestyle = bpy.data.linestyles.new("Structure ink")
    ls.select_edge_mark = True
    line = ls.linestyle
    line.color = (0.055, 0.045, 0.035)
    line.thickness = 1.65
    render(out / "03-camera.png")
    for ob in groups["land"]:
        ob.hide_render = True
    box("Survey datum", (0, 0, -0.12), (68, 63, 0.2), clay)
    for name, eye, target, scale in [
        ("top", (0, 2, 62), (0, 2, 0), 44),
        ("front", (0, -65, 3), (0, 6, 3), 37),
        ("side", (65, 1, 3), (0, 1, 3), 29),
    ]:
        cam.location = eye
        point(cam, target)
        camdat.type = "ORTHO"
        camdat.ortho_scale = scale
        if name == "top":
            cam.rotation_euler = (0, 0, 0)
        scene.render.resolution_x = 900
        scene.render.resolution_y = 600
        render(out / ("view-" + name + ".png"))
elif STAGE == 5:
    render(out / "05-light.png")
else:
    scene.render.film_transparent = True
    for group in groups:
        if os.getenv("ONLY_LAYER") not in (None, group):
            continue
        for k, obs in groups.items():
            for ob in obs:
                ob.visible_camera = k == group
        render(out / (str(STAGE) + "-" + group + ".png"))
    for obs in groups.values():
        for ob in obs:
            ob.visible_camera = True
    if STAGE == 8:
        scene.render.film_transparent = False
        for key, obs in groups.items():
            col = bpy.data.collections.new(key.title())
            scene.collection.children.link(col)
            for ob in obs:
                for old in list(ob.users_collection):
                    if not old.name.startswith("Bounce receivers"):
                        old.objects.unlink(ob)
                col.objects.link(ob)
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "market.blend"), compress=True)
if STAGE >= 5 and not os.getenv("ONLY_LAYER"):
    exec(
        compile((SOURCE / "current_views.py").read_text(), str(SOURCE / "current_views.py"), "exec")
    )
