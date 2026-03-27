function [R,S,W,L,s,r,e,mean_async,mindelay,score]=match_tap_to_template(Sideal,Rr,MAXPROXIMITY)
%Sideal=cumsum([0,ALL{J}.ISI]);

%figure(2);clf;
minscore=MAXPROXIMITY*9999;
mindelay=nan;
for delay=round(-1.2*max(Sideal)):10:round(1.2*max(Rr))
    if delay>=0
        [~,~,~,~,~,~,e]=RawTapstoTaps4(Sideal,Rr-delay,MAXPROXIMITY); % apply a conservative critertion
    else
        [~,~,~,~,~,~,e]=RawTapstoTaps4(Sideal-(-delay),Rr,MAXPROXIMITY); % apply a conservative critertion
    end
    mean_async=mean(e(~isnan(e))); % compute mean asynchorny
    score=abs(mean_async)+sum(isnan(e))*MAXPROXIMITY/4;
    if score<minscore
        minscore=score;
        mindelay=delay;
%                 figure(2);
%                  [R,S,W,L,s,r,e]=RawTapstoTaps4(Sideal,Rr-mindelay,MAXPROXIMITY); % recompute onsets cnaceling out mean async.
%                  plot(S,s,'b+-');hold on; plot(R,s+e,'rd-');
%                  pause;
    end
end

assert(~isnan(mindelay));
[~,~,~,~,~,~,e]=RawTapstoTaps4(Sideal,Rr-mindelay,MAXPROXIMITY); % apply a conservative critertion
mean_async=mean(e(~isnan(e))); % compute mean asynchorny
score=abs(mean_async)+sum(isnan(e))*MAXPROXIMITY/4;


[R,S,W,L,s,r,e]=RawTapstoTaps4(Sideal,Rr-mean_async-mindelay,MAXPROXIMITY); % recompute onsets cnaceling out mean async.
R=R+mean_async; %removing mean async shift
e=e+mean_async; %removing mean async shift

figure(100);clf;
plot(S,s,'b+-');hold on; plot(R,s+e,'rd-');

% THE OLD VERSION OF THIS:
        
            % %             % check that the extracted onsetes mataches the "ideal" template,
            % %             % allow not more than 5 ms difference. This is a sanity check used
            % %             % mainly to make sure data collection is ok.
            % %             MAXproxS=min(ALL{J}.ISI)/2; %used to be:  MAXproxS=min(ISI)/2; %this is just for ideal stimulus
            % %             Sideal=Sr(1)+cumsum([0,ALL{J}.ISI]);
            % %             [Sideal2,~,~,~,~,sideal2,eideal2]=RawTapstoTaps4(Sideal,Sr,MAXproxS);
            % %             assert(max(abs(eideal2))<5);
            % %
            % %             % aligments of extracted onsets
            % %             % find mean asynchrony, shift data by mean async and apply
            % %             % alignment criteria (same for all trials) shift back...
            % %             [~,~,~,~,~,~,e]=RawTapstoTaps4(Sideal2-Sideal2(1),Rr-Sideal2(1),MAXPROXIMITY); % apply a conservative critertion
            % %             mean_async=mean(e(~isnan(e))); % compute mean asynchorny
            % %             [R,S,W,L,s,r,e]=RawTapstoTaps4(Sideal2-Sideal2(1),Rr-Sideal2(1)-mean_async,MAXPROXIMITY); % recompute onsets cnaceling out mean async.
            % %             R=R+mean_async; %removing mean async shift
            % %             e=e+mean_async; %removing mean async shift
            
