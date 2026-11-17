import bpy
import json
import os
import sys
from mathutils import Matrix, Vector


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    args = {
        "scene": "scene.json",
        "blend": "blends/opu_scene.blend",
        "lighting": "lighting.json",
    }
    i = 0
    while i < len(argv):
        if argv[i] == "--scene":
            args["scene"] = argv[i + 1]
            i += 2
        elif argv[i] == "--blend":
            args["blend"] = argv[i + 1]
            i += 2
        elif argv[i] == "--lighting":
            args["lighting"] = argv[i + 1]
            i += 2
        else:
            i += 1
    return args


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_empty(name):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.2
    bpy.context.scene.collection.objects.link(obj)
    return obj


def make_material(name, color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.65
    return mat


def make_texture_material(name, image_path):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.8

    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(image_path)
    tex.interpolation = "Closest"
    tex.extension = "EXTEND"

    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def add_body_mesh(body):
    name = body["name"]
    empty = make_empty(name)

    if body["shape"] == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=64,
            radius=body["radius"],
            depth=body["length"],
            location=(0, 0, 0),
        )
        mesh = bpy.context.object
    elif body["shape"] == "brick":
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
        mesh = bpy.context.object
        mesh.scale = body["dimensions"]
        bpy.context.view_layer.objects.active = mesh
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    else:
        raise ValueError(f"Unknown shape: {body['shape']}")

    mesh.name = f"{name}_mesh"
    mesh.parent = empty
    mesh.matrix_parent_inverse = empty.matrix_world.inverted()
    mesh.matrix_world = Matrix.Identity(4)

    mat = make_material(f"{name}_mat", body["color"])
    mesh.data.materials.append(mat)
    return empty


def add_marker(marker, parent_empty, scene_dir):
    size = marker["plane_size"]
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    obj = bpy.context.object
    obj.name = f"Marker_{marker['id']:02d}"

    transform = (
        marker["T_RM"]
        if marker["body"] == "Rotor"
        else marker["T_SM"]
    )

    obj.parent = parent_empty
    obj.matrix_parent_inverse = parent_empty.matrix_world.inverted()
    obj.matrix_world = Matrix(transform)

    texture = os.path.join(scene_dir, marker["texture"])
    if not os.path.isfile(texture):
        raise FileNotFoundError(texture)
    mat = make_texture_material(f"ArUco_{marker['id']:02d}", texture)
    obj.data.materials.append(mat)
    return obj


def add_camera(cam):
    data = bpy.data.cameras.new(cam["name"])
    data.display_size = 0.25  # размер пиктограммы камеры в 4 раза меньше стандартного
    obj = bpy.data.objects.new(cam["name"], data)
    bpy.context.scene.collection.objects.link(obj)

    obj.matrix_world = Matrix(cam["T_WC"])
    width = cam["resolution"][0]
    fx = cam["K"][0][0]
    sensor_width = 36.0
    data.sensor_width = sensor_width
    data.sensor_fit = "HORIZONTAL"
    data.lens = fx * sensor_width / width
    data.shift_x = 0.0
    data.shift_y = 0.0
    obj["res_x"] = cam["resolution"][0]
    obj["res_y"] = cam["resolution"][1]
    return obj


def add_lights(spec):
    for item in spec["lights"]:
        bpy.ops.object.light_add(type="AREA", location=item["location"])
        light = bpy.context.object
        light.name = item["name"]
        light.data.energy = item["energy"]
        light.data.size = item["size"]
        direction = Vector((0.0, 0.0, 0.0)) - light.location
        light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        bpy.context.scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = tuple(spec["world"]["color"])
    bg.inputs["Strength"].default_value = spec["world"]["strength"]


def setup_render(scene):
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.resolution_percentage = 100
    scene.render.fps = 30
    scene.view_settings.view_transform = "Standard"
    try:
        scene.eevee.taa_render_samples = 32
    except Exception:
        pass


def main():
    args = parse_args()
    scene_path = os.path.abspath(args["scene"])
    blend_path = os.path.abspath(args["blend"])
    lighting_path = os.path.abspath(args["lighting"])
    scene_dir = os.path.dirname(scene_path)

    with open(scene_path, "r", encoding="utf-8") as f:
        spec = json.load(f)
    with open(lighting_path, "r", encoding="utf-8") as f:
        lighting = json.load(f)

    clear_scene()
    scene = bpy.context.scene
    setup_render(scene)

    body_empties = {}
    for body in spec["bodies"]:
        body_empties[body["name"]] = add_body_mesh(body)

    for marker in spec["markers"]:
        parent = body_empties[marker["body"]]
        add_marker(marker, parent, scene_dir)

    for cam in spec["cameras"]:
        add_camera(cam)

    add_lights(lighting)

    for name, empty in body_empties.items():
        empty.matrix_world = Matrix.Identity(4)

    os.makedirs(os.path.dirname(blend_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"SCENE_OK bodies={len(spec['bodies'])} markers={len(spec['markers'])} cameras={len(spec['cameras'])}")
    print(f"BLEND={blend_path}")


if __name__ == "__main__":
    main()
