function val = rmsval(x)

% x = x-mean(x(:));
val = sqrt(mean(x(:).^2));