function [lo, hi] = ciFisherZ(r_hat, r_boot, alpha)
% ciFisherZ
%   Normal-approximation CI for a correlation on the Fisher-z scale,
%   back-transformed via tanh. See STATS.md §4.3.
%
%   [lo, hi] = ciFisherZ(r_hat, r_boot, alpha)
%
%   r_hat  : sample point estimate (untransformed r in (-1, 1))
%   r_boot : vector of bootstrap r values
%   alpha  : 1 - confidence level (default 0.05 -> 95% CI)
%
%   The CI is:
%       z_hat   = atanh(r_hat)
%       sigma_z = std(atanh(r_boot))
%       CI_z    = z_hat +/- z_{1-alpha/2} * sigma_z
%       CI_r    = tanh(CI_z)
%
%   r_boot values exactly equal to +/-1 are clipped to +/-1 +/- eps before
%   atanh so infinities don't contaminate the SD.

    if nargin < 3, alpha = 0.05; end
    if ~isfinite(r_hat)
        lo = NaN; hi = NaN; return
    end
    r_boot = r_boot(isfinite(r_boot));
    if numel(r_boot) < 2
        lo = NaN; hi = NaN; return
    end
    eps_ = 1e-6;
    z_boot = atanh(max(min(r_boot, 1 - eps_), -1 + eps_));
    sigma_z = std(z_boot, 0);
    z_hat = atanh(max(min(r_hat, 1 - eps_), -1 + eps_));
    z_crit = norminv(1 - alpha/2);
    lo = tanh(z_hat - z_crit * sigma_z);
    hi = tanh(z_hat + z_crit * sigma_z);
end
