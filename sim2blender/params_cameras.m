function c = params_cameras()
%   Параметры виртуальных камер для упрощённой модели реального ОПУ.
%
%   T_WC — переход из СК камеры в лабораторную СК.
%   K    — матрица внутренних параметров.
%   Камера смотрит вдоль локальной -Z, верх +Y.

target = [0; 0; 0.30];   % центр рабочей зоны ОПУ

positions = [ 1.35, -1.15, 1.40;
              1.35,  0.00, 1.45;
              1.35,  1.15, 1.40];

resolution = [2448, 2048];
pixel_mm   = 3.45e-3;        % 3.45 мкм
focal_mm   = 16.0;
fx         = focal_mm / pixel_mm;

K = [fx,  0, resolution(1)/2;
     0,  fx, resolution(2)/2;
     0,   0, 1];

c = struct('name', {}, 'T_WC', {}, 'K', {}, 'resolution', {}, ...
    'dist', {}, 'pixel_mm', {}, 'focal_mm', {});

for i = 1:size(positions,1)
    c(i).name       = sprintf('cam%d', i);
    c(i).T_WC       = look_at(positions(i,:).', target, [0;0;1]);
    c(i).K          = K;
    c(i).resolution = resolution;
    c(i).dist       = [0 0 0 0 0];
    c(i).pixel_mm   = pixel_mm;
    c(i).focal_mm   = focal_mm;
end
end

function T = look_at(pos, target, up)
%   Матрица T_WC: камера смотрит из pos на target, верх up.
z = pos - target;
z = z / norm(z);             % локальная +Z камеры (назад)
x = cross(up, z);

x = x / norm(x);             % локальная +X камеры
y = cross(z, x);             % локальная +Y камеры

T = eye(4);
T(1:3,1:3) = [x, y, z];
T(1:3,4)   = pos;
end
