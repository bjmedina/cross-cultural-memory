function mysound(x,sr)
x = x - mean(x(:));
rmsvol = sqrt(mean(x(:).^2));
if 20*log10(rmsvol) + 126 > 90;
    error('Reconsider that volume..');
end
sound(x,sr);