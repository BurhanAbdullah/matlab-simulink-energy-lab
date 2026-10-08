function report = run_energy_benchmark(varargin)
%RUN_ENERGY_BENCHMARK Run deterministic cross-model energy benchmarks.
%
% report = run_energy_benchmark()
% report = run_energy_benchmark("OutputDirectory","benchmark-artifacts")
%
% The harness is intentionally numeric and plot-independent. It calls the
% repository's existing validation examples and adds a compact KPI layer.

options = parse_options(varargin{:});
rootDirectory = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(rootDirectory, 'examples'));

gates = benchmark_default_parameters();

report = struct();
report.schema_version = gates.schema_version;
report.source = "matlab-simulink-energy-lab";
report.timestamp_note = "Deterministic benchmark; no runtime timestamp is stored.";
report.benchmarks = struct();

% ---- Battery 2RC identification ----------------------------------------
battery2rc = struct();
battery2rc.name = "battery_2rc_identification";
battery2rc.status = "FAIL";
battery2rc.metrics = struct();
scenario = build_battery_2rc_fit_scenario();
fitResult = fit_battery_2rc_parameters( ...
    scenario.calibration_data, scenario.initial_parameters);
calibration = evaluate_battery_2rc_fit( ...
    scenario.calibration_data, fitResult.parameters);
validation = evaluate_battery_2rc_fit( ...
    scenario.validation_data, fitResult.parameters);

estimated = fitResult.parameters;
truth = scenario.true_parameters;
estimatedTau_s = [estimated.r1_Ohm*estimated.c1_F, ...
    estimated.r2_Ohm*estimated.c2_F];
truthTau_s = [truth.r1_Ohm*truth.c1_F, truth.r2_Ohm*truth.c2_F];

battery2rc.metrics.calibration_rmse_mV = 1000*calibration.metrics.rmse_V;
battery2rc.metrics.heldout_rmse_mV = 1000*validation.metrics.rmse_V;
battery2rc.metrics.max_resistance_relative_error = max(abs([
    estimated.r0_Ohm/truth.r0_Ohm - 1
    estimated.r1_Ohm/truth.r1_Ohm - 1
    estimated.r2_Ohm/truth.r2_Ohm - 1]));
battery2rc.metrics.max_time_constant_relative_error = max(abs( ...
    estimatedTau_s(:)./truthTau_s(:) - 1));
battery2rc.status = ternary( ...
    calibration.metrics.rmse_V <= gates.battery2rc_max_calibration_rmse_V && ...
    validation.metrics.rmse_V <= gates.battery2rc_max_validation_rmse_V && ...
    battery2rc.metrics.max_resistance_relative_error <= ...
        gates.battery2rc_max_resistance_relative_error && ...
    battery2rc.metrics.max_time_constant_relative_error <= ...
        gates.battery2rc_max_tau_relative_error, ...
    "PASS", "FAIL");
report.benchmarks.battery_2rc_identification = battery2rc;

% ---- SOC EKF ------------------------------------------------------------
ekf = struct();
ekf.name = "battery_soc_ekf";
ekf.status = "FAIL";
ekf.metrics = struct();
ekfResult = simulate_battery_soc_ekf_example();
ekf.metrics.final_abs_soc_error = abs(ekfResult.metrics.final_soc_error);
ekf.metrics.soc_rmse = ekfResult.metrics.soc_rmse;
ekf.metrics.voltage_rmse_mV = 1000*ekfResult.metrics.voltage_rmse_V;
ekf.metrics.settling_time_s = ekfResult.metrics.soc_settling_time_s;
ekf.status = ternary( ...
    ekf.metrics.final_abs_soc_error <= gates.ekf_max_abs_final_soc_error && ...
    ekf.metrics.soc_rmse <= gates.ekf_max_soc_rmse && ...
    ekf.metrics.voltage_rmse_mV <= 1000*gates.ekf_max_voltage_rmse_V && ...
    ekf.metrics.settling_time_s <= gates.ekf_max_settling_time_s, ...
    "PASS", "FAIL");
report.benchmarks.battery_soc_ekf = ekf;

% ---- Thermal model ------------------------------------------------------
thermal = struct();
thermal.name = "battery_thermal_model";
thermal.status = "FAIL";
thermal.metrics = struct();
thermalProfile = battery_thermal_default_profile();
thermalParameters = battery_thermal_default_parameters();
thermalResult = simulate_battery_thermal_model( ...
    thermalProfile, thermalParameters, 1);
thermalLimitSummary = summarize_battery_temperature_limits( ...
    thermalResult, [30; 35; 37; 45]);
thermal.metrics.peak_temperature_C = max(thermalResult.cell_temp_C);
thermal.metrics.energy_balance_error_J = abs(thermalResult.energy_balance_error_J);
thermal.metrics.time_above_35C_s = thermalLimitSummary.time_above_limit_s(2);
thermal.metrics.degree_hours_above_35C = ...
    thermalLimitSummary.degree_hours_above_limit_C_h(2);
thermal.status = ternary( ...
    all(isfinite(thermalResult.cell_temp_C)) && ...
    thermal.metrics.energy_balance_error_J <= ...
        gates.thermal_max_energy_balance_error_J && ...
    thermal.metrics.peak_temperature_C < gates.thermal_max_peak_temperature_C, ...
    "PASS", "FAIL");
report.benchmarks.battery_thermal_model = thermal;

% ---- BESS reserve model -------------------------------------------------
reserve = struct();
reserve.name = "bess_dc_reserve";
reserve.status = "FAIL";
reserve.metrics = struct();
reserveParameters = bess_dc_reserve_default_parameters();
reserveResult = simulate_bess_dc_reserve(reserveParameters);
reserveSummary = summarize_bess_dc_reserve(reserveResult);
reserve.metrics.final_soc = reserveSummary.final_soc;
reserve.metrics.minimum_soc = reserveSummary.minimum_soc;
reserve.metrics.minimum_dc_voltage_V = reserveSummary.minimum_dc_voltage_V;
reserve.metrics.delivered_discharge_energy_kWh = ...
    reserveSummary.delivered_discharge_energy_kWh;
reserve.metrics.curtailed_discharge_energy_kWh = ...
    reserveSummary.curtailed_discharge_energy_kWh;
reserve.metrics.accepted_charge_energy_kWh = ...
    reserveSummary.accepted_charge_energy_kWh;
reserve.status = ternary( ...
    reserve.metrics.minimum_soc >= gates.reserve_min_final_soc && ...
    reserve.metrics.minimum_dc_voltage_V >= gates.reserve_min_dc_voltage_V && ...
    all(isfinite([reserve.metrics.final_soc, ...
        reserve.metrics.minimum_dc_voltage_V, ...
        reserve.metrics.delivered_discharge_energy_kWh])), ...
    "PASS", "FAIL");
report.benchmarks.bess_dc_reserve = reserve;

% ---- Global summary -----------------------------------------------------
names = fieldnames(report.benchmarks);
statuses = strings(numel(names),1);
for index = 1:numel(names)
    statuses(index) = string(report.benchmarks.(names{index}).status);
end
report.summary.total_benchmarks = numel(names);
report.summary.passed_benchmarks = nnz(statuses == "PASS");
report.summary.failed_benchmarks = nnz(statuses == "FAIL");
report.summary.pass_rate = report.summary.passed_benchmarks / ...
    max(1, report.summary.total_benchmarks);
report.summary.status = ternary(report.summary.failed_benchmarks == 0, ...
    "PASS", "FAIL");

if options.WriteArtifacts
    outputDirectory = options.OutputDirectory;
    if ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end
    write_benchmark_json(report, fullfile(outputDirectory, ...
        'energy-benchmark-report.json'));
    write_benchmark_csv(report, fullfile(outputDirectory, ...
        'energy-benchmark-metrics.csv'));
end

end

function options = parse_options(varargin)
options = struct('WriteArtifacts', false, 'OutputDirectory', '');
if mod(nargin,2) ~= 0
    error('EnergyBenchmark:Options', ...
        'Options must be supplied as name/value pairs.');
end
for index = 1:2:nargin
    name = string(varargin{index});
    value = varargin{index+1};
    switch lower(name)
        case "outputdirectory"
            options.OutputDirectory = char(value);
            options.WriteArtifacts = true;
        otherwise
            error('EnergyBenchmark:Options', ...
                'Unknown option: %s', name);
    end
end
end

function value = ternary(condition, trueValue, falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end

function write_benchmark_json(report, pathName)
textToWrite = jsonencode(report, PrettyPrint=true);
fid = fopen(pathName, 'w');
if fid < 0
    error('EnergyBenchmark:IO', 'Unable to create %s.', pathName);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', textToWrite);
end

function write_benchmark_csv(report, pathName)
rows = {};
names = fieldnames(report.benchmarks);
for i = 1:numel(names)
    benchmark = report.benchmarks.(names{i});
    metricNames = fieldnames(benchmark.metrics);
    for j = 1:numel(metricNames)
        metric = metricNames{j};
        value = benchmark.metrics.(metric);
        if isnumeric(value) && isscalar(value)
            rows(end+1,:) = {string(names{i}), string(benchmark.status), ...
                string(metric), value}; %#ok<AGROW>
        end
    end
end
tableData = cell2table(rows, 'VariableNames', ...
    {'benchmark','status','metric','value'});
writetable(tableData, pathName);
end

function result = simulate_battery_soc_ekf_example()
modelDirectory = fileparts(fullfile(mfilename('fullpath')));
fn = fullfile(modelDirectory, '..', 'examples', ...
    'battery-soc-ekf', 'simulate_battery_soc_ekf_example.m');
if ~isfile(fn)
    fn = fullfile(modelDirectory, '..', 'examples', ...
        'battery-soc-ekf', 'simulate_battery_soc_ekf_example.m');
end
if ~isfile(fn)
    error('EnergyBenchmark:Dependency', ...
        'Expected battery SOC EKF example was not found.');
end
addpath(fileparts(fn));
result = feval('simulate_battery_soc_ekf_example');
end
