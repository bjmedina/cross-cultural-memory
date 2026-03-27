function [midpoint] = find_loudest_harm(F0, centroid)
% Find the loudest harmonics around the spectral centroid

HarmVec = F0*[1:1:100];
Diffs = abs(HarmVec-centroid);
midpoint = min(find(Diffs==min(Diffs)));  

end

