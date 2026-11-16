function export_rotor_angles(T, outFile)
%   Расчёт идеальных азимута и угла места ротора из
%   ground_truth/animation.csv.
%
%   Вход:
%     T       — таблица ground_truth/animation.csv
%     outFile — путь к выходному CSV
%
%   Результат:
%     ground_truth/rotor_angles_true.csv —
%       frame,t,phi_rad,theta_rad,phi_deg,theta_deg

rotor = T(strcmp(T.body, 'Rotor'), :);
stator = T(strcmp(T.body, 'Stator'), :);

n = numel(rotor.frame);
phi = zeros(n, 1);
theta = zeros(n, 1);

for k = 1:n
    Rr = [rotor.m00(k) rotor.m01(k) rotor.m02(k);
          rotor.m10(k) rotor.m11(k) rotor.m12(k);
          rotor.m20(k) rotor.m21(k) rotor.m22(k)];

    Rs = [stator.m00(k) stator.m01(k) stator.m02(k);
          stator.m10(k) stator.m11(k) stator.m12(k);
          stator.m20(k) stator.m21(k) stator.m22(k)];

    R = Rs' * Rr;

    phi(k) = atan2(-R(1,2), R(2,2));
    theta(k) = atan2(R(3,1), R(3,3));
end

out = table(rotor.frame, rotor.t, phi, theta, ...
    rad2deg(phi), rad2deg(theta), ...
    'VariableNames', {'frame', 't', 'phi_rad', 'theta_rad', ...
    'phi_deg', 'theta_deg'});

writetable(out, outFile);
fprintf('Записано: %s\n', outFile);
end
