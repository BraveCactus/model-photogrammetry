import bpy
import csv
import os
import sys
from mathutils import Matrix


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    args = {
        "blend": "blends/opu_scene.blend",
        "anim": "ground_truth/animation.csv",
        "out": "renders",
        "frames": "0",
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


def parse_frames(value):
    return [int(x) for x in value.split(",") if x.strip() != ""]


def load_animation(path):
    frames = {}
    with open(path, "r", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            frame = int(row["frame"])
            body = row["body"]
            matrix = Matrix(
                [[float(row[f"m{i}{j}"]) for j in range(4)] for i in range(4)]
            )
            frames.setdefault(frame, {})[body] = matrix
    return frames


def main():
    args = parse_args()
    blend_path = os.path.abspath(args["blend"])
    anim_path = os.path.abspath(args["anim"])
    out_dir = os.path.abspath(args["out"])
    frames_to_render = parse_frames(args["frames"])
    camera_filter = [c.strip() for c in args["cameras"].split(",") if c.strip()]

    bpy.ops.wm.open_mainfile(filepath=blend_path)
    scene = bpy.context.scene
    data = load_animation(anim_path)

    cameras = sorted(
        [o for o in bpy.data.objects if o.type == "CAMERA"],
        key=lambda o: o.name,
    )
    if camera_filter:
        cameras = [c for c in cameras if c.name in camera_filter]
    if not cameras:
        raise RuntimeError("No cameras found")

    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"

    for frame in frames_to_render:
        if frame not in data:
            raise KeyError(f"Frame {frame} not in animation")
        for body, matrix in data[frame].items():
            obj = bpy.data.objects.get(body)
            if obj is None:
                raise KeyError(f"Object {body} not in Blender scene")
            obj.matrix_world = matrix

        bpy.context.view_layer.update()

        for cam in cameras:
            scene.camera = cam
            scene.render.resolution_x = int(cam.get("res_x", 2448))
            scene.render.resolution_y = int(cam.get("res_y", 2048))
            cam_dir = os.path.join(out_dir, cam.name)
            os.makedirs(cam_dir, exist_ok=True)
            out_file = os.path.join(cam_dir, f"frame_{frame:04d}.png")
            scene.render.filepath = out_file
            bpy.ops.render.render(write_still=True)
            print(f"RENDERED {out_file}")

    print("RENDER_OK")


if __name__ == "__main__":
    main()
