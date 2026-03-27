% --------------------------
% utilities
% --------------------------
function p = correctRate_clip(p_raw, eps_val)
    if isnan(p_raw)
        p = NaN;
    else
        p = min(max(p_raw, eps_val), 1 - eps_val);
    end
end