import bpy
import os
import sys


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    args = {
        "blend": "blends/opu_scene_animated.blend",
        "out": "renders_baked",
        "start": "0",
        "end": "0",
        "step": "1",
        "percent": "100",
        "cameras": "",
    }
    i = 0
    while i < len(argv):
        key = argv[i].lstrip("-")
        if key in args and i + 1 < len(argv):
            args[key] = argv[i + 1]
            i += 2
        else:
            i += 1
    return args


def main():
    args = parse_args()
    blend = os.path.abspath(args["blend"])
    out_dir = os.path.abspath(args["out"])
    start = int(args["start"])
    end = int(args["end"])
    step = int(args["step"])
    percent = int(args["percent"])
    camera_filter = [c.strip() for c in args["cameras"].split(",") if c.strip()]

    bpy.ops.wm.open_mainfile(filepath=blend)
    scene = bpy.context.scene
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.resolution_percentage = percent
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"

    cameras = sorted([o for o in bpy.data.objects if o.type == "CAMERA"],
                     key=lambda o: o.name)
    if camera_filter:
        cameras = [c for c in cameras if c.name in camera_filter]
    if not cameras:
        raise RuntimeError("No cameras")

    for frame in range(start, end + 1, step):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        for cam in cameras:
            scene.camera = cam
            scene.render.resolution_x = int(cam.get("res_x", 2448))
            scene.render.resolution_y = int(cam.get("res_y", 2048))
            cam_dir = os.path.join(out_dir, cam.name)
            os.makedirs(cam_dir, exist_ok=True)
            path = os.path.join(cam_dir, f"frame_{frame:04d}.png")
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            print(f"RENDERED {path}")

    print("RENDER_BAKED_OK")


if __name__ == "__main__":
    main()
