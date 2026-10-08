function parameters = benchmark_default_parameters()
%BENCHMARK_DEFAULT_PARAMETERS Deterministic benchmark gates.

parameters = struct();

% Battery 2RC gates.
parameters.battery2rc_max_calibration_rmse_V = 1.0e-3;
parameters.battery2rc_max_validation_rmse_V = 1.5e-3;
parameters.battery2rc_max_resistance_relative_error = 0.15;
parameters.battery2rc_max_tau_relative_error = 0.20;

% SOC EKF gates.
parameters.ekf_max_abs_final_soc_error = 0.02;
parameters.ekf_max_soc_rmse = 0.035;
parameters.ekf_max_voltage_rmse_V = 6.0e-3;
parameters.ekf_max_settling_time_s = 1500;

% Thermal gates.
parameters.thermal_max_energy_balance_error_J = 1.0e-6;
parameters.thermal_max_peak_temperature_C = 45;

% Reserve gates.
parameters.reserve_min_final_soc = 0;
parameters.reserve_min_dc_voltage_V = 0;

% Global schema/version.
parameters.schema_version = "1.0";
end
