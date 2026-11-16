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
        "out": "blends/opu_scene_animated.blend",
        "camera": "cam1",
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


def load_animation(path):
    frames = {}
    with open(path, "r", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            frame = int(row["frame"])
            body = row["body"]
            mat = Matrix(
                [[float(row[f"m{i}{j}"]) for j in range(4)] for i in range(4)]
            )
            frames.setdefault(frame, {})[body] = mat
    return frames


def linearize(obj):
    ad = obj.animation_data
    if not ad or not ad.action:
        return
    action = ad.action
    fcurves = []
    try:
        fcurves = list(action.fcurves)
    except Exception:
        try:
            for layer in action.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        fcurves.extend(bag.fcurves)
        except Exception:
            pass
    for fc in fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"


def main():
    args = parse_args()
    blend = os.path.abspath(args["blend"])
    anim = os.path.abspath(args["anim"])
    out = os.path.abspath(args["out"])

    bpy.ops.wm.open_mainfile(filepath=blend)
    scene = bpy.context.scene
    data = load_animation(anim)
    frame_ids = sorted(data.keys())
    bodies = sorted(data[frame_ids[0]].keys())

    for body in bodies:
        obj = bpy.data.objects.get(body)
        if obj is None:
            raise KeyError(f"Object {body} not found")
        obj.rotation_mode = "QUATERNION"

        for frame in frame_ids:
            mat = data[frame][body]
            obj.location = mat.to_translation()
            obj.rotation_quaternion = mat.to_quaternion()
            obj.keyframe_insert(data_path="location", frame=frame)
            obj.keyframe_insert(data_path="rotation_quaternion", frame=frame)

        linearize(obj)

    scene.frame_start = frame_ids[0]
    scene.frame_end = frame_ids[-1]
    scene.render.fps = 30
    scene.frame_set(frame_ids[0])

    cam = bpy.data.objects.get(args["camera"])
    if cam is not None:
        scene.camera = cam

    bpy.context.view_layer.update()
    for body in bodies:
        obj = bpy.data.objects[body]
        p = obj.matrix_world.translation
        print(f"FRAME0 {body} [{p.x:.4f} {p.y:.4f} {p.z:.4f}]")

    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out)
    print(f"BAKED={out}")
    print(f"FRAMES={frame_ids[0]}..{frame_ids[-1]} BODIES={len(bodies)}")


if __name__ == "__main__":
    main()
