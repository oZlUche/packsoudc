"""Executed after the perspective outputs. Orthographic studies use the actual stage scene."""


def render_current_views():
    # A separate camera leaves the painting's independently framed perspective intact.
    data = bpy.data.cameras.new("Survey orthographic")
    survey = bpy.data.objects.new("Survey camera", data)
    scene.collection.objects.link(survey)
    original_camera = scene.camera
    config = scene.render
    original = (
        config.resolution_x,
        config.resolution_y,
        config.resolution_percentage,
        config.film_transparent,
        config.filepath,
        scene.cycles.samples,
    )
    backings = [ob for ob in groups["land"] if ob.name.startswith("远景")]
    hidden = [(ob, ob.hide_render) for ob in backings]
    try:
        for ob, _ in hidden:
            ob.hide_render = True
        scene.camera = survey
        data.type = "ORTHO"
        data.clip_end = 200
        config.resolution_x, config.resolution_y = 960, 540
        config.resolution_percentage = 100
        config.film_transparent = False
        scene.cycles.samples = 2
        # All three drawings share the modeled road surface and Z=0 datum.
        views = [
            ("top", (0, 2, 65), (0, 2, 0), 55.0),
            ("front", (0, -65, 3.1), (0, 2, 3.1), 54.5),
            ("side", (65, 2, 3.1), (0, 2, 3.1), 31.0),
        ]
        for name, eye, target, width in views:
            survey.location = eye
            if name == "top":
                survey.rotation_euler = (0, 0, 0)
            else:
                point(survey, target)
            data.ortho_scale = width
            render(out / f"{STAGE:02d}-ortho-{name}.png")
    finally:
        scene.camera = original_camera
        for ob, state in hidden:
            ob.hide_render = state
        (
            config.resolution_x,
            config.resolution_y,
            config.resolution_percentage,
            config.film_transparent,
            config.filepath,
            scene.cycles.samples,
        ) = original
        bpy.data.objects.remove(survey, do_unlink=True)
        bpy.data.cameras.remove(data)


if STAGE in (5, 6, 7, 8):
    render_current_views()
