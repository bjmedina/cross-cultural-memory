function [mel] = makeF0SpectralTone_v3(nNMat, F0, dur, up_down, sr)
%New version - if N >4, the second note starts at N+2, not N+1
% v3 - removed the N+2 thing from the last version... 
x = F0;
t = 0:1/sr:dur;

            n = nNMat(1);
            N = nNMat(2);
            %if n<4
                n1 = n;
          %  else
           %     n1 = n+1;
          %  end
            
           
            
            x1 = x/(N+n-1);
            x2 = x/(N+n1);
            
            
            if N ==2
                a = sin(2*pi*x1*n*t)+sin(2*pi*x1*(n+1)*t);
                
                b = sin(2*pi*x2*(n1+1)*t)+sin(2*pi*x2*(n1+2)*t);
            elseif N ==3
                
                
                a = sin(2*pi*x1*(n)*t)+sin(2*pi*x1*(n+1)*t)+sin(2*pi*x1*(n+2)*t);
                b = sin(2*pi*x2*(n1+1)*t)+sin(2*pi*x2*(n1+2)*t)+sin(2*pi*x2*(n1+3)*t);
                 elseif N ==4
                
                
                a = sin(2*pi*x1*(n)*t)+sin(2*pi*x1*(n+1)*t)+sin(2*pi*x1*(n+2)*t)+sin(2*pi*x1*(n+3)*t);
                b = sin(2*pi*x2*(n1+1)*t)+sin(2*pi*x2*(n1+2)*t)+sin(2*pi*x2*(n1+3)*t)+sin(2*pi*x2*(n1+4)*t);
                
      
            
            end
            
            c = hann(a, 20, sr);
            d = hann(b, 10, sr);
            
            
             if up_down ==-1
                  mel = [c,d];
            elseif up_down ==1
                mel = [d,c];
             end
           %  figure
           % j_specgram2(mel, sr)
 end     
           