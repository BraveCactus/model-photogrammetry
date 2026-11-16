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
PROJECT_ROOT  = 'D:\My\Projects\diplom\photogram\model\photo_opu';
SIM_DIR       = fullfile(PROJECT_ROOT, 'sim2blender');
GT_DIR        = fullfile(SIM_DIR, 'ground_truth');
BLEND_DIR     = fullfile(SIM_DIR, 'blends');
OUTPUT_DIR    = fullfile(PROJECT_ROOT, 'output');

if ~isfolder(GT_DIR),    mkdir(GT_DIR);    end
if ~isfolder(BLEND_DIR), mkdir(BLEND_DIR); end

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
frameRoot = fullfile(OUTPUT_DIR, 'frames', run_id);
videoDir  = fullfile(OUTPUT_DIR, 'videos', run_id);
if ~isfolder(frameRoot), mkdir(frameRoot); end
if ~isfolder(videoDir),  mkdir(videoDir); end

fprintf('=== run_render: %s ===\n', run_id);

% 1. Экспорт сцены, анимации и ground truth
export_all();

% 2. Сцена Blender
sceneFile = fullfile(SIM_DIR, 'scene.json');
blendFile = fullfile(BLEND_DIR, 'opu_scene.blend');
buildScript = fullfile(SIM_DIR, 'blender', 'build_scene.py');

cmd = sprintf('"%s" --background --python "%s" -- --scene "%s" --blend "%s"', ...
    BLENDER, buildScript, sceneFile, blendFile);
system(cmd);

% 3. Создание анимации
animFile = fullfile(GT_DIR, 'animation.csv');
animBlend = fullfile(BLEND_DIR, 'opu_scene_animated.blend');
makeScript = fullfile(SIM_DIR, 'blender', 'make_animation.py');

cmd = sprintf('"%s" --background --python "%s" -- --blend "%s" --anim "%s" --out "%s"', ...
    BLENDER, makeScript, blendFile, animFile, animBlend);
system(cmd);

% 4. Определение последнего кадра из ground_truth/animation.csv
T = readtable(animFile);
maxFrame = max(T.frame);
lastFrame = min(lastFrame, maxFrame);

% 4.1. Идеальные углы ротора
anglesFile = fullfile(GT_DIR, 'rotor_angles_true.csv');
export_rotor_angles(T, anglesFile);

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

fprintf('Готово: %s\n', videoDir);
winopen(videoDir);
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
