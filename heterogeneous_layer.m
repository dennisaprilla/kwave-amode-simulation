% Simulating Transducer Field Patterns Example
%
% This example demonstrates the use of k-Wave to compute the field pattern
% generated by a curved single element transducer in two dimensions. It
% builds on the Monopole Point Source In A Homogeneous Propagation Medium
% Example.
%
% author: Bradley Treeby
% date: 10th December 2009
% last update: 4th May 2017
%  
% This function is part of the k-Wave Toolbox (http://www.k-wave.org)
% Copyright (C) 2009-2017 Bradley Treeby

% This file is part of k-Wave. k-Wave is free software: you can
% redistribute it and/or modify it under the terms of the GNU Lesser
% General Public License as published by the Free Software Foundation,
% either version 3 of the License, or (at your option) any later version.
% 
% k-Wave is distributed in the hope that it will be useful, but WITHOUT ANY
% WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for
% more details. 
% 
% You should have received a copy of the GNU Lesser General Public License
% along with k-Wave. If not, see <http://www.gnu.org/licenses/>. 

clearvars; close all;

% =========================================================================
% SIMULATION
% =========================================================================

% 1) create the computational grid ----------------------------------------
Nx = 1024;     % number of grid points in the x (row) direction
Ny = Nx/2;     % number of grid points in the y (column) direction
dx = 0.025e-3; % grid point spacing in the x direction [m]
dy = dx;       % grid point spacing in the y direction [m]
kgrid = kWaveGrid(Nx, dx, Ny, dy);

% 2) Create medium --------------------------------------------------------
angle = 0;
medium_logic = makemedium_v1(angle, [Nx, Ny]);

c1 = 1560; % [m/s]
c2 = 3500; % [m/s]
d1 = 1049; % [kg/m^3]
d2 = 1908; % [kg/m^3]
a1 = 0.54; % [dB/(MHz^y cm]
a2 = 6.90; % [dB/(MHz^y cm]

speed1   = c1 * medium_logic;       
speed2   = c2 * (medium_logic==0);
density1 = d1 * medium_logic;      
density2 = d2 * (medium_logic==0); 
alpha1   = a1 * medium_logic;
alpha2   = a2 * (medium_logic==0); 

medium.sound_speed = speed1 + speed2;      
medium.density     = density1 + density2;      
medium.alpha_coeff = alpha1 + alpha2;
medium.alpha_power = 1.25;

% create the time array
kgrid.makeTime(medium.sound_speed);
% Nt = 1000; % [#sample]
% f  = 50e6; % [Hz]
% dt = 1/f;  % [s]
% kgrid.setTime(Nt, dt)

% 3) define a curved transducer element -----------------------------------
radius_m      = 64e-3;
diameter_m    = 6e-3;
arc_pos_m     = [-10e-3 0];

arc_pos       = [(Nx/2)+1, Ny/2] + round(arc_pos_m/dx); % [grid points]    
radius        = round(radius_m/dx);       % [grid points]
diameter      = round(diameter_m/dx)+1;   % [grid points]
focus_pos     = [Nx/2, Ny/2];             % [grid points]
source.p_mask = makeArc([Nx, Ny], arc_pos, radius, diameter, focus_pos);

% 4) Create waveform ------------------------------------------------------
sample_freq = 1/kgrid.dt;   % [Hz]
signal_freq = 7.5e6; % [Hz]
num_cycles  = 3;
source.p    = toneBurst(sample_freq, signal_freq, num_cycles, 'Plot', true);

% 5) Create sensor --------------------------------------------------------
% create a sensor mask covering the entire computational domain using the
% opposing corners of a rectangle
% sensor.mask = [1, 1, Nx, Ny]';
% create a sensor exactly the same as the transducer
sensor.mask = makeArc([Nx, Ny], arc_pos, radius, diameter, focus_pos);

% define the frequency response of the sensor elements
% center_freq = 7.5e6;      % [Hz]
% bandwidth   = 65;         % [%]
% sensor.frequency_response = [center_freq, bandwidth];

% filter the source to remove high frequencies not supported by the grid
% source.p = filterTimeSeries(kgrid, medium, source.p);

% set the record mode capture the final wave-field and the statistics at
% each sensor point 
% sensor.record = {'p_max', 'p_rms'};

% 6) Run the simulation ---------------------------------------------------

% assign the input options
input_args = {'DisplayMask', source.p_mask, 'PMLInside', false, 'PlotPML', false};
% input_args = {'DisplayMask', display_mask, 'PMLInside', false, 'PlotPML', false, 'RecordMovie', true, 'MovieArgs', {'FrameRate', 10}};

% run the simulation
sensor_data = kspaceFirstOrder2D(kgrid, medium, source, sensor, input_args{:});
sensor_data = sum(sensor_data, 1);

% =========================================================================
% SIGNAL PROCESSING
% =========================================================================

% get a suitable scaling factor for the time axis
[~, t_scale, t_prefix] = scaleSI(kgrid.t_array(end));

USRaw_data    = sensor_data;
USRaw_tvector = kgrid.t_array * t_scale;

USBurst_data       = source.p;
USBurst_signalfreq = signal_freq; % [Hz]
USBurst_samplefreq = sample_freq; % [Hz]
USBurst_dt         = 1/USBurst_samplefreq;
USBurst_tvector    = (0:length(USBurst_data) - 1) * USBurst_dt;

% 1) correlate
[S_corr, ~]  = xcorr(USRaw_data, USBurst_data);
S_corr       = S_corr';
% -- start from halfway of barkercode entering the US signal
sample_start = length(S_corr) - ...
               size(USRaw_data,2) - ...
               floor( 0.5 * length(USBurst_data) ) +1;
sample_end   = length(S_corr) - ...
               floor( 0.5 * length(USBurst_data) );
USRaw_corr   = S_corr(sample_start:sample_end);

% 2) Envelope
S_envelop = envelope(USRaw_corr, 100, 'analytic');

% 3) Peak
offset = 200;
[peaks, locs, width, prominence] =  findpeaks( S_envelop(offset+1:end), ...
                                              'MinPeakHeight', 0.5, ...
                                              'MinPeakProminence', 0.5, ...
                                              'SortStr', 'descend', ...
                                              'WidthReference', 'halfprom');
locs_idx = locs(1)+offset;
peaks    = peaks(1);
% locs_t   = locs_idx*(USBurst_dt*1e6);
locs_t   = locs_idx*(kgrid.dt*1e6);

locs_mm  = (c1 * 1e3) * (locs_t*1e-6) / 2

% =========================================================================
% VISUALISATION (2)
% =========================================================================


figure;
subplot(2,1,1);
plot(USRaw_tvector, USRaw_data);
xlabel('Time (us)');
ylabel('Amplitude');
grid on;
axis tight;
subplot(2,1,2);
plot(USRaw_tvector, USRaw_corr);
xlabel('Time (us)');
ylabel('Amplitude');
grid on; axis tight; hold on;
plot(USRaw_tvector, S_envelop, '-r', 'LineWidth', 1);
plot(locs_t, peaks, 'or', 'MarkerFaceColor', 'r');

% figure;
% plot(USRaw_tvector, USRaw_data);
% xlabel('Time (us)');
% ylabel('Amplitude');
% grid on; hold on; axis tight;
% plot(USRaw_tvector, S_envelop, '-r', 'LineWidth', 1);
% plot(locs_t, peaks, 'or', 'MarkerFaceColor', 'r');
















