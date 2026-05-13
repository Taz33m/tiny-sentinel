/*
 * Copyright (c) 2026 Tazeem Mahashin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module anomaly_detector #(
    parameter [7:0] SPIKE_THRESH_NORMAL = 8'd24,
    parameter [7:0] SPIKE_THRESH_STRICT = 8'd12,
    parameter [3:0] STUCK_LIMIT_NORMAL = 4'd8,
    parameter [3:0] STUCK_LIMIT_STRICT = 4'd4,
    parameter [7:0] DRIFT_THRESH_NORMAL = 8'd16,
    parameter [7:0] DRIFT_THRESH_STRICT = 8'd8,
    parameter [3:0] DRIFT_COUNT_LIMIT_NORMAL = 4'd4,
    parameter [3:0] DRIFT_COUNT_LIMIT_STRICT = 4'd2
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] sample,
    input  wire [7:0] baseline,
    input  wire       baseline_valid,
    input  wire [7:0] prev_sample,
    input  wire       prev_sample_valid,
    input  wire       strict_mode,
    output reg  [3:0] stuck_count,
    output reg  [3:0] drift_count,
    output reg        spike_flag,
    output reg        stuck_flag,
    output reg        drift_flag,
    output wire       current_event_anomaly
);

  wire [7:0] spike_threshold = strict_mode ? SPIKE_THRESH_STRICT : SPIKE_THRESH_NORMAL;
  wire [3:0] stuck_limit = strict_mode ? STUCK_LIMIT_STRICT : STUCK_LIMIT_NORMAL;
  wire [7:0] drift_threshold = strict_mode ? DRIFT_THRESH_STRICT : DRIFT_THRESH_NORMAL;
  wire [3:0] drift_count_limit = strict_mode ? DRIFT_COUNT_LIMIT_STRICT : DRIFT_COUNT_LIMIT_NORMAL;

  wire [7:0] abs_diff = (sample >= baseline) ? (sample - baseline) : (baseline - sample);
  wire [7:0] jump_diff = (sample >= prev_sample) ? (sample - prev_sample) : (prev_sample - sample);

  wire [3:0] stuck_count_inc = (stuck_count == 4'hf) ? 4'hf : (stuck_count + 4'd1);
  wire [3:0] drift_count_inc = (drift_count == 4'hf) ? 4'hf : (drift_count + 4'd1);

  wire repeated_sample = prev_sample_valid && (sample == prev_sample);
  wire spike_event = prev_sample_valid && (jump_diff >= spike_threshold);
  wire [3:0] stuck_count_next = repeated_sample ? stuck_count_inc : 4'd0;
  wire stuck_event = repeated_sample && (stuck_count_next >= stuck_limit);

  wire drift_condition = baseline_valid && (abs_diff >= drift_threshold) && !spike_event;
  wire [3:0] drift_count_next = drift_condition ? drift_count_inc : 4'd0;
  wire drift_event = drift_condition && (drift_count_next >= drift_count_limit);

  assign current_event_anomaly = spike_event || stuck_event || drift_event;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stuck_count <= 4'd0;
      drift_count <= 4'd0;
      spike_flag <= 1'b0;
      stuck_flag <= 1'b0;
      drift_flag <= 1'b0;
    end else begin
      stuck_count <= stuck_count_next;
      drift_count <= drift_count_next;
      spike_flag <= spike_event;
      stuck_flag <= stuck_event;
      drift_flag <= drift_event;
    end
  end

endmodule
