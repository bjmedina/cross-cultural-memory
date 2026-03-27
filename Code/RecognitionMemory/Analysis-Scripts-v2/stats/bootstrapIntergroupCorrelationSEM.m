function outs = bootstrapIntergroupCorrelationSEM(outsA, outsB, trialType, varargin)
% bootstrapIntergroupCorrelationSEM
%   Bootstrap SEM / CI for intergroup itemwise correlations with optional
%   attenuation correction using reliabilities estimated either across
%   participants (splitDim=1) or across stimuli (splitDim=2).
%
%   Name/Value options:
%     'nBoot'              (1000)
%     'minResp'            (2)
%     'minItems'           (5)
%     'UseSpearman'        (true)
%     'ReliabilityMode'    ('subset')   % 'fixed' | 'subset' | 'per-draw'
%     'SplitHalfRepeats'   (200)
%     'ReliabilitySplitDim'(1)          % 1=participants, 2=stimuli
%     'BootstrapDim'       (1)          % 1=participants, 2=stimuli   <-- NEW
%     'CorrectAtten'       (true)
%     'Verbose'            (true)
%
%   Bryan Medina ? Bolivia 2025

    % ---- options ----
    p = inputParser;
    addParameter(p,'nBoot',1000);
    addParameter(p,'minResp',2);
    addParameter(p,'minItems',5);
    addParameter(p,'UseSpearman',true);
    addParameter(p,'ReliabilityMode','fixed'); % 'fixed'|'subset'|'per-draw'
    addParameter(p,'SplitHalfRepeats',200);
    addParameter(p,'ReliabilitySplitDim',1);
    addParameter(p,'BootstrapDim',1);   % <??? NEW LINE
    addParameter(p,'CorrectAtten',true);
    addParameter(p,'Verbose',true);
    parse(p,varargin{:});
    opt = p.Results;

    corrType = ternary(opt.UseSpearman,'Spearman','Pearson');
    relMode  = lower(string(opt.ReliabilityMode));
    splitDim = opt.ReliabilitySplitDim;
    bootDim  = opt.BootstrapDim;    % ---- select data ----
    
    switch lower(trialType)
        case 'hit'
            A = outsA.itemwise_hits; B = outsB.itemwise_hits;
            SB_fixed_A = outsA.sb_hit; SB_fixed_B = outsB.sb_hit;
        case 'fa'
            A = outsA.itemwise_fas;  B = outsB.itemwise_fas;
            SB_fixed_A = outsA.sb_fa; SB_fixed_B = outsB.sb_fa;
        otherwise
            error('trialType must be ''hit'' or ''fa''.');
    end

    % ---- align items ----
    [sharedItems, ia, ib] = intersect(outsA.items, outsB.items,'stable');
    A = A(:,ia); B = B(:,ib);
    [nA,nItems] = size(A); nB = size(B,1);

    % ---- point estimate ----
    [r_point_raw, valid_items_point] = compute_r_on_items(A,B,corrType,opt.minResp,opt.minItems);
    SB_A_point = NaN; SB_B_point = NaN; r_point_corr = NaN;

    if opt.CorrectAtten
        switch relMode
            case "fixed"
                SB_A_use = SB_fixed_A; SB_B_use = SB_fixed_B;
            case "subset"
                SB_A_use = split_half_SB_flexible(A(:,valid_items_point), corrType, opt.SplitHalfRepeats, splitDim);
                SB_B_use = split_half_SB_flexible(B(:,valid_items_point), corrType, opt.SplitHalfRepeats, splitDim);
            otherwise
                SB_A_use = NaN; SB_B_use = NaN;
        end
        SB_A_point = SB_A_use; SB_B_point = SB_B_use;
        if ~isnan(SB_A_use) && ~isnan(SB_B_use)
            r_point_corr = clamp_unit(r_point_raw / max(sqrt(SB_A_use*SB_B_use), eps));
        end
    end

    % ---- bootstrap ----
    rBoot_raw = nan(opt.nBoot,1);
    rBoot_corr = nan(opt.nBoot,1);
    nKept = nan(opt.nBoot,1);

    for b=1:opt.nBoot
        switch bootDim
            case 1 % bootstrap participants
                idxA = randi(nA,[nA 1]);
                idxB = randi(nB,[nB 1]);
                Amean = nanmean(A(idxA,:),1);
                Bmean = nanmean(B(idxB,:),1);
                nObsA = sum(~isnan(A(idxA,:)),1);
                nObsB = sum(~isnan(B(idxB,:)),1);
                valid = (nObsA>=opt.minResp) & (nObsB>=opt.minResp);

            case 2 % bootstrap stimuli
                % Resample stimuli, then average over participants (dim=1)
                % to get group-level mean per stimulus → [1 × nItems] vectors
                idxStim = randi(nItems,[nItems 1]);
                Amean = nanmean(A(:,idxStim),1);
                Bmean = nanmean(B(:,idxStim),1);
                nObsA = sum(~isnan(A(:,idxStim)),1);
                nObsB = sum(~isnan(B(:,idxStim)),1);
                valid = (nObsA>=opt.minResp) & (nObsB>=opt.minResp);

            otherwise
                error('BootstrapDim must be 1 (participants) or 2 (stimuli).');
        end

        k = sum(valid);
        if k<opt.minItems, continue; end

        r = corr(Amean(valid)', Bmean(valid)', 'Type', corrType, 'Rows','pairwise');
        rBoot_raw(b)=r;
        nKept(b)=k;

        if opt.CorrectAtten
            switch relMode
                case "fixed"
                    SB_A = SB_fixed_A; SB_B = SB_fixed_B;
                case "subset"
                    SB_A = SB_A_point; SB_B = SB_B_point;
                otherwise % 'per-draw'
                    SB_A = split_half_SB_flexible(A, corrType, ceil(opt.SplitHalfRepeats/2), splitDim);
                    SB_B = split_half_SB_flexible(B, corrType, ceil(opt.SplitHalfRepeats/2), splitDim);
            end
            if ~isnan(SB_A) && ~isnan(SB_B)
                rBoot_corr(b) = clamp_unit(r / max(sqrt(SB_A*SB_B), eps));
            end
        end
    end

    % ---- summarize (Fisher-z means) ----
    rBoot_raw  = rBoot_raw(~isnan(rBoot_raw));
    ci_raw     = prctile(rBoot_raw,[2.5 97.5]);
    mean_raw   = tanh(mean(atanh(limit_r(rBoot_raw))));
    if any(~isnan(rBoot_corr))
        rBoot_corr = rBoot_corr(~isnan(rBoot_corr));
        ci_corr    = prctile(rBoot_corr,[2.5 97.5]);
        mean_corr  = tanh(mean(atanh(limit_r(rBoot_corr))));
    else
        rBoot_corr = []; ci_corr=[NaN NaN]; mean_corr=NaN;
    end

    % ---- pack ----
    outs = struct();
    outs.point_raw     = r_point_raw;
    outs.point_corr    = r_point_corr;
    outs.point_itemsN  = sum(valid_items_point);
    outs.mean_boot_raw = mean_raw; outs.ci_raw = ci_raw;
    outs.mean_boot_corr= mean_corr; outs.ci_corr = ci_corr;
    outs.n_kept_items  = nKept(~isnan(nKept));
    outs.shared_items  = sharedItems;
    outs.options       = opt;
    outs.SB_point_A    = SB_A_point; outs.SB_point_B = SB_B_point;

    if opt.Verbose
        fprintf('Intergroup %s ? point r=%.3f (N=%d items)\n', upper(trialType), outs.point_raw, outs.point_itemsN);
        fprintf('Bootstrap RAW (bootDim=%d): mean=%.3f, 95%%CI [%.3f, %.3f]\n', ...
            bootDim, outs.mean_boot_raw, ci_raw(1), ci_raw(2));
        if ~isnan(outs.point_corr)
            fprintf('Corrected (mode=%s, splitDim=%d): point=%.3f | boot mean=%.3f, 95%%CI [%.3f, %.3f]\n', ...
                relMode, splitDim, outs.point_corr, outs.mean_boot_corr, outs.ci_corr(1), outs.ci_corr(2));
        end
    end
