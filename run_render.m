function run_render(mode)
%   Последовательно запускает экспорт, Blender и сборку видео.
%
%   run_render            % preview: 60 кадров, cam1, 50%
%   run_render('preview') % аналогично строке выше
%   run_render('full')    % все кадры, cam1, 100%

if nargin < 1 || isempty(mode)
    mode = 'preview';
end
mode = lower(char(mode));

BLENDER       = 'D:\Programs\blender\blender.exe';
PROJECT_ROOT  = fileparts(mfilename('fullpath'));
WORKSPACE     = fileparts(PROJECT_ROOT);
SIM_DIR       = fullfile(PROJECT_ROOT, 'sim2blender');
GT_DIR        = fullfile(SIM_DIR, 'ground_truth');
BLEND_DIR     = fullfile(SIM_DIR, 'blends');
OUTPUT_ROOT   = fullfile(WORKSPACE, 'output', 'runs');
LIGHTING_FILE = fullfile(SIM_DIR, 'lighting.json');

if ~isfolder(GT_DIR),    mkdir(GT_DIR);    end
if ~isfolder(BLEND_DIR), mkdir(BLEND_DIR); end
if ~isfolder(OUTPUT_ROOT), mkdir(OUTPUT_ROOT); end

CAMERAS_PREVIEW = {'cam1'};
CAMERAS_FULL    = {'cam1'};

PREVIEW_FRAMES  = 60;
PREVIEW_PERCENT = 50;
FULL_PERCENT    = 100;
FPS             = 30;

addpath(SIM_DIR);

switch mode
    case 'preview'
        cameras = CAMERAS_PREVIEW;
        percent = PREVIEW_PERCENT;
        lastFrame = PREVIEW_FRAMES - 1;
    case 'full'
        cameras = CAMERAS_FULL;
        percent = FULL_PERCENT;
        lastFrame = inf;
    otherwise
        error('Неизвестный режим: %s. Используйте preview или full.', mode);
end

run_id = sprintf('%s_%s', datestr(now, 'yyyymmdd_HHMMSS'), mode);
runDir = fullfile(OUTPUT_ROOT, run_id);
configDir = fullfile(runDir, 'config');
gtRunDir = fullfile(runDir, 'ground_truth');
frameRoot = fullfile(runDir, 'frames');
videoDir  = fullfile(runDir, 'videos');
blendRunDir = fullfile(runDir, 'blender');

if ~isfolder(runDir),      mkdir(runDir);      end
if ~isfolder(configDir),   mkdir(configDir);   end
if ~isfolder(gtRunDir),    mkdir(gtRunDir);    end
if ~isfolder(frameRoot),   mkdir(frameRoot);   end
if ~isfolder(videoDir),    mkdir(videoDir);    end
if ~isfolder(blendRunDir), mkdir(blendRunDir); end

fprintf('=== run_render: %s ===\n', run_id);

% 1. Экспорт сцены, анимации и ground truth
export_all();

% 2. Сцена Blender
sceneFile = fullfile(SIM_DIR, 'scene.json');
blendFile = fullfile(BLEND_DIR, 'opu_scene.blend');
buildScript = fullfile(SIM_DIR, 'blender', 'build_scene.py');

cmd = sprintf(['"%s" --background --python "%s" -- ' ...
    '--scene "%s" --blend "%s" --lighting "%s"'], ...
    BLENDER, buildScript, sceneFile, blendFile, LIGHTING_FILE);
system(cmd);

% 3. Создание анимации
animFile = fullfile(GT_DIR, 'animation.csv');
animBlend = fullfile(BLEND_DIR, 'opu_scene_animated.blend');
makeScript = fullfile(SIM_DIR, 'blender', 'make_animation.py');

cmd = sprintf('"%s" --background --python "%s" -- --blend "%s" --anim "%s" --out "%s"', ...
    BLENDER, makeScript, blendFile, animFile, animBlend);
system(cmd);

copyfile(blendFile, fullfile(blendRunDir, 'opu_scene.blend'));
copyfile(animBlend, fullfile(blendRunDir, 'opu_scene_animated.blend'));

texRunDir = fullfile(runDir, 'textures');
if ~isfolder(texRunDir), mkdir(texRunDir); end
copyfile(fullfile(SIM_DIR, 'textures', '*'), texRunDir);

% 4. Определение последнего кадра из ground_truth/animation.csv
T = readtable(animFile);
maxFrame = max(T.frame);
lastFrame = min(lastFrame, maxFrame);

% 4.1. rotor_angles_true.csv уже создан в export_animation

% 4.2. Снимок конфигурации и ground truth в папку прогона
copyfile(fullfile(GT_DIR, 'animation.csv'), gtRunDir);
copyfile(fullfile(GT_DIR, 'animation_data.mat'), gtRunDir);
copyfile(fullfile(GT_DIR, 'rotor_angles_true.csv'), gtRunDir);
copyfile(fullfile(GT_DIR, 'summary.txt'), gtRunDir);
camRunDir = fullfile(gtRunDir, 'cam1');
if ~isfolder(camRunDir), mkdir(camRunDir); end
copyfile(fullfile(GT_DIR, 'cam1', '*'), camRunDir);

copyfile(sceneFile, fullfile(configDir, 'scene.json'));
copyfile(fullfile(SIM_DIR, 'params_markers.m'), configDir);
copyfile(fullfile(SIM_DIR, 'params_cameras.m'), configDir);
copyfile(fullfile(SIM_DIR, 'scene_definition.m'), configDir);
copyfile(LIGHTING_FILE, configDir);

% 5. Рендер PNG
renderScript = fullfile(SIM_DIR, 'blender', 'render_baked.py');

cmd = sprintf(['"%s" --background --python "%s" -- --blend "%s" ' ...
    '--out "%s" --start 0 --end %d --cameras %s --percent %d'], ...
    BLENDER, renderScript, animBlend, frameRoot, lastFrame, ...
    strjoin(cameras, ','), percent);
system(cmd);

% 6. Сборка MP4
for k = 1:numel(cameras)
    cam = cameras{k};
    camFrameDir = fullfile(frameRoot, cam);
    videoFile = fullfile(videoDir, [cam '.mp4']);
    encode_video(camFrameDir, videoFile, FPS);
    fprintf('Видео: %s\n', videoFile);
end

scene = jsondecode(fileread(sceneFile));
camIdx = find(strcmp({scene.cameras.name}, 'cam1'), 1);
runInfo = struct();
runInfo.run_id = run_id;
runInfo.created_at = datestr(now, 30);
runInfo.status = 'completed';
runInfo.mode = mode;
runInfo.percent = percent;
runInfo.model = 'opu_export';
runInfo.cameras = cameras;
runInfo.frames = lastFrame + 1;
runInfo.fps = scene.render.fps;
runInfo.resolution = scene.cameras(camIdx).resolution;
runInfo.marker_count = numel(scene.markers);
runInfo.lighting = 'lighting.json';

fid = fopen(fullfile(runDir, 'run.json'), 'w');
fprintf(fid, '%s', jsonencode(runInfo, 'PrettyPrint', true));
fclose(fid);

fprintf('Готово: %s\n', runDir);
winopen(runDir);
end

function encode_video(frameDir, videoFile, fps)
files = dir(fullfile(frameDir, 'frame_*.png'));
if isempty(files)
    error('Нет PNG-кадров в %s', frameDir);
end

writer = VideoWriter(videoFile, 'MPEG-4');
writer.FrameRate = fps;
open(writer);
for k = 1:numel(files)
    img = imread(fullfile(frameDir, files(k).name));
    writeVideo(writer, img);
end
close(writer);
end
