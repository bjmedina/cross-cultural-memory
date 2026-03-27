function  vels=vels_for_octave_set_level(octaves_relative_to_sing_range,IS_MALE)
%all_vels=[105,       102,            95          ,90,      90,           88,       80,    75]; % calibrate by ear
all_vels=[95 92 92 89 86 88 80 74];

if IS_MALE
    octaves_index=octaves_relative_to_sing_range+2;
else
    octaves_index=octaves_relative_to_sing_range+3;
end
assert(max(octaves_index)<=8)
assert(min(octaves_index)>=1)

vels=(all_vels(octaves_index));
