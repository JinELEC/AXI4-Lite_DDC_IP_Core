% 16-tap filter coefficients
disp(sprintf('%d,',round(fir1(15,0.04)*32768)))

% 32-tap filter coefficients
disp(sprintf('%d,',round(fir1(31,0.04)*2147483648)))

% 64-tap filter coefficients
disp(sprintf('%d,',round(fir1(63,0.04)*9.223372e+18)))