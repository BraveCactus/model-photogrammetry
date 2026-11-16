function m = params_markers()
%   ArUco-маркеры на верхней площадке реального ОПУ.
%
%   6 маркеров DICT_4X4_50:
%     id 0..3 - плашмя на верхней плоскости площадки, нормаль +Z;
%     id 4    - на торце +Y, нормаль +Y;
%     id 5    - на торце -Y, нормаль -Y.
%
%   Маркеры заданы в СК тела Rotor. Начало СК — центр площадки.
%   Плоскость маркера — локальная XY, нормаль +Z.

m.dictionary = 'DICT_4X4_50';
m.ids = 0:5;
m.count = numel(m.ids);

m.size = 0.03;          % сторона чёрного ArUco-маркера, м
m.margin = 0.20;        % белая полоса с каждой стороны, доля от size
m.plane_size = m.size * (1 + 2*m.margin);
m.body = 'Rotor';

% Верхняя площадка: 0.34 x 0.40 x 0.05 м (X — глубина, Y — длинная сторона).
m.top_z = 0.025;        % верхняя грань в СК Rotor
m.side_y = 0.20;        % боковые торцы вдоль длинной стороны
m.z_offset = 0.0002;

% Порядок углов: top-left, top-right, bottom-right, bottom-left.
m.corner_order = [-1 1; 1 1; 1 -1; -1 -1] * (m.size/2);
m.corner_order(:,3) = 0;

% Для плоскости Blender — углы с учётом белой рамки.
m.plane_corners = [-1 1; 1 1; 1 -1; -1 -1] * (m.plane_size/2);
m.plane_corners(:,3) = 0;

m.textureDir = 'textures';
m.texture_px = 512;
m.margin_px = round(m.margin * m.texture_px);
m.T_BM = cell(1, m.count);
m.texture = cell(1, m.count);

% 4 маркера на верхней плоскости.
top_xy = [-0.085 -0.09;
           0.085 -0.09;
           0.085  0.09;
          -0.085  0.09];

for k = 1:4
    T = eye(4);
    T(1:3,4) = [top_xy(k,1); top_xy(k,2); m.top_z + m.z_offset];
    m.T_BM{k} = T;
    m.texture{k} = sprintf('%s/aruco_%02d.png', m.textureDir, m.ids(k));
end

% +Y торец: нормаль +Y, локальный +Y маркера направлен вверх (+Z).
T = eye(4);
T(1:3,1:3) = rotx(-90) * rotz(180);
T(1:3,4) = [0; m.side_y + m.z_offset; 0];
m.T_BM{5} = T;
m.texture{5} = sprintf('%s/aruco_%02d.png', m.textureDir, m.ids(5));

% -Y торец: нормаль -Y, локальный +Y маркера направлен вверх (+Z).
T = eye(4);
T(1:3,1:3) = rotx(90);
T(1:3,4) = [0; -m.side_y - m.z_offset; 0];
m.T_BM{6} = T;
m.texture{6} = sprintf('%s/aruco_%02d.png', m.textureDir, m.ids(6));
end

function R = rotx(a)
R = [1 0 0; 0 cosd(a) -sind(a); 0 sind(a) cosd(a)];
end

function R = rotz(a)
R = [cosd(a) -sind(a) 0; sind(a) cosd(a) 0; 0 0 1];
end