end

% ---- helpers ----
function [r, valid] = compute_r_on_items(A,B,corrType,minResp,minItems)
    nObsA=sum(~isnan(A),1); nObsB=sum(~isnan(B),1);
    valid=(nObsA>=minResp)&(nObsB>=minResp);
    if sum(valid)<minItems, r=NaN; return; end
    r=corr(nanmean(A(:,valid),1)', nanmean(B(:,valid),1)', 'Type',corrType,'Rows','pairwise');
end

function SB = split_half_SB_flexible(M, corrType, nRep, splitDim)
    if isempty(M), SB = NaN; return; end
    [nSub, nItems] = size(M);
    rr = nan(nRep, 1);
    for k = 1:nRep
        switch splitDim
            case 1  % across participants
                if nSub < 4, SB = NaN; return; end
                idx = randperm(nSub);
                A = nanmean(M(idx(1:floor(nSub/2)), :), 1);
                B = nanmean(M(idx(floor(nSub/2)+1:end), :), 1);
            case 2  % across stimuli
                if nItems < 4, SB = NaN; return; end
                idx = randperm(nItems);
                A = nanmean(M(:, idx(1:floor(nItems/2))), 2);
                B = nanmean(M(:, idx(floor(nItems/2)+1:end)), 2);
            otherwise
                error('splitDim must be 1 or 2');
        end

        A = A(:); B = B(:);
        valid = ~isnan(A) & ~isnan(B);
        if sum(valid) < 3, rr(k)=NaN; continue; end
        % FIX: use corr() with proper Type and NaN handling (was corrcoef)
        rr(k) = corr(A(valid), B(valid), 'Type', corrType, 'Rows', 'pairwise');
    end
    r_half = mean(rr, 'omitnan');
    SB = (2 * r_half) / (1 + r_half);
