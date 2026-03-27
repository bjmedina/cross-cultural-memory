function corrmat = fastcorr(aa,bb)
corrmat = sum(zscore(aa).*zscore(bb))/(size(aa,1)-1);