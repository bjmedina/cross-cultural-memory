

%% Small ear

% f = nan(199,1);
px = nan(199,5);
for i = 1:5
    tf = load(['tf-mcdermott-A-7-7-15-SmallEar-v' num2str(i) '-earR.mat']);
    f = tf.f;
    px(:,i) = tf.px;
end

semilogx(f,px);
ylim([70 130]);
xlim([20 10e3]);    
legend('Placement 1', 'Placement 2', 'Placement 3', 'Placement 4',  'Placement 5', 'Location', 'Best');
xlabel('Frequency'); ylabel('Power (dB)');
saveas(gcf,['small-ear-replicability.pdf'],'pdf');

%% Small ear clipping

px = nan(199,2);
tf = load('tf-mcdermott-A-7-7-15-SmallEar-earR.mat');
f = tf.f;
px(:,1) = tf.px;
tf = load('tf-mcdermott-A-7-7-15-SmallEar-ClipEar-earR.mat');
px(:,2) = tf.px;

semilogx(f,px);
ylim([70 130]);
xlim([20 10e3]);    
legend('Regular Placement', 'Ear Clipped', 'Location', 'Best');
xlabel('Frequency'); ylabel('Power (dB)');
saveas(gcf,['small-ear-clipping.pdf'],'pdf');

%% Small ear clipping

px = nan(199,2);
tf = load('tf-mcdermott-A-7-7-15-LargeEar-earR.mat');
f = tf.f;
px(:,1) = tf.px;
tf = load('tf-mcdermott-A-7-7-15-LargeEar-ClipEar-earR.mat');
px(:,2) = tf.px;

semilogx(f,px);
ylim([70 130]);
xlim([20 10e3]);    
legend('Regular Placement', 'Ear Clipped', 'Location', 'Best');
xlabel('Frequency'); ylabel('Power (dB)');
saveas(gcf,['large-ear-clipping.pdf'],'pdf');

%% Effect of pressure on small ear

px = nan(199,2);
tf = load('tf-mcdermott-A-7-7-15-SmallEar-v4-earR.mat');
f = tf.f;
px(:,1) = tf.px;
tf = load('tf-mcdermott-A-7-7-15-SmallEar-GreaterPressure-earR.mat');
px(:,2) = tf.px;

semilogx(f,px);
ylim([70 130]);
xlim([20 10e3]);
legend('Less Pressure', 'Greater Pressure (Book Underneath)', 'Location', 'Best');
xlabel('Frequency'); ylabel('Power (dB)');
saveas(gcf,['small-effect-of-pressure.pdf'],'pdf');
