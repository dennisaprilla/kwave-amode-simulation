clear; close all;

load('test.mat');

% get a suitable scaling factor for the time axis
[~, t_scale, t_prefix] = scaleSI(kgrid.t_array(end));

% 1) Prepare the necessary variables --------------------------------------
USRaw_data       = sensor_data;
USRaw_signalfreq = 1/kgrid.dt;  % [Hz]
USRaw_samplefreq = kgrid.dt;    % [s]
USRaw_tvector    = kgrid.t_array * t_scale; % [mus]

USBurst_data       = source.p;
USBurst_signalfreq = signal_freq; % [Hz]
USBurst_samplefreq = sample_freq; % [Hz]
USBurst_dt         = 1/USBurst_samplefreq; % [s]
USBurst_tvector    = (0:length(USBurst_data) - 1) * USBurst_dt;

% 2) TGC ------------------------------------------------------------------

tgc_mastergain  = 20;  % [dB]
tgc_dacslope    = 0.5; % [dB/mus]
tgc_dacdelay    = 2;   % [mus]
tgc_maxgain     = 40;  % [dB]
tgc_slopesample = tgc_dacslope * (USRaw_samplefreq * 1e6); % [dB/sample]

idx       = knnsearch(USRaw_tvector', tgc_dacdelay, "K", 1);
tgc_x1    = USRaw_tvector(1:idx);
tgc_x2    = USRaw_tvector(idx+1:end);
tgc_y1    = zeros(1, length(tgc_x1));
tgc_y2    = ( tgc_slopesample * (1:length(tgc_x2)) );

tgc_x = [tgc_x1, tgc_x2];
tgc_y = [tgc_y1, tgc_y2] + tgc_mastergain;
tgc_y(tgc_y>tgc_maxgain) = tgc_maxgain;

USRaw_tgc = USRaw_data .* 10.^(tgc_y/10);

figure;
plot(USRaw_tvector, tgc_y, '-r');
grid('on');
axis('tight');
title('Default Time Gain Compensation');
xlabel('Time', 'Interpreter', 'latex');
ylabel('Amplification (dB)', 'Interpreter', 'latex');
ylim([0 50]);

figure;
yyaxis('left');
plot(USRaw_tvector, USRaw_data);
grid on; axis tight;
yyaxis('right');
plot(USRaw_tvector, USRaw_tgc, '-g');
title('Raw vs TGCd');
xlabel('Time (mus)');
ylabel('Pressure');