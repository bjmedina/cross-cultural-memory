function  result = zadd(input1,input2);
%zadd - adds two rows with different lengths.  Pads difference at the end with zeros.
%Usage: result = zadd(input1, input2)

if nargin < 2
   help zadd
   return
end

longlength = max(length(input1),length(input2));
difference = length(input1) - length(input2);
if difference < 0
   input1 = [input1 zeros(1,-difference)];
else
   input2 = [input2 zeros(1,difference)];
end

result = input1 + input2;
