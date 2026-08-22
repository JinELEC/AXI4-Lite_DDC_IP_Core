Fs = 100e6 / 20;      % 100 MHz / 20
f_in = 1.466667e6;    % 1.4667 MHz Input IF (f_LO=1.6667MHz, translated=0.2MHz)
N = 1024;
t = (0:N-1) / Fs;

% 8-bit Signed ADC data (-128 ~ 127)
adc_data = round(127 * cos(2*pi*f_in*t));

writematrix(adc_data', 'adc_samples.txt');
