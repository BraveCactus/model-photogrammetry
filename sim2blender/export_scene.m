function export_scene()
%   Экспорт scene.json для Blender.
%
%   Источник: params_markers.m и params_cameras.m.
%   Результат: scene.json в папке sim2blender.

here = fileparts(mfilename('fullpath'));
scene = scene_definition();

outFile = fullfile(here, 'scene.json');
json = jsonencode(scene, 'PrettyPrint', true);

fid = fopen(outFile, 'w', 'n', 'UTF-8');
if fid < 0
    error('Не удалось открыть %s', outFile);
end
fprintf(fid, '%s', json);
fclose(fid);

fprintf('Записано: %s\n', outFile);
fprintf('  тел: %d\n', numel(scene.bodies));
fprintf('  маркеров: %d\n', numel(scene.markers));
fprintf('  камер: %d\n', numel(scene.cameras));
for i = 1:numel(scene.cameras)
    fprintf('    %s: pos=[%.3f %.3f %.3f]\n', scene.cameras(i).name, ...
        scene.cameras(i).T_WC(1,4), scene.cameras(i).T_WC(2,4), ...
        scene.cameras(i).T_WC(3,4));
end
end
