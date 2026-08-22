%% ==========================================================
% Linear FFT of CORDIC Output & FIR Output (MHz Scale)
% ==========================================================
clear;
clc;
close all;

%% Sampling Frequency
Fs = 5e6;   % 21-clock interval (100 MHz / 21) ≈ 4.7619 MHz

%% Read files
cordic = load('cordic_out.txt');
fir    = load('fir_out.txt');

%% Remove DC
cordic = cordic - mean(cordic);
fir    = fir - mean(fir);

%% FFT
N1 = length(cordic);
N2 = length(fir);
CORDIC_FFT = abs(fft(cordic)) / N1;
FIR_FFT    = abs(fft(fir)) / N2;

%% Positive Spectrum
CORDIC_FFT = CORDIC_FFT(1:floor(N1/2));
FIR_FFT    = FIR_FFT(1:floor(N2/2));

% Frequency Axis (MHz)
f1_mhz = (0:floor(N1/2)-1) * (Fs / N1) / 1e6;
f2_mhz = (0:floor(N2/2)-1) * (Fs / N2) / 1e6;

%% ==========================================================
% Figure 1: CORDIC Output FFT
%% ==========================================================
figure('Color', 'w');
plot(f1_mhz, CORDIC_FFT, 'LineWidth', 1.5, 'Color', [0 0.4470 0.7410]);
grid on;
xlabel('Frequency (MHz)', 'FontSize', 11);
ylabel('Magnitude', 'FontSize', 11);
title('CORDIC Output FFT', 'FontSize', 12, 'FontWeight', 'bold');
xlim([0 Fs/(2*1e6)]);

%% ==========================================================
% Figure 2: FIR Output FFT
%% ==========================================================
figure('Color', 'w');
plot(f2_mhz, FIR_FFT, 'LineWidth', 1.5, 'Color', [0.8500 0.3250 0.0980]);
grid on;
xlabel('Frequency (MHz)', 'FontSize', 11);
ylabel('Magnitude', 'FontSize', 11);
title('FIR Filter Output FFT (64-tap)', 'FontSize', 12, 'FontWeight', 'bold');
xlim([0 Fs/(2*1e6)]);