end
function x = clamp_unit(x), x=max(-1,min(1,x)); end
function x = limit_r(x), x(x>=1)=0.999999; x(x<=-1)=-0.999999; end

% function outs = bootstrapIntergroupCorrelationSEM(outsA, outsB, trialType, varargin)
% % Participant-bootstrap SEM/CI for intergroup itemwise correlations
% % with attenuation correction using Spearman?Brown reliabilities
% % computed on the SAME items and SAME correlation metric.
% %
% % Name/Value:
% %   'nBoot'           (1000)
% %   'minResp'         (2)
% %   'minItems'        (5)
% %   'UseSpearman'     (true)   % use same metric for reliabilities too
% %   'ReliabilityMode' ('subset') % 'fixed' | 'subset' | 'per-draw'
% %   'SplitHalfRepeats'(200)    % for split-half estimation
% %   'CorrectAtten'    (true)
% %   'Verbose'         (true)
% 
%     % ---- options ----
%     p = inputParser;
%     addParameter(p,'nBoot',1000); addParameter(p,'minResp',2);
%     addParameter(p,'minItems',5); addParameter(p,'UseSpearman',true);
%     addParameter(p,'ReliabilityMode','subset'); % 'fixed'|'subset'|'per-draw'
%     addParameter(p,'SplitHalfRepeats',200);
%     addParameter(p,'CorrectAtten',true); addParameter(p,'Verbose',true);
%     parse(p,varargin{:}); opt=p.Results;
%     corrType = ternary(opt.UseSpearman,'Spearman','Pearson');
%     relMode  = lower(string(opt.ReliabilityMode));
% 
%     % ---- select data ----
%     switch lower(trialType)
%         case 'hit'
%             A = outsA.itemwise_hits; B = outsB.itemwise_hits;
%             SB_fixed_A = outsA.sb_hit; SB_fixed_B = outsB.sb_hit; % SB (full-measure)
%         case 'fa'
%             A = outsA.itemwise_fas;  B = outsB.itemwise_fas;
%             SB_fixed_A = outsA.sb_fa; SB_fixed_B = outsB.sb_fa;
%         otherwise, error('trialType must be ''hit'' or ''fa''.');
%     end
% 
%     % ---- align items ----
%     [sharedItems, ia, ib] = intersect(outsA.items, outsB.items,'stable');
%     A = A(:,ia); B = B(:,ib);
%     [nA,nItems] = size(A); nB = size(B,1);
% 
%     % ---- point estimate with same coverage rules ----
%     [r_point_raw, valid_items_point] = compute_r_on_items(A,B,corrType,opt.minResp,opt.minItems);
%     SB_A_point = NaN; SB_B_point = NaN; r_point_corr = NaN;
% 
%     if opt.CorrectAtten
%         switch relMode
%             case "fixed"
%                 SB_A_use = SB_fixed_A; SB_B_use = SB_fixed_B;
%             case "subset"
%                 SB_A_use = split_half_SB(A(:,valid_items_point), corrType, opt.SplitHalfRepeats);
%                 SB_B_use = split_half_SB(B(:,valid_items_point), corrType, opt.SplitHalfRepeats);
%             otherwise % "per-draw" handled inside loop
%                 SB_A_use = NaN; SB_B_use = NaN;
%         end
%         SB_A_point = SB_A_use; SB_B_point = SB_B_use;
%         if ~isnan(SB_A_use) && ~isnan(SB_B_use)
%             r_point_corr = clamp_unit(r_point_raw / max(sqrt(SB_A_use*SB_B_use), eps));
%         end
%     end
% 
%     % ---- bootstrap ----
%     rBoot_raw = nan(opt.nBoot,1); rBoot_corr = nan(opt.nBoot,1); nKept = nan(opt.nBoot,1);
%     for b=1:opt.nBoot
%         idxA = randi(nA,[nA 1]); idxB = randi(nB,[nB 1]);
%         Amean = nanmean(A(idxA,:),1); Bmean = nanmean(B(idxB,:),1);
% 
%         nObsA = sum(~isnan(A(idxA,:)),1); nObsB = sum(~isnan(B(idxB,:)),1);
%         valid = (nObsA>=opt.minResp) & (nObsB>=opt.minResp);
%         k = sum(valid); if k<opt.minItems, continue; end
% 
%         r = corr(Amean(valid)', Bmean(valid)', 'Type', corrType, 'Rows','pairwise');
%         rBoot_raw(b)=r; nKept(b)=k;
% 
%         if opt.CorrectAtten
%             switch relMode
%                 case "fixed"
%                     SB_A = SB_fixed_A; SB_B = SB_fixed_B;
%                 case "subset"
%                     SB_A = SB_A_point; SB_B = SB_B_point; % same subset as point estimate
%                 otherwise % 'per-draw'
%                     SB_A = split_half_SB(A(idxA,valid), corrType, ceil(opt.SplitHalfRepeats/2));
%                     SB_B = split_half_SB(B(idxB,valid), corrType, ceil(opt.SplitHalfRepeats/2));
%             end
%             if ~isnan(SB_A) && ~isnan(SB_B)
%                 rBoot_corr(b) = clamp_unit(r / max(sqrt(SB_A*SB_B), eps));
%             end
%         end
%     end
% 
%     % ---- summarize (Fisher-z means) ----
%     rBoot_raw  = rBoot_raw(~isnan(rBoot_raw));
%     ci_raw     = prctile(rBoot_raw,[2.5 97.5]);
%     mean_raw   = tanh(mean(atanh(limit_r(rBoot_raw))));
%     if any(~isnan(rBoot_corr))
%         rBoot_corr = rBoot_corr(~isnan(rBoot_corr));
%         ci_corr    = prctile(rBoot_corr,[2.5 97.5]);
%         mean_corr  = tanh(mean(atanh(limit_r(rBoot_corr))));
%     else
%         rBoot_corr = []; ci_corr=[NaN NaN]; mean_corr=NaN;
%     end
% 
%     % ---- pack ----
%     outs = struct();
%     outs.point_raw     = r_point_raw;
%     outs.point_corr    = r_point_corr;
%     outs.point_itemsN  = sum(valid_items_point);
%     outs.mean_boot_raw = mean_raw; outs.ci_raw = ci_raw;
%     outs.mean_boot_corr= mean_corr; outs.ci_corr = ci_corr;
%     outs.n_kept_items  = nKept(~isnan(nKept));
%     outs.shared_items  = sharedItems;
%     outs.options       = opt;
%     outs.SB_point_A    = SB_A_point; outs.SB_point_B = SB_B_point;
% 
%     if opt.Verbose
%         fprintf('Intergroup %s ? point r=%.3f (N=%d items)\n', upper(trialType), outs.point_raw, outs.point_itemsN);
%         fprintf('Bootstrap RAW: mean=%.3f, 95%%CI [%.3f, %.3f]\n', outs.mean_boot_raw, ci_raw(1), ci_raw(2));
%         if ~isnan(outs.point_corr)
%             fprintf('Corrected (mode=%s): point=%.3f | boot mean=%.3f, 95%%CI [%.3f, %.3f]\n', ...
%                 relMode, outs.point_corr, outs.mean_boot_corr, outs.ci_corr(1), outs.ci_corr(2));
%         end
%     end
% end
% 
% % ---- helpers ----
% function [r, valid] = compute_r_on_items(A,B,corrType,minResp,minItems)
%     nObsA=sum(~isnan(A),1); nObsB=sum(~isnan(B),1);
%     valid=(nObsA>=minResp)&(nObsB>=minResp);
%     if sum(valid)<minItems, r=NaN; return; end
%     r=corr(nanmean(A(:,valid),1)', nanmean(B(:,valid),1)', 'Type',corrType,'Rows','pairwise');
% end
% 
% function SB = split_half_SB(M, corrType, nRep)
%     if isempty(M), SB=NaN; return; end
%     nSub=size(M,1); if nSub<4, SB=NaN; return; end
%     rr=nan(nRep,1);
%     for k=1:nRep
%         idx=randperm(nSub);
%         A=nanmean(M(idx(1:floor(nSub/2)),:),1);
%         B=nanmean(M(idx(floor(nSub/2)+1:end),:),1);
%         m=~isnan(A)&~isnan(B);
%         if nnz(m)<3, rr(k)=NaN; else
%             rr(k)=corr(A(m)',B(m)','Type',corrType,'Rows','pairwise');
%         end
%     end
%     r_half=mean(rr,'omitnan');
%     SB=(2*r_half)/(1+r_half);  % Spearman?Brown to full-measure reliability
% end
% 
% function out = ternary(c,a,b), if c, out=a; else, out=b; end, end
% function x = clamp_unit(x), x=max(-1,min(1,x)); end
% function x = limit_r(x), x(x>=1)=0.999999; x(x<=-1)=-0.999999; end