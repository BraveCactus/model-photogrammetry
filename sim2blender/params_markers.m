function m = params_markers()
%   ArUco-маркеры ОПУ.
%
%   5 маркеров на роторе:
%     id 0 — верхняя грань, нормаль +Z;
%     id 1 — грань +X, нормаль +X;
%     id 2 — грань -X, нормаль -X;
%     id 3 — грань +Y, нормаль +Y;
%     id 4 — грань -Y, нормаль -Y.
%
%   1 маркер на статоре:
%     id 5 — боковая поверхность +X, нормаль +X.
%
%   Плоскость маркера — локальная XY, нормаль +Z.
%   T_RM — маркер -> ротор, T_SM — маркер -> статор.

m.dictionary = 'DICT_4X4_50';
m.ids = 0:5;
m.count = numel(m.ids);

m.size = 0.03;
m.margin = 0.20;
m.plane_size = m.size * (1 + 2*m.margin);

m.body = { ...
    'Rotor', 'Rotor', 'Rotor', 'Rotor', 'Rotor', 'Stator'};

m.top_z = 0.025;
m.side_x = 0.17;
m.side_y = 0.20;
m.stator_radius = 0.16;
m.stator_z = 0.0;
m.z_offset = 0.0002;

m.corner_order = [-1 1; 1 1; 1 -1; -1 -1] * (m.size/2);
m.corner_order(:,3) = 0;

m.plane_corners = [-1 1; 1 1; 1 -1; -1 -1] * (m.plane_size/2);
m.plane_corners(:,3) = 0;

m.textureDir = 'textures';
m.texture_px = 512;
m.margin_px = round(m.margin * m.texture_px);
m.T_RM = cell(1, m.count);
m.T_SM = cell(1, m.count);
m.texture = cell(1, m.count);

% Верхняя грань ротора.
T = eye(4);
T(1:3,4) = [0; 0; m.top_z + m.z_offset];
m.T_RM{1} = T;

% Грань +X ротора.
T = eye(4);
T(1:3,1:3) = [0 0 1; 1 0 0; 0 1 0];
T(1:3,4) = [m.side_x + m.z_offset; 0; 0];
m.T_RM{2} = T;

% Грань -X ротора.
T = eye(4);
T(1:3,1:3) = [0 0 -1; -1 0 0; 0 1 0];
T(1:3,4) = [-m.side_x - m.z_offset; 0; 0];
m.T_RM{3} = T;

% Грань +Y ротора.
T = eye(4);
T(1:3,1:3) = [-1 0 0; 0 0 1; 0 1 0];
T(1:3,4) = [0; m.side_y + m.z_offset; 0];
m.T_RM{4} = T;

% Грань -Y ротора.
T = eye(4);
T(1:3,1:3) = [1 0 0; 0 0 -1; 0 1 0];
T(1:3,4) = [0; -m.side_y - m.z_offset; 0];
m.T_RM{5} = T;

% Маркер на боковой поверхности статора +X.
T = eye(4);
T(1:3,1:3) = [0 0 1; 1 0 0; 0 1 0];
T(1:3,4) = [m.stator_radius + m.z_offset; 0; m.stator_z];
m.T_SM{6} = T;

for k = 1:m.count
    m.texture{k} = sprintf('%s/aruco_%02d.png', m.textureDir, m.ids(k));
end
end
