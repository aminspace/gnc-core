% export_for_report.m
% Exports simulation results for the weekly engineering report.
% Works in MATLAB (R2019b or later) and GNU Octave (7 or later).
%
% Demo version: generates SYNTHETIC Monte Carlo data for the
% kst_nav_closed_loop_v4 run. In production, replace the "Results"
% section with the real outputs of your simulation.
%
% Output folder (upload to gnc-core/results/ on GitHub):
%   results/kst_nav_closed_loop_v4/
%     results.json
%     fig1_delta_v_dispersion.png
%     fig2_terminal_miss_distance.png

clear; close all;

%% Run metadata
run_id     = 'kst_nav_closed_loop_v4';
ticket     = 'KST-1';
model_ref  = 'HX_KST01_DDJ_0009';
req_ref    = 'HX_KST01_SPC_0001';
run_date   = '2026-11-25';
n_samples  = 500;
dv_limit   = 2.50;   % m/s, L2 delta-v budget for terminal approach
miss_limit = 0.10;   % m, L2 terminal position accuracy (3-sigma)

out_dir = fullfile('results', run_id);
if ~exist(out_dir, 'dir'); mkdir(out_dir); end

%% Results (synthetic, seeded so every run is identical)
rand('seed', 42); randn('seed', 42);           % Octave
try, rng(42); catch, end                       % MATLAB
dv   = 2.05 + 0.09 * randn(n_samples, 1);      % m/s
miss = abs(0.028 * randn(n_samples, 1) + 0.012 * randn(n_samples, 1)); % m

dv_mean   = mean(dv);
dv_3sig   = dv_mean + 3 * std(dv);
miss_3sig = mean(miss) + 3 * std(miss);
dv_pass   = all(dv <= dv_limit);
miss_pass = miss_3sig <= miss_limit;

%% Figure 1: delta-v dispersion
f1 = figure('Visible', 'off', 'Position', [100 100 800 500]);
hist(dv, 30); hold on;
yl = ylim;
plot([dv_limit dv_limit], yl, 'r--', 'LineWidth', 2);
plot([dv_3sig dv_3sig], yl, 'k:', 'LineWidth', 2);
xlabel('Terminal approach \Delta v (m/s)');
ylabel('Samples');
title(sprintf('Monte Carlo \\Delta v dispersion (N = %d)', n_samples));
legend('Samples', 'L2 limit', '3\sigma', 'Location', 'northwest');
grid on;
fig1 = 'fig1_delta_v_dispersion.png';
print(f1, fullfile(out_dir, fig1), '-dpng', '-r150');

%% Figure 2: terminal miss distance
f2 = figure('Visible', 'off', 'Position', [100 100 800 500]);
plot(1:n_samples, miss * 100, '.', 'MarkerSize', 8); hold on;
plot([1 n_samples], [miss_limit miss_limit] * 100, 'r--', 'LineWidth', 2);
xlabel('Monte Carlo sample');
ylabel('Terminal miss distance (cm)');
ylim([0 miss_limit * 100 * 1.25]);
title('Terminal position error per sample');
legend('Samples', 'L2 limit (3\sigma)', 'Location', 'northeast');
grid on;
fig2 = 'fig2_terminal_miss_distance.png';
print(f2, fullfile(out_dir, fig2), '-dpng', '-r150');

%% results.json
rnd = @(x, n) round(x * 10^n) / 10^n;   % works in MATLAB and Octave
r.run_id       = run_id;
r.model        = [run_id '.slx'];
r.ticket       = ticket;
r.date         = run_date;
r.samples      = n_samples;
r.references   = {model_ref, req_ref};
r.changes      = {'Added pulse-width thruster model', 'Re-tuned cross-track gains'};
r.metrics(1).name = 'Delta-v mean';          r.metrics(1).value = rnd(dv_mean, 3);   r.metrics(1).unit = 'm/s'; r.metrics(1).limit = dv_limit;   r.metrics(1).pass = dv_pass;
r.metrics(2).name = 'Delta-v 3-sigma';       r.metrics(2).value = rnd(dv_3sig, 3);   r.metrics(2).unit = 'm/s'; r.metrics(2).limit = dv_limit;   r.metrics(2).pass = dv_3sig <= dv_limit;
r.metrics(3).name = 'Miss distance 3-sigma'; r.metrics(3).value = rnd(miss_3sig, 4); r.metrics(3).unit = 'm';   r.metrics(3).limit = miss_limit; r.metrics(3).pass = miss_pass;
r.figures(1).file = fig1;
r.figures(1).caption = sprintf('Terminal approach delta-v dispersion, %d-sample Monte Carlo, against L2 limit (%s)', n_samples, req_ref);
r.figures(2).file = fig2;
r.figures(2).caption = sprintf('Terminal miss distance per sample against L2 3-sigma limit (%s)', req_ref);
r.status = 'Pending review';

fid = fopen(fullfile(out_dir, 'results.json'), 'w');
fprintf(fid, '%s', jsonencode(r));
fclose(fid);

fprintf('Exported to %s\n', out_dir);
