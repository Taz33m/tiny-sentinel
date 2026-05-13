# Tiny Sentinel Testbench

This directory contains the cocotb RTL testbench for Tiny Sentinel.

## How to run

```sh
make -B
```

The testbench instantiates `tt_um_tazeem_tiny_sentinel`, drives the Tiny Tapeout harness pins, and checks the project behavior against the submission spec.

Covered scenarios:

- Reset and warmup behavior.
- First learned sample initialization.
- Baseline adaptation.
- Normal non-anomalous samples.
- Spike detection.
- Stuck-at detection, including repeated zero.
- Slow drift detection and exact flag timing.
- Strict mode.
- Frozen baseline behavior.
- Alert latch clear priority.
- Score decay.
- Fixed `uio_oe` and debug output mapping.

The simulation writes `tb.fst`. View it with GTKWave or Surfer:

```sh
gtkwave tb.fst tb.gtkw
```

or

```sh
surfer tb.fst
```
