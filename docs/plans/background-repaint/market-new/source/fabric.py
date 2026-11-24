"""Painted flax albedo for the finished cloth shading."""

import bpy


def enhance_fabric(tree, bs, coords, previous_color, SOURCE):
    nodes, links = tree.nodes, tree.links
    paint = nodes.new("ShaderNodeTexImage")
    paint.label = "Hand-painted flax fibres and ochre dye"
    paint.image = bpy.data.images.load(str(SOURCE / "flax-paint.jpg"), check_existing=True)
    paint.projection = "BOX"
    paint.projection_blend = 0.15
    # Use object-space metres so adjoining panels share the weave density.
    mapping = nodes.new("ShaderNodeVectorMath")
    mapping.operation = "SCALE"
    mapping.inputs["Scale"].default_value = 0.8
    links.new(coords.outputs["Object"], mapping.inputs[0])
    links.new(mapping.outputs["Vector"], paint.inputs["Vector"])

    tint = nodes.new("ShaderNodeMixRGB")
    tint.label = "Flax tint over dyed cloth"
    tint.blend_type = "SOFT_LIGHT"
    tint.inputs[0].default_value = 0.24
    links.new(previous_color, tint.inputs[1])
    links.new(paint.outputs["Color"], tint.inputs[2])
    links.new(tint.outputs["Color"], bs.inputs["Base Color"])
