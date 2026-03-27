function outs = compareThreeGroupsItemwiseDprime( ...
    baseDir, placeCodesA, placeCodesB, placeCodesC, ...
    condition, minISI0dprime, varargin)
% compareThreeGroupsItemwiseDprime
%   Compute itemwise d' for three groups (A=Boston, B=Tsimane, C=San Borja).
%   Standardize within group (z-score).
%   Compute pairwise itemwise differences: A-B, A-C, B-C.
%
% Interpretation (fixed):
%   A = Boston
%   B = Tsimane
%   C = San Borja
%
% Meaning of ?:
%   ?(A?B) > 0  ? Boston > Tsimane
%   ?(A?B) < 0  ? Tsimane > Boston
%
%   ?(A?C) > 0  ? Boston > San Borja
%   ?(A?C) < 0  ? San Borja > Boston
%
%   ?(B?C) > 0  ? Tsimane > San Borja
%   ?(B?C) < 0  ? San Borja > Tsimane
%
% Bryan Medina ? Jan 2026

    % ----------- Optional args -----------
    p = inputParser;
    addParameter(p,'ShowPlot',true,@islogical);
    addParameter(p,'TopK',20,@isscalar);
    parse(p,varargin{:});
    showPlot = p.Results.ShowPlot;
    topK = p.Results.TopK;

    % ----------- Helper: load group -----------
    function files = loadGroup(placeCodes)
        files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime);
        if isempty(files)
            error('No valid files found for group: %s', strjoin(placeCodes,'-'));
        end
    end

    filesA = loadGroup(placeCodesA);  % Boston
    filesB = loadGroup(placeCodesB);  % Tsimane
    filesC = loadGroup(placeCodesC);  % San Borja

    % ----------- Find shared items across groups -----------
    itemsA = unionOfItems(filesA,'hit');
    itemsB = unionOfItems(filesB,'hit');
    itemsC = unionOfItems(filesC,'hit');

    sharedItems = intersect(intersect(itemsA, itemsB, 'stable'), itemsC, 'stable');
    nItems = numel(sharedItems);

    % ----------- Compute itemwise d' -----------
    function dprimeVec = computeDprime(files, itemList)
        R_hit = participantItemRates(files, itemList, 'hit');
        R_fa  = participantItemRates(files, itemList, 'fa');

        hitMean = mean(R_hit,1,'omitnan');
        faMean  = mean(R_fa,1,'omitnan');

        epsVal = 1e-2;
        hC = min(max(hitMean,epsVal),1-epsVal);
        fC = min(max(faMean, epsVal),1-epsVal);

        dprimeVec = norminv(hC) - norminv(fC);
    end

    dA = computeDprime(filesA, sharedItems);
    dB = computeDprime(filesB, sharedItems);
    dC = computeDprime(filesC, sharedItems);

    % ----------- Z-score per group -----------
    function zVec = zscoreGroup(dp)
        mu = mean(dp,'omitnan');
        sg = std(dp,'omitnan');
        zVec = (dp - mu) ./ sg;
    end

    zA = zscoreGroup(dA);  % Boston
    zB = zscoreGroup(dB);  % Tsimane
    zC = zscoreGroup(dC);  % San Borja

    % ----------- Pairwise ? differences -----------
    DeltaAB = zA - zB;  % Boston - Tsimane
    DeltaAC = zA - zC;  % Boston - San Borja
    DeltaBC = zB - zC;  % Tsimane - San Borja

    % ----------- Table builder -----------
    function T = makePairTable(itemNames, g1Name, g2Name, d1, d2, z1, z2, delta)
        T = table( ...
            itemNames(:), d1(:), d2(:), z1(:), z2(:), delta(:), ...
            'VariableNames', {'Item','dprime_g1','dprime_g2','z_g1','z_g2','Delta'});
        [~,idx] = sort(abs(T.Delta),'descend');
        T = T(idx,:);
    end

    % Hard-coded names
    nameA = 'Boston';
    nameB = 'Tsimane';
    nameC = 'SanBorja';

    TAB = makePairTable(sharedItems, nameA, nameB, dA, dB, zA, zB, DeltaAB);
    TAC = makePairTable(sharedItems, nameA, nameC, dA, dC, zA, zC, DeltaAC);
    TBC = makePairTable(sharedItems, nameB, nameC, dB, dC, zB, zC, DeltaBC);

    % ----------- Store output -----------
    outs = struct();
    outs.items = sharedItems;

    outs.rawDprime = struct('Boston',dA,'Tsimane',dB,'SanBorja',dC);
    outs.zDprime   = struct('Boston',zA,'Tsimane',zB,'SanBorja',zC);

    outs.pairwise = struct();
    outs.pairwise.Boston_minus_Tsimane = TAB;
    outs.pairwise.Boston_minus_SanBorja = TAC;
    outs.pairwise.Tsimane_minus_SanBorja = TBC;

    outs.top.Boston_minus_Tsimane = TAB(1:topK,:);
    outs.top.Boston_minus_SanBorja = TAC(1:topK,:);
    outs.top.Tsimane_minus_SanBorja = TBC(1:topK,:);

    % ----------- Visualization (optional) -----------
    if showPlot
        pairs = {
            {'Boston_minus_Tsimane', TAB, nameA, nameB}, ...
            {'Boston_minus_SanBorja', TAC, nameA, nameC}, ...
            {'Tsimane_minus_SanBorja', TBC, nameB, nameC}
        };

        for pIdx = 1:numel(pairs)
            label = pairs{pIdx}{1};
            T     = pairs{pIdx}{2};
            g1    = pairs{pIdx}{3};
            g2    = pairs{pIdx}{4};

            figure('Color','w','Name',label,'Position',[200 200 1000 700]);

            % Histogram of ? differences
            subplot(2,1,1);
            histogram(T.Delta,'BinWidth',0.1,'FaceColor',[0.4 0.6 0.8]);
            xlabel(sprintf('diff = z(dprime_%s) ? z(dprime_%s)\nPositive = %s > %s   |   Negative = %s > %s', ...
                g1, g2, g1, g2, g2, g1), ...
                'Interpreter','none');

            ylabel('Count');
            title(sprintf('Itemwise differences: %s vs %s', g1, g2), 'Interpreter','none');
            grid on;

            % Top K items
            subplot(2,1,2);
            cleanNames = strrep(T.Item(1:topK), '_',' ');
            bar(T.Delta(1:topK),'FaceColor',[0.7 0.4 0.4]);
            set(gca,'XTick',1:topK,'XTickLabel',cleanNames,...
                'XTickLabelRotation',45,'TickLabelInterpreter','none');
            % Bar plot ylabel
            ylabel(sprintf('z(dprime_%s) ? z(dprime_%s)', g1, g2), 'Interpreter','none');
            title(sprintf('Top %d most different items (%s vs %s)', topK, g1, g2), ...
                  'Interpreter','none');
            grid on;
        end
    end
end