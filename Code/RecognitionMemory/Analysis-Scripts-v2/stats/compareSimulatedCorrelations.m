function compareSimulatedCorrelations(x, y, label1, label2, useCorrected)
    if nargin < 5, useCorrected = false; end

    field = ternary(useCorrected, 'sim_r_corr', 'sim_r_raw');

    n = min(numel(x.(field)), numel(y.(field)));
    r1 = x.(field)(1:n);
    r2 = y.(field)(1:n);
    diffDist = r1 - r2;

    p_val = 2 * min(mean(diffDist > 0, 'omitnan'), mean(diffDist < 0, 'omitnan'));
    ci_diff = prctile(diffDist, [2.5 97.5]);
    mean_diff = mean(diffDist, 'omitnan');
    sem_diff = std(diffDist, 'omitnan');

    fprintf('%s vs %s (%s) | Mean diff = %.3f | SEM = %.3f | 95%% CI = [%.3f, %.3f] | p = %.4f\n', ...
        label1, label2, field, mean_diff, sem_diff, ci_diff(1), ci_diff(2), p_val);
end 