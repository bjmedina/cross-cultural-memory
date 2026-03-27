function [mel] = makeSpecShiftTone_singing_v1(nNMat, midi, dur, up_down, sr, isi)
%New version - if N >4, the second note starts at N+2, not N+1
% _singing version adds an inter-note interval of 300ms


%f0 = F0;
f0_roots = midi2freq(midi);
tone_dur = dur*1000;
if f0_roots(1)>f0_roots(2)
harm_stack = [2:7;nNMat(1):nNMat(1)+5];
else
harm_stack = [nNMat(1):nNMat(1)+5;2:7];
end

%harm_stack = [2:7;5:10];
%harm_stack = [2:7;3:8];

%tone_dur = 500;
%sr = 44100;
num_harm = size(harm_stack,2);
chord=[];

spectral_slope = -4;
ramp_dur = 20;
        for n=1:2 %two notes
            ct = [];
                f0 = f0_roots(n);
                
            for harms=1:num_harm
                h = harm_stack(n,harms);
                t = tone(f0*h,tone_dur,0,sr);
                t = scale_j(t,spectral_slope*log2(h));
                ct = zadd(ct,t);
            end
            ct = hann(ct,ramp_dur,sr);
            chord(n,:) = [ct];
        end
      %  up_down
      %   if sign(up_down) == 1
        mel = [chord(1,:),zeros([1, (isi-(dur*1000))/1000*sr]), chord(2,:)];
        %    elseif sign(up_down) ==-1
       %          mel = [chord(1,:),zeros([1, (isi-(dur*1000))/1000*sr]), chord(2,:)];
                
       %  end
end
         
%         soundsc(chord, sr)
%         figure
%         j_specgram2(chord, sr)
%        %%
% 
%             n = nNMat(1);
%             N = nNMat(2);
%             if n<4
%                 n1 = n;
%             else
%                 n1 = n+1;
%             end
%             
%            
%             
%             x1 = x/(N+n-1);
%             x2 = x/(N+n1);
%             
%             
%             if N ==2
%                 a = sin(2*pi*x1*n*t)+sin(2*pi*x1*(n+1)*t);
%                 
%                 b = sin(2*pi*x2*(n1+1)*t)+sin(2*pi*x2*(n1+2)*t);
%             elseif N ==3
%                 
%                 
%                 a = sin(2*pi*x1*(n)*t)+sin(2*pi*x1*(n+1)*t)+sin(2*pi*x1*(n+2)*t);
%                 b = sin(2*pi*x2*(n1+1)*t)+sin(2*pi*x2*(n1+2)*t)+sin(2*pi*x2*(n1+3)*t);
%                  elseif N ==4
%                 
%                 
%                 a = sin(2*pi*x1*(n)*t)+sin(2*pi*x1*(n+1)*t)+sin(2*pi*x1*(n+2)*t)+sin(2*pi*x1*(n+3)*t);
%                 b = sin(2*pi*x2*(n1+1)*t)+sin(2*pi*x2*(n1+2)*t)+sin(2*pi*x2*(n1+3)*t)+sin(2*pi*x2*(n1+4)*t);
%                 
%       
%             
%             end
%             
%             c = hann(a, 20, sr);
%             d = hann(b, 10, sr);
%             
%             
%              if up_down ==-1
%                   mel = [c, zeros([1, (isi-(dur*1000))/1000*sr]), d];
%             elseif up_down ==1
%                 mel = [d, zeros([1, (isi-(dur*1000))/1000*sr]), c];
%              end
%            %  figure
%            % j_specgram2(mel, sr)
%  end     
%            