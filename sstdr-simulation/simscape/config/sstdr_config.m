function [config] = sstdr_config(configuration_name)
%SSTDR_CONFIG Configuration manager for SSTDR simulations
%
% Usage:
%   sstdr_config('default')      % Load default configuration
%   sstdr_config('sine_fast')    % Fast sine wave modulation
%   sstdr_config('unmodulated')  % Unmodulated PN sequence
%   config = sstdr_config(...)   % Return configuration structure
%
% This function sets up predefined configurations for SSTDR simulations
% and provides easy integration with Simscape models.
%
% All configurations now use explicit chip rate control with the following pattern:
% - Chip rate = Modulation frequency (when modulated)
% - Sampling frequency = 4x chip rate
% - Max step = 1/(10*fs) for numerical accuracy

if nargin < 1
    configuration_name = 'default';
end

fprintf('Loading SSTDR configuration: %s\n', configuration_name);

%% Predefined Configurations
switch lower(configuration_name)
    case 'default'
        % 100 kHz chip rate, 100 kHz carrier, 400 kHz sampling
        config = struct( ...
            'name', 'Default SSTDR', ...
            'pn_config', struct( ...
                'modulation', 'sine', ...
                'carrier_freq', 100e3, ...
                'chip_rate', 100e3, ...
                'fs', 400e3, ...
                'pn_bits', 10, ...
                'polynomial', [10 3 0], ...
                'magnitude', 1 ...
            ), ...
            'correlation_config', struct( ...
                'method', 'freq', ...
                'peak_threshold', 0.1, ...
                'normalize', true, ...
                'plot_results', true ...
            ), ...
            'simulation_config', struct( ...
                'stop_time', 10.23e-3, ...  % Duration for 1023 chips at 100kHz chip rate
                'solver', 'ode45', ...
                'max_step', 1/(10*400e3) ...  % 10 steps per sample period
            ) ...
        );
        
    case 'sine_fast'
        % 250 kHz chip rate, 250 kHz carrier, 1 MHz sampling
        config = struct( ...
            'name', 'Fast Sine Wave SSTDR', ...
            'pn_config', struct( ...
                'modulation', 'sine', ...
                'carrier_freq', 250e3, ...
                'chip_rate', 250e3, ...
                'fs', 1e6, ...
                'pn_bits', 10, ...
                'polynomial', [10 3 0], ...
                'magnitude', 1 ...
            ), ...
            'correlation_config', struct( ...
                'method', 'freq', ...
                'peak_threshold', 0.15, ...
                'normalize', true, ...
                'plot_results', true ...
            ), ...
            'simulation_config', struct( ...
                'stop_time', 4.092e-3, ...  % Duration for 1023 chips at 250kHz chip rate
                'solver', 'ode45', ...
                'max_step', 1/(10*1e6) ...  % 10 steps per sample period
            ) ...
        );
        
    case 'unmodulated'
        % 125 kHz chip rate, no carrier, 500 kHz sampling
        config = struct( ...
            'name', 'Unmodulated PN SSTDR', ...
            'pn_config', struct( ...
                'modulation', 'none', ...
                'carrier_freq', 0, ...
                'chip_rate', 125e3, ...
                'fs', 500e3, ...
                'pn_bits', 10, ...
                'polynomial', [10 3 0], ...
                'magnitude', 2 ...
            ), ...
            'correlation_config', struct( ...
                'method', 'both', ...
                'peak_threshold', 0.2, ...
                'normalize', true, ...
                'plot_results', true ...
            ), ...
            'simulation_config', struct( ...
                'stop_time', 8.184e-3, ...  % Duration for 1023 chips at 125kHz chip rate
                'solver', 'ode23t', ...
                'max_step', 1/(10*500e3) ...  % 10 steps per sample period
            ) ...
        );
        
    case 'high_res'
        % 200 kHz chip rate, 200 kHz carrier, 800 kHz sampling
        config = struct( ...
            'name', 'High Resolution SSTDR', ...
            'pn_config', struct( ...
                'modulation', 'sine', ...
                'carrier_freq', 200e3, ...
                'chip_rate', 200e3, ...
                'fs', 800e3, ...
                'pn_bits', 11, ...
                'polynomial', [11 2 0], ...
                'magnitude', 1 ...
            ), ...
            'correlation_config', struct( ...
                'method', 'freq', ...
                'peak_threshold', 0.05, ...
                'normalize', true, ...
                'plot_results', true ...
            ), ...
            'simulation_config', struct( ...
                'stop_time', 10.235e-3, ...  % Duration for 2047 chips at 200kHz chip rate
                'solver', 'ode45', ...
                'max_step', 1/(10*800e3) ...  % 10 steps per sample period
            ) ...
        );
        
    otherwise
        error('Unknown configuration: %s. Available: default, sine_fast, unmodulated, high_res', configuration_name);
