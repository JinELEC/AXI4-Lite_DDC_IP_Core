% 16-tap filter coefficients
disp(sprintf('%d,',round(fir1(15,0.25)*32768)))

% 32-tap filter coefficients
disp(sprintf('%d,',round(fir1(31,0.25)*32768)))

% 64-tap filter coefficients
disp(sprintf('%d,',round(fir1(63,0.25)*32768)))
