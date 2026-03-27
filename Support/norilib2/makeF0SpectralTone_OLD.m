function [mel] = makeF0SpectralTone(nNMat, F0, dur, up_down, sr, inter_note_interval)
x = F0;
t = 0:1/sr:dur;

            n = nNMat(1);
            N = nNMat(2);
            
            x1 = x/(N+n-1);
            x2 = x/(N+n);
            
            
            if N ==2
                a = sin(2*pi*x1*n*t)+sin(2*pi*x1*(n+1)*t);
                
                b = sin(2*pi*x2*(n+1)*t)+sin(2*pi*x2*(n+2)*t);
            elseif N ==3
                
                
                a = sin(2*pi*x1*(n)*t)+sin(2*pi*x1*(n+1)*t)+sin(2*pi*x1*(n+2)*t);
                b = sin(2*pi*x2*(n+1)*t)+sin(2*pi*x2*(n+2)*t)+sin(2*pi*x2*(n+3)*t);
                 elseif N ==4
                
                
                a = sin(2*pi*x1*(n)*t)+sin(2*pi*x1*(n+1)*t)+sin(2*pi*x1*(n+2)*t)+sin(2*pi*x1*(n+3)*t);
                b = sin(2*pi*x2*(n+1)*t)+sin(2*pi*x2*(n+2)*t)+sin(2*pi*x2*(n+3)*t)+sin(2*pi*x2*(n+4)*t);
                
      
            
            end
            
            c = hann(a, 20, sr);
            d = hann(b, 10, sr);
            
            
             if up_down ==-1
                  mel = [c,zeros(1,(inter_note_interval-500)*sr/1000),d];
            elseif up_down ==1
                mel = [d,zeros(1,(inter_note_interval-500)*sr/1000),c];
            end
 end     
           