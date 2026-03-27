function items = unionOfItems(files, trialType)
    items = string([]);
    for i = 1:numel(files)
        [SP, rp] = loadSP_RP(files{i});
        SP = string(SP(:)); rp = rp(:);
        
        switch lower(trialType)
            case 'hit', mask = ~isnan(rp) & rp > 1;
            case 'fa',  mask = isnan(rp);
            otherwise,  error('trialType must be ''hit'' or ''fa''.');
        end
        if any(mask)
            items = union(items, unique(SP(mask)));
        end
    end
end