dur = 15;
lco = 40;
hco = 10000;
spec_level_init = -30;
filt_atten = 20;
sr = 48000;
test_noise = gnoise_SNH(lco, hco, spec_level_init, filt_atten, dur, sr);

test_noise1 = test_noise/rms(test_noise)*.1;
test_noise2 = test_noise/rms(test_noise)*.01;
test_noise3 = test_noise/rms(test_noise)*.001;