end

%% Apply Configuration
fprintf('Applying configuration: %s\n', config.name);

% Generate PN code with specified parameters
pn_params = namedargs2cell(config.pn_config);
pn_result = gen_pn_code(pn_params{:});

% Store PN generation results in config
config.pn_result = pn_result;

% Set up simulation parameters in base workspace for Simscape
assignin('base', 'sim_stop_time', config.simulation_config.stop_time);
assignin('base', 'sim_solver', config.simulation_config.solver);
assignin('base', 'sim_max_step', config.simulation_config.max_step);

% Export sampling parameters for model configuration
assignin('base', 'sim_fs', config.pn_config.fs);              % Sampling frequency
assignin('base', 'sim_ts', 1/config.pn_config.fs);            % Sample time
assignin('base', 'sim_decimation', pn_result.settings.interpFactor); % Decimation factor
assignin('base', 'sim_chip_rate', config.pn_config.chip_rate); % Chip rate

% Store configuration in base workspace
assignin('base', 'sstdr_config', config);

%% Display Configuration Summary
fprintf('\n=== SSTDR Configuration Summary ===\n');
fprintf('Configuration: %s\n', config.name);
fprintf('PN Sequence:\n');
fprintf('  - Length: %d bits (%d chips)\n', config.pn_config.pn_bits, pn_result.pn_length);
fprintf('  - Modulation: %s\n', config.pn_config.modulation);
fprintf('Frequencies:\n');
fprintf('  - Chip rate: %.1f kHz (%.3f μs per chip)\n', config.pn_config.chip_rate/1000, 1e6/config.pn_config.chip_rate);
if ~strcmp(config.pn_config.modulation, 'none')
    fprintf('  - Carrier frequency: %.1f kHz\n', config.pn_config.carrier_freq/1000);
    fprintf('  - Frequency ratio: %.1fx (carrier/chip)\n', config.pn_config.carrier_freq/config.pn_config.chip_rate);
end
fprintf('  - Sampling frequency: %.1f kHz\n', config.pn_config.fs/1000);
fprintf('  - Sampling ratio: %.1fx (fs/chip_rate)\n', config.pn_config.fs/config.pn_config.chip_rate);
fprintf('  - Duration: %.3f ms\n', pn_result.total_duration*1000);
fprintf('Correlation:\n');
fprintf('  - Method: %s\n', config.correlation_config.method);
fprintf('  - Peak threshold: %.2f\n', config.correlation_config.peak_threshold);
fprintf('Simulation:\n');
fprintf('  - Stop time: %.3f ms\n', config.simulation_config.stop_time*1000);
fprintf('  - Solver: %s\n', config.simulation_config.solver);
fprintf('  - Max step: %.1f μs\n', config.simulation_config.max_step*1e6);
fprintf('Exported Variables:\n');
fprintf('  - sim_fs: %.0f Hz (sampling frequency)\n', config.pn_config.fs);
fprintf('  - sim_ts: %.2e s (sample time)\n', 1/config.pn_config.fs);
fprintf('  - sim_chip_rate: %.0f Hz (chip rate)\n', config.pn_config.chip_rate);
fprintf('  - sim_decimation: %d (interpolation factor)\n', pn_result.settings.interpFactor);

end 