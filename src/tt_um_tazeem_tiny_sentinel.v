/*
 * Copyright (c) 2026 Tazeem Mahashin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_tazeem_tiny_sentinel (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  wire learn_enable = uio_in[0];
  wire strict_mode = uio_in[1];
  wire freeze_baseline = uio_in[2];
  wire clear_latch = uio_in[3];

  wire [7:0] baseline;
  wire baseline_valid;
  wire [7:0] prev_sample;
  wire prev_sample_valid;

  wire [3:0] stuck_count;
  wire [3:0] drift_count;
  wire spike_flag;
  wire stuck_flag;
  wire drift_flag;
  wire current_event_anomaly;

  wire [2:0] anomaly_score;
  wire any_anomaly;
  wire alert_latched;

  baseline_tracker baseline_tracker_inst (
      .clk(clk),
      .rst_n(rst_n),
      .sample(ui_in),
      .learn_enable(learn_enable),
      .freeze_baseline(freeze_baseline),
      .baseline(baseline),
      .baseline_valid(baseline_valid),
      .prev_sample(prev_sample),
      .prev_sample_valid(prev_sample_valid)
  );

  anomaly_detector anomaly_detector_inst (
      .clk(clk),
      .rst_n(rst_n),
      .sample(ui_in),
      .baseline(baseline),
      .baseline_valid(baseline_valid),
      .prev_sample(prev_sample),
      .prev_sample_valid(prev_sample_valid),
      .strict_mode(strict_mode),
      .stuck_count(stuck_count),
      .drift_count(drift_count),
      .spike_flag(spike_flag),
      .stuck_flag(stuck_flag),
      .drift_flag(drift_flag),
      .current_event_anomaly(current_event_anomaly)
  );

  score_accumulator score_accumulator_inst (
      .clk(clk),
      .rst_n(rst_n),
      .current_event_anomaly(current_event_anomaly),
      .clear_latch(clear_latch),
      .anomaly_score(anomaly_score),
      .any_anomaly(any_anomaly),
      .alert_latched(alert_latched)
  );

  assign uo_out = {
    alert_latched,
    anomaly_score,
    drift_flag,
    stuck_flag,
    spike_flag,
    any_anomaly
  };

  assign uio_out = {baseline[7:4], 4'b0000};
  assign uio_oe = 8'b11110000;

  wire _unused = &{ena, uio_in[7:4], stuck_count, drift_count, 1'b0};

endmodule
