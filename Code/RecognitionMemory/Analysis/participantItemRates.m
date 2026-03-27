function R = participantItemRates(files, itemsShared, trialType)
    nSub = numel(files); nItems = numel(itemsShared);
    R = nan(nSub, nItems);
    for i = 1:nSub
        [SP, rp, ic] = loadSP_RP_IC(files{i});
        SP = string(SP(:)); rp = rp(:); ic = logical(ic(:));
        switch lower(trialType)
            case 'hit'
                mask = ~isnan(rp) & rp >= 1;
                if any(mask)
                    [G, ids] = findgroups(SP(mask));
                    val = splitapply(@mean, double(ic(mask)), G);
                    [~, ia, ib] = intersect(itemsShared, unique(ids), 'stable');
                    R(i, ia) = val(ib);
                end
            case 'fa'
                mask = isnan(rp);
                if any(mask)
                    [G, ids] = findgroups(SP(mask));
                    val = splitapply(@mean, 1 - double(ic(mask)), G);
                    [~, ia, ib] = intersect(itemsShared, unique(ids), 'stable');
                    R(i, ia) = val(ib);
                end
        end
    end
end