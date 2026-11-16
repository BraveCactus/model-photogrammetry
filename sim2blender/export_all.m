function export_all()
%   Полный экспорт Simscape: scene.json + ground_truth/animation.csv +
%   ground_truth/camX.

fprintf('=== 1. scene.json ===\n');
export_scene();

fprintf('\n=== 2. ground_truth/animation.csv ===\n');
export_animation();

fprintf('\n=== 3. ground truth ===\n');
export_ground_truth();

fprintf('\nЭкспорт завершён.\n');
end
