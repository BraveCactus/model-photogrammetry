function data = export_animation()
%   Экспорт положений тел из opu_export.slx.
%
%   Результаты:
%     ground_truth/animation.csv      — frame,t,body,4x4 матрица
%     ground_truth/animation_data.mat — те же данные для ground truth

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
gtDir = fullfile(here, 'ground_truth');
if ~isfolder(gtDir)
    mkdir(gtDir);
end
mdl = 'opu_export';
modelFile = fullfile(root, [mdl '.slx']);

load_system(modelFile);

out = sim(mdl);

bodies = {'Stator', 'RightCol', 'LeftCol', 'Rotor'};
t = out.Rotor_p.Time;
Nt = numel(t);

data = struct();
data.time = t;
data.bodies = bodies;
data.T = zeros(4, 4, Nt, numel(bodies));

csvFile = fullfile(gtDir, 'animation.csv');
fid = fopen(csvFile, 'w', 'n', 'UTF-8');
if fid < 0
    error('Не удалось открыть %s', csvFile);
end

names = cell(1, 16);
idx = 1;
for ii = 0:3
    for jj = 0:3
        names{idx} = sprintf('m%d%d', ii, jj);
        idx = idx + 1;
    end
end
fprintf(fid, 'frame,t,body,%s\n', strjoin(names, ','));

for k = 1:numel(bodies)
    body = bodies{k};
    p = out.([body '_p']);
    R = out.([body '_R']);

    P = reshape(p.Data, 3, Nt);
    R3 = reshape(R.Data, 3, 3, Nt);

    for n = 1:Nt
        T = eye(4);
        T(1:3,1:3) = R3(:,:,n);
        T(1:3,4)   = P(:,n);
        data.T(:,:,n,k) = T;

        fprintf(fid, '%d,%.9f,%s', n-1, t(n), body);
        for ii = 1:4
            for jj = 1:4
                fprintf(fid, ',%.12g', T(ii,jj));
            end
        end
        fprintf(fid, '\n');
    end
end

fclose(fid);
save(fullfile(gtDir, 'animation_data.mat'), 'data');

fprintf('Записано: %s\n', csvFile);
fprintf('  кадров: %d\n', Nt);
fprintf('  тел: %d\n', numel(bodies));
fprintf('  строк: %d\n', Nt*numel(bodies));
for k = 1:numel(bodies)
    T0 = data.T(:,:,1,k);
    fprintf('  %-8s t0 p=[%.4f %.4f %.4f]\n', bodies{k}, ...
        T0(1,4), T0(2,4), T0(3,4));
end
end
