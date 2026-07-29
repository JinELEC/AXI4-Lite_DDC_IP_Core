%% ==========================================================
% Linear FFT of CORDIC Output & FIR Output
% ==========================================================
clear;
clc;
close all;

%% Sampling Frequency
Fs = 12.5e6;     % 12.5 MSPS

%% Read files
cordic = load('cordic_out.txt');
fir    = load('fir_out.txt');

%% Remove DC
cordic = cordic - mean(cordic);
fir    = fir - mean(fir);

%% FFT
N1 = length(cordic);
N2 = length(fir);

CORDIC_FFT = abs(fft(cordic))/N1;
FIR_FFT    = abs(fft(fir))/N2;

%% Positive Spectrum
CORDIC_FFT = CORDIC_FFT(1:N1/2);
FIR_FFT    = FIR_FFT(1:N2/2);

f1 = (0:N1/2-1) * Fs / N1;
f2 = (0:N2/2-1) * Fs / N2;

%% ==========================================================
% CORDIC Output FFT
%% ==========================================================
figure;

plot(f1/1e3, CORDIC_FFT, 'LineWidth', 1.5);

grid on;
xlabel('Frequency (kHz)');
ylabel('Magnitude');
title('CORDIC Output FFT');

xlim([0 1000]);

%% ==========================================================
% FIR Output FFT
%% ==========================================================
figure;

plot(f2/1e3, FIR_FFT, 'LineWidth', 1.5);

grid on;
xlabel('Frequency (kHz)');
ylabel('Magnitude');
title('FIR Output FFT');

xlim([0 1000]);
