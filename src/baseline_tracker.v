/*
 * Copyright (c) 2026 Tazeem Mahashin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module baseline_tracker #(
    parameter AVG_SHIFT = 2
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] sample,
    input  wire       learn_enable,
    input  wire       freeze_baseline,
    output reg  [7:0] baseline,
    output reg        baseline_valid,
    output reg  [7:0] prev_sample,
    output reg        prev_sample_valid
);

  wire [7:0] delta_up = sample - baseline;
  wire [7:0] delta_down = baseline - sample;

  wire [7:0] shifted_up = delta_up >> AVG_SHIFT;
  wire [7:0] shifted_down = delta_down >> AVG_SHIFT;

  wire [7:0] step_up = (shifted_up == 8'd0) ? 8'd1 : shifted_up;
  wire [7:0] step_down = (shifted_down == 8'd0) ? 8'd1 : shifted_down;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baseline <= 8'd0;
      baseline_valid <= 1'b0;
      prev_sample <= 8'd0;
      prev_sample_valid <= 1'b0;
    end else begin
      if (!baseline_valid && learn_enable) begin
        baseline <= sample;
        baseline_valid <= 1'b1;
        prev_sample <= sample;
        prev_sample_valid <= 1'b1;
      end else begin
        if (learn_enable && !freeze_baseline && baseline_valid) begin
          if (sample > baseline) begin
            baseline <= baseline + step_up;
          end else if (baseline > sample) begin
            baseline <= baseline - step_down;
          end
        end

        if (prev_sample_valid) begin
          prev_sample <= sample;
        end
      end
    end
  end

endmodule
