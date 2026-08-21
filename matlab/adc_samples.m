Fs = 12.5e6;         % 100 MHz / 8

f_in = 3.0e6;        % 3 MHz input IF signal

N = 1024;

t = (0:N-1) / Fs;

adc_data = round(127 * cos(2*pi*f_in*t));

writematrix(adc_data', 'adc_samples.txt');