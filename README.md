![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Tiny Sentinel

Tiny Sentinel is a one-tile hardware sensor-integrity watchdog for Tiny Tapeout. It monitors an 8-bit sensor stream, maintains an adaptive baseline, and flags spike, stuck-at, and slow-drift anomalies in real time using deterministic shift/add logic, small counters, and saturating arithmetic.

The project demonstrates a practical embedded ASIC block: catching sensor failures directly in silicon before software has to poll, filter, or diagnose the stream.

## What It Does

Tiny Sentinel watches `ui_in[7:0]` as a digital sensor sample. After calibration, it compares each sample against the previous sample and the learned baseline:

- Sudden jumps raise `spike_detected`.
- Repeated identical samples raise `stuck_detected`, including repeated zero.
- Sustained deviation from the baseline raises `drift_detected`.
- A 3-bit score rises on anomaly events and decays on clean samples.
- A latch records that an anomaly happened until cleared.

## Pin Map

| Pin | Direction | Meaning |
| --- | --- | --- |
| `ui_in[7:0]` | input | Current 8-bit sensor sample |
| `uo_out[0]` | output | Any anomaly |
| `uo_out[1]` | output | Spike / sudden jump detected |
| `uo_out[2]` | output | Stuck-at sample detected |
| `uo_out[3]` | output | Slow drift detected |
| `uo_out[6:4]` | output | Saturating anomaly score |
| `uo_out[7]` | output | Latched alert |
| `uio_in[0]` | input | Learn/adapt baseline enable |
| `uio_in[1]` | input | Strict mode |
| `uio_in[2]` | input | Freeze baseline |
| `uio_in[3]` | input | Clear latched alert |
| `uio_out[7:4]` | output | Baseline high nibble |
| `uio_out[3:0]` | output | Tied low |

`uio_oe` is fixed to `8'b11110000`, so `uio[3:0]` are controls and `uio[7:4]` are debug outputs.

## Detection Logic

The baseline tracker initializes on the first learned sample. After that, when learning is enabled and freeze is low, it moves toward the current sample by a power-of-two fraction of the difference. If the shifted difference is zero but the sample differs, the baseline still moves by one count.

The detector uses two distances:

```text
abs_diff  = |sample - baseline|
jump_diff = |sample - previous_sample|
```

Normal mode thresholds:

| Detector | Threshold |
| --- | --- |
| Spike | `jump_diff >= 24` |
| Stuck | same sample for 8 repeats |
| Drift | `abs_diff >= 16` for 4 non-spiking cycles |

Strict mode thresholds:

| Detector | Threshold |
| --- | --- |
| Spike | `jump_diff >= 12` |
| Stuck | same sample for 4 repeats |
| Drift | `abs_diff >= 8` for 2 non-spiking cycles |

During a demo, use learn mode for calibration. For detection, deassert learn mode or assert freeze mode. If learn remains enabled, the detector still works, but slow-drift detection becomes less sensitive because the baseline tracks the signal.

## Verification

The cocotb testbench covers:

- Reset and initialization.
- Baseline learning and debug output.
- Normal mild variation.
- Spike detection.
- Stuck detection, including repeated `8'd0`.
- Drift detection with exact threshold-cycle timing.
- Strict-mode thresholds.
- Frozen baseline behavior.
- Alert latch clear priority.
- Score decay.
- Fixed `uio_oe` mapping.

Run:

```sh
cd test
make -B
```

The passing simulation writes `test/tb.fst` for waveform inspection.

## Implementation Notes

The design is fully synchronous to `clk` with active-low reset through `rst_n`. It uses synthesizable Verilog only: no delays, no initial blocks in source, no implicit wires, and all outputs are assigned. It is designed to fit within a standard 1x1 TinyTapeout tile using simple counters, comparators, shift-based averaging, and saturating arithmetic.

## Screenshots

Passing RTL waveform:

![Tiny Sentinel RTL waveform](docs/assets/waveform.png)

GDS render from the TinyTapeout GDS workflow:

![Tiny Sentinel GDS render](docs/assets/gds_render.png)

The deployed TinyTapeout viewer is available at [taz33m.github.io/tiny-sentinel](https://taz33m.github.io/tiny-sentinel/).

## Limitations

Tiny Sentinel expects an 8-bit digital sample stream and does not digitize analog signals. The baseline is intentionally simple, so it is easy to synthesize and explain, but it is not a statistical model. Thresholds are fixed in hardware except for normal versus strict mode.
