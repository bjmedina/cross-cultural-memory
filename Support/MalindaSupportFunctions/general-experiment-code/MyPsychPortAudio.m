function varargout = MyPsychPortAudio(varargin)

% function varargout = MyPsychPortAudio(varargin)
% 
% Wrapper function for PsychPortAudio used to prevent sounds from being played to loud
% that are too loud. Also checks for clipping. Note this functions assumes 
% that a sinusoid at peak SPL has a certain maximum level, and this value
% must be correct for the sound system being used. 
% 
% Last modified by Sam Norman-Haignere on 2015-06-24

% maximum dB SPL allowed
max_spl = 100;

% dB SPL of a sine tone at peak amplitude
% for the earphones being used
sine_peak_spl = 105;

% relevant commands
switch varargin{1}
    
    case 'FillBuffer'
        
        wav = varargin{3};
        
        % check level
        spl = 10*log10(mean(wav(:).^2)) + sine_peak_spl + 20*log10(sqrt(2));
        if spl > max_spl
            error('Error in MyPsychPortAudio: SPL exceeds %d\n', max_spl);
        end
        
        % check clipping
        if any(abs(wav)>1)
            error('Error in MyPsychPortAudio: Waveform values exceed 1, Clipping will result.');
        end
        
    case 'Volume'
        
        % prevent volume from exceeding 1, so that fill-buffer limits are
        % valid
        vol = varargin{3};
        if vol > 1
            error('Volume cannot be higher than 1.');
        end
        
end

% call PsychPortAudio, return output arguments
[varargout{1:nargout}] = PsychPortAudio(varargin{:});