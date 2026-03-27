function [sourceStructure filterStructure] = straight_analysis(wav,sr)

%% Analysis
fprintf('Straight analysis...\n');
r = exF0candidatesTSTRAIGHTGB(wav,sr);
rc = r;
rc = autoF0Tracking(r,wav);
rc.vuv = refineVoicingDecision(wav,rc);
% rc.vuv(:) = 1;
sourceStructure = aperiodicityRatioSigmoid(wav,rc,1,2,0);
filterStructure = exSpectrumTSTRAIGHTGB(wav,sr,sourceStructure);