function scene = scene_definition()
%   Описание упрощённой сцены реального ОПУ для Blender.
%
%   Тела соответствуют четырём телам Simscape-модели:
%     Stator   - нижний цилиндрический стол;
%     RightCol - боковая стойка +Y;
%     LeftCol  - боковая стойка -Y;
%     Rotor    - верхняя поворотная площадка.

m = params_markers();
c = params_cameras();

bodies = struct('name', {}, 'shape', {}, 'radius', {}, ...
    'length', {}, 'dimensions', {}, 'color', {});

bodies(1) = struct('name', 'Stator', 'shape', 'cylinder', ...
    'radius', 0.16, 'length', 0.10, 'dimensions', [], ...
    'color', [0.14 0.15 0.17]);
bodies(2) = struct('name', 'RightCol', 'shape', 'brick', ...
    'radius', [], 'length', [], 'dimensions', [0.16 0.03 0.30], ...
    'color', [0.32 0.35 0.39]);
bodies(3) = struct('name', 'LeftCol', 'shape', 'brick', ...
    'radius', [], 'length', [], 'dimensions', [0.16 0.03 0.30], ...
    'color', [0.32 0.35 0.39]);
bodies(4) = struct('name', 'Rotor', 'shape', 'brick', ...
    'radius', [], 'length', [], 'dimensions', [0.34 0.40 0.05], ...
    'color', [0.22 0.23 0.25]);

markers = struct('id', {}, 'body', {}, 'size', {}, 'plane_size', {}, ...
    'T_BM', {}, 'texture', {}, 'corners_local', {}, ...
    'plane_corners_local', {});

for k = 1:m.count
    markers(k).id = m.ids(k);
    markers(k).body = m.body;
    markers(k).size = m.size;
    markers(k).plane_size = m.plane_size;
    markers(k).T_BM = m.T_BM{k};
    markers(k).texture = m.texture{k};
    markers(k).corners_local = m.corner_order;
    markers(k).plane_corners_local = m.plane_corners;
end

cameras = struct('name', {}, 'resolution', {}, 'K', {}, ...
    'dist', {}, 'T_WC', {});
for i = 1:numel(c)
    cameras(i).name = c(i).name;
    cameras(i).resolution = c(i).resolution;
    cameras(i).K = c(i).K;
    cameras(i).dist = c(i).dist;
    cameras(i).T_WC = c(i).T_WC;
end

scene = struct();
scene.schema = 'opu-model/1';
scene.name = 'opu_v1';
scene.units = 'm';
scene.dictionary = m.dictionary;
scene.bodies = bodies;
scene.markers = markers;
scene.cameras = cameras;
scene.render = struct( ...
    'engine', 'BLENDER_EEVEE', ...
    'fps', 30, ...
    'resolution_percentage', 100, ...
    'file_format', 'PNG');
end
