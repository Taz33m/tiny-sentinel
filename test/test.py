# SPDX-FileCopyrightText: © 2026 Tazeem Mahashin
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer


LEARN = 0x1
STRICT = 0x2
FREEZE = 0x4
CLEAR = 0x8


def as_int(signal):
    return int(signal.value)


def output_value(dut):
    return as_int(dut.uo_out)


def any_flag(dut):
    return output_value(dut) & 0x1


def spike_flag(dut):
    return (output_value(dut) >> 1) & 0x1


def stuck_flag(dut):
    return (output_value(dut) >> 2) & 0x1


def drift_flag(dut):
    return (output_value(dut) >> 3) & 0x1


def score(dut):
    return (output_value(dut) >> 4) & 0x7


def alert_latched(dut):
    return (output_value(dut) >> 7) & 0x1


def baseline_debug(dut):
    return as_int(dut.uio_out)


def baseline_internal(dut):
    return as_int(dut.user_project.baseline_tracker_inst.baseline)


async def tick(dut, sample, controls):
    dut.ui_in.value = sample
    dut.uio_in.value = controls
    await ClockCycles(dut.clk, 1)
    await Timer(1, unit="ns")


async def reset_dut(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 4)
    await Timer(1, unit="ns")
    assert output_value(dut) == 0
    assert as_int(dut.uio_oe) == 0xF0
    assert baseline_debug(dut) == 0

    dut.rst_n.value = 1
    await Timer(1, unit="ns")


async def initialize_at(dut, sample=100):
    await tick(dut, sample, LEARN)
    assert output_value(dut) == 0
    assert baseline_internal(dut) == sample


@cocotb.test()
async def test_tiny_sentinel_behavior(dut):
    dut.clk.value = 0
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())

    dut._log.info("Reset behavior and fixed uio direction mapping")
    await reset_dut(dut)

    dut._log.info("First learned sample initializes baseline and prev_sample without an anomaly")
    await initialize_at(dut, 100)
    assert baseline_debug(dut) == 0x60
    assert as_int(dut.uio_oe) == 0xF0

    dut._log.info("Baseline learning converges toward samples near 100")
    await reset_dut(dut)
    await initialize_at(dut, 80)
    assert baseline_debug(dut) == 0x50
    for sample in [100, 101, 100, 101, 100, 101, 100]:
        await tick(dut, sample, LEARN)
    assert 96 <= baseline_internal(dut) <= 101
    assert baseline_debug(dut) == 0x60

    dut._log.info("Normal mild variation around the baseline does not trigger anomalies")
    await reset_dut(dut)
    await initialize_at(dut, 100)
    for sample in [99, 101, 100, 102, 98, 101]:
        await tick(dut, sample, FREEZE)
        assert any_flag(dut) == 0
        assert spike_flag(dut) == 0
        assert stuck_flag(dut) == 0
        assert drift_flag(dut) == 0
        assert score(dut) == 0
        assert alert_latched(dut) == 0

    dut._log.info("Sudden jump triggers spike, score, any anomaly, and latch")
    await reset_dut(dut)
    await initialize_at(dut, 100)
    await tick(dut, 170, FREEZE)
    assert spike_flag(dut) == 1
    assert stuck_flag(dut) == 0
    assert drift_flag(dut) == 0
    assert any_flag(dut) == 1
    assert score(dut) == 2
    assert alert_latched(dut) == 1

    dut._log.info("Repeated zero after initialization counts as a stuck-at fault")
    await reset_dut(dut)
    await initialize_at(dut, 0)
    for cycle in range(1, 8):
        await tick(dut, 0, FREEZE)
        assert stuck_flag(dut) == 0, f"stuck asserted too early on repeat {cycle}"
        assert any_flag(dut) == 0
    await tick(dut, 0, FREEZE)
    assert stuck_flag(dut) == 1
    assert any_flag(dut) == 1
    assert score(dut) == 2

    dut._log.info("Slow non-spiking drift asserts when the next drift count reaches the limit")
    await reset_dut(dut)
    await initialize_at(dut, 100)
    for sample in [105, 110, 115, 116, 117, 118]:
        await tick(dut, sample, FREEZE)
        assert spike_flag(dut) == 0
        assert drift_flag(dut) == 0
    await tick(dut, 119, FREEZE)
    assert spike_flag(dut) == 0
    assert drift_flag(dut) == 1
    assert any_flag(dut) == 1
    assert score(dut) == 2

    dut._log.info("Strict mode lowers the spike threshold")
    await reset_dut(dut)
    await initialize_at(dut, 100)
    await tick(dut, 113, FREEZE)
    assert spike_flag(dut) == 0
    assert any_flag(dut) == 0

    await reset_dut(dut)
    await initialize_at(dut, 100)
    await tick(dut, 113, FREEZE | STRICT)
    assert spike_flag(dut) == 1
    assert any_flag(dut) == 1
    assert score(dut) == 2

    dut._log.info("Freeze mode prevents baseline updates even while learn is asserted")
    await reset_dut(dut)
    await initialize_at(dut, 100)
    await tick(dut, 180, LEARN | FREEZE)
    assert baseline_internal(dut) == 100
    assert baseline_debug(dut) == 0x60

    dut._log.info("Clear latch wins even on a cycle with a new anomaly")
    await reset_dut(dut)
    await initialize_at(dut, 100)
    await tick(dut, 170, FREEZE)
    assert alert_latched(dut) == 1
    await tick(dut, 20, FREEZE | CLEAR)
    assert spike_flag(dut) == 1
    assert any_flag(dut) == 1
    assert alert_latched(dut) == 0

    dut._log.info("Score decays toward zero after anomalies stop")
    await reset_dut(dut)
    await initialize_at(dut, 100)
    await tick(dut, 170, FREEZE)
    assert score(dut) == 2
    await tick(dut, 100, FREEZE)
    assert score(dut) == 4
    assert any_flag(dut) == 1
    for expected, sample in [(3, 101), (2, 102), (1, 101), (0, 100)]:
        await tick(dut, sample, FREEZE)
        assert score(dut) == expected
    assert any_flag(dut) == 0
