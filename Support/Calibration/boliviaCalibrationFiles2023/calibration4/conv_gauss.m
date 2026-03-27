function y = conv_gauss(x,sig)

if round(3*sig) < 1
    y = x;
    return;
end
h = normpdf(-ceil(3*sig):ceil(3*sig), 0, sig);
h = h/sum(h);
        
x_buf = [ones(length(h),1) * x(1);  x;  ones(length(h),1) * x(end)];
y_buf = conv(x_buf,h,'same');
y = y_buf(length(h) + 1 : end - length(h));