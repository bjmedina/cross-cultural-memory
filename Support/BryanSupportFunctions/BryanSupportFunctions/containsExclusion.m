function [found, intersect_idx] = containsExclusion(sequence, exclusions)
    
    intersect_idx = zeros(length(sequence),1);
    
    for i=1:length(sequence)
        for j=1:length(exclusions)
            if sequence(i) == exclusions(j)
                intersect_idx(i) = intersect_idx(i) + 1;
                break
            end
        end
    end
    
    if sum(intersect_idx) > 0
        found = 1;
    else
        found = 0;
    end
    
    