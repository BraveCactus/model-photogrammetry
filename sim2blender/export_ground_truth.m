function export_ground_truth()
%   Проекции ArUco-углов и 3D-координаты углов маркеров.
%
%   Для каждой камеры создаётся папка ground_truth/camX:
%     projections.csv      — 2D-проекции углов в пикселях;
%     camera_corners.csv   — 3D-координаты углов в СК камеры;
%     world_corners.csv    — 3D-координаты углов в лабораторной СК.
%
%   Дополнительно создаётся ground_truth/summary.txt.
%
%   Использует ground_truth/animation_data.mat, params_markers.m,
%   params_cameras.m.

here = fileparts(mfilename('fullpath'));
gtDir = fullfile(here, 'ground_truth');
if ~isfolder(gtDir)
    mkdir(gtDir);
end
dataFile = fullfile(gtDir, 'animation_data.mat');
if ~isfile(dataFile)
    error('Сначала выполните export_animation: %s', dataFile);
end
S = load(dataFile);
data = S.data;

markers = params_markers();
cameras = params_cameras();

rotorIdx = find(strcmp(data.bodies, 'Rotor'), 1);
if isempty(rotorIdx)
    error('В animation_data нет тела Rotor.');
end

Nt = numel(data.time);
Nm = markers.count;
C = [markers.corner_order.'; ones(1, 4)];   % углы маркера в его СК

summaryFile = fullfile(gtDir, 'summary.txt');
sfid = fopen(summaryFile, 'w', 'n', 'UTF-8');
fprintf(sfid, 'Ground truth summary\n');
fprintf(sfid, 'frames: %d, markers: %d, cameras: %d\n', ...
    Nt, Nm, numel(cameras));
fprintf(sfid, 'camera folders: ground_truth/camX/\n\n');

for ci = 1:numel(cameras)
    cam = cameras(ci);
    K = cam.K;
    T_WC = cam.T_WC;

    camDir = fullfile(gtDir, cam.name);
    if ~isfolder(camDir)
        mkdir(camDir);
    end

    projFile  = fullfile(camDir, 'projections.csv');
    camFile   = fullfile(camDir, 'camera_corners.csv');
    worldFile = fullfile(camDir, 'world_corners.csv');

    fidProj  = fopen(projFile,  'w', 'n', 'UTF-8');
    fidCam   = fopen(camFile,   'w', 'n', 'UTF-8');
    fidWorld = fopen(worldFile, 'w', 'n', 'UTF-8');
    if fidProj < 0 || fidCam < 0 || fidWorld < 0
        error('Не удалось открыть файлы ground truth для %s', cam.name);
    end

    fprintf(fidProj, ['frame,t,camera,marker_id,visible,' ...
        'u0,v0,u1,v1,u2,v2,u3,v3\n']);
    fprintf(fidCam, ['frame,t,camera,marker_id,visible,' ...
        'x0,y0,z0,x1,y1,z1,x2,y2,z2,x3,y3,z3\n']);
    fprintf(fidWorld, ['frame,t,camera,marker_id,visible,' ...
        'x0,y0,z0,x1,y1,z1,x2,y2,z2,x3,y3,z3\n']);

    for n = 1:Nt
        T_WR = data.T(:,:,n,rotorIdx);

        for mi = 1:Nm
            if strcmp(markers.body{mi}, 'Stator')
                continue;
            end

            T_RM = markers.T_RM{mi};

            X_W = T_WR * T_RM * C;      % лабораторные координаты углов
            X_C = T_WC \ X_W;           % координаты углов в СК камеры

            % Проекция в пиксели.
            depth = -X_C(3,:);
            u = K(1,1) * X_C(1,:) ./ depth + K(1,3);
            v = -K(2,2) * X_C(2,:) ./ depth + K(2,3);

            % Пока считаем все маркеры видимыми.
            visible = 1;

            % 2D-проекции углов.
            fprintf(fidProj, '%d,%.9f,%s,%d,%d', ...
                n-1, data.time(n), cam.name, markers.ids(mi), visible);
            fprintf(fidProj, ',%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
                u(1), v(1), u(2), v(2), u(3), v(3), u(4), v(4));

            % 3D-координаты углов в СК камеры.
            fprintf(fidCam, '%d,%.9f,%s,%d,%d', ...
                n-1, data.time(n), cam.name, markers.ids(mi), visible);
            for j = 1:4
                fprintf(fidCam, ',%.9f,%.9f,%.9f', ...
                    X_C(1,j), X_C(2,j), X_C(3,j));
            end
            fprintf(fidCam, '\n');

            % 3D-координаты углов в лабораторной СК.
            fprintf(fidWorld, '%d,%.9f,%s,%d,%d', ...
                n-1, data.time(n), cam.name, markers.ids(mi), visible);
            for j = 1:4
                fprintf(fidWorld, ',%.9f,%.9f,%.9f', ...
                    X_W(1,j), X_W(2,j), X_W(3,j));
            end
            fprintf(fidWorld, '\n');
        end
    end

    fclose(fidProj);
    fclose(fidCam);
    fclose(fidWorld);

    fprintf(sfid, '%s: visible=1 for all markers\n', cam.name);
    fprintf('%s: visible=1 for all markers\n', cam.name);
end

fclose(sfid);
fprintf('Ground truth: %s\n', gtDir);
end
