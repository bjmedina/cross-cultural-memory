function [lo, hi] = ciBCa(r_hat, r_boot, jackknife_vals, alpha)
% ciBCa
%   Bias-corrected and accelerated (BCa) confidence interval for a
%   correlation. See STATS.md §4.4 for the formulas.
%
%   [lo, hi] = ciBCa(r_hat, r_boot, jackknife_vals, alpha)
%
%   r_hat          : sample point estimate
%   r_boot         : vector of bootstrap correlations
%   jackknife_vals : vector of leave-one-out correlations at the SAME
%                    resampling level as r_boot (participants for
%                    participant bootstrap, stimuli for stimulus
%                    bootstrap). Used for the acceleration term only.
%   alpha          : 1 - confidence level (default 0.05)
%
%   If jackknife_vals is empty or constant the acceleration is set to 0 and
%   BCa reduces to a bias-corrected percentile interval.

    if nargin < 4, alpha = 0.05; end
    if ~isfinite(r_hat)
        lo = NaN; hi = NaN; return
    end
    r_boot = r_boot(isfinite(r_boot));
    if numel(r_boot) < 2
        lo = NaN; hi = NaN; return
    end

    % Bias correction z0
    frac_below = mean(r_boot < r_hat);
    frac_below = min(max(frac_below, 1/(2*numel(r_boot))), 1 - 1/(2*numel(r_boot)));
    z0 = norminv(frac_below);

    % Acceleration a from jackknife
    if isempty(jackknife_vals)
        a = 0;
    else
        jk = jackknife_vals(isfinite(jackknife_vals));
        if numel(jk) < 3
            a = 0;
        else
            jk_mean = mean(jk);
            diff = jk_mean - jk;
            num = sum(diff.^3);
            den = 6 * (sum(diff.^2))^1.5;
            if den > 0
                a = num / den;
            else
                a = 0;
            end
        end
    end

    % Adjusted quantiles
    z_lo = norminv(alpha/2);
    z_hi = norminv(1 - alpha/2);
    alpha1 = normcdf(z0 + (z0 + z_lo) / (1 - a*(z0 + z_lo)));
    alpha2 = normcdf(z0 + (z0 + z_hi) / (1 - a*(z0 + z_hi)));
    alpha1 = min(max(alpha1, 1e-6), 1 - 1e-6);
    alpha2 = min(max(alpha2, 1e-6), 1 - 1e-6);

    lo = prctile(r_boot, 100*alpha1);
    hi = prctile(r_boot, 100*alpha2);
end
