# Energy-System Benchmark Harness

This directory defines a deterministic, tool-free benchmark layer for the
validated battery and BESS examples in this repository.

The purpose is **cross-model engineering regression testing**, not model
certification. Each benchmark returns quantitative metrics with explicit units,
a deterministic scenario identifier, and pass/fail gates. The harness makes it
possible to compare a model revision against a committed baseline without
depending on plots or hand inspection.

## Included benchmark tracks

| Track | Model | Primary KPIs |
| --- | --- | --- |
| Battery dynamics | 2RC identification | calibration RMSE, held-out RMSE, parameter recovery |
| SOC estimation | SOC EKF | final SOC error, SOC RMSE, settling time, voltage RMSE |
| Thermal behaviour | electro-thermal model | peak temperature, thermal energy-balance error, exposure |
| BESS reserve | DC-link/SOC reserve | delivered energy, curtailed energy, minimum DC voltage |
| BESS supervisory control | unified controller | scenario pass rate, tracking, saturation and recovery |

## Design principles

1. **Deterministic:** the same source revision and benchmark inputs must produce
   the same metrics.
2. **Units explicit:** metric names include units where ambiguity is possible.
3. **No plot dependency:** benchmark decisions use numeric results only.
4. **Regression-aware:** baseline values are versioned separately from the code.
5. **Fail loudly:** missing files, non-finite results, or changed metric schemas
   are benchmark failures.
6. **Scientific boundaries visible:** synthetic/reference parameters are never
   presented as measured-cell or certified-grid evidence.

## Running

From the repository root:

```matlab
addpath('benchmarks');
report = run_energy_benchmark;
disp(report.summary)
```

To write machine-readable evidence:

```matlab
addpath('benchmarks');
run_energy_benchmark('OutputDirectory', 'benchmark-artifacts');
```

The benchmark is intentionally implemented with Base MATLAB functionality so
it can be used independently of Simulink for the model families that support
that path.
