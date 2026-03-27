%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Nori Jacoby's audio library
% Please don't use it without Nori's permision...
% For more information please contact: nori.viola@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ISIseed0=NITER_randomize_1threshold_point(CLICKS,TOT,TRUNC_TRESH)

% generate uniform samples from the unit simplex

p=nan(CLICKS+1,1);
p(2:CLICKS)=rand(CLICKS-1,1);
p(1)=0;
p(CLICKS+1)=1;
ps=sort(p);
t=diff(ps);
assert(abs(sum(t)-1)<1e-10)

%shift the unit simplex according to the distrebution

ISIseed0=(t*(TOT-CLICKS*TRUNC_TRESH)+TRUNC_TRESH)';

assert(sum(ISIseed0>0)==CLICKS);
assert(abs(sum(ISIseed0)-TOT)<1);


%  ITI1=TRUNC_TRESH;
%  ITI2=TOT-TRUNC_TRESH;
%
%     ISIseed0=[];
%     while ((isempty(ISIseed0)))||(min(ISIseed0)<TRUNC_TRESH)
%         %ISIseed0 = rand(1,CLICKS-1)*(ITI2-ITI1)+ITI1;
%         %ISIseed0(CLICKS) = TOT-sum(ISIseed0(1:(end-1)));
%         ISIseed0=rand(1,CLICKS);
%         ISIseed0=TOT*ISIseed0/sum(ISIseed0);
%     end
%
%     assert(sum(ISIseed0>0)==CLICKS);
%     %sum(ISIseed0)==TOT
%
%     assert(abs(sum(ISIseed0)-TOT)<1); ISIseed0=TOT*ISIseed0/sum(ISIseed0);
end
