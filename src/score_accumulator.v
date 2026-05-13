/*
 * Copyright (c) 2026 Tazeem Mahashin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module score_accumulator (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       current_event_anomaly,
    input  wire       clear_latch,
    output reg  [2:0] anomaly_score,
    output reg        any_anomaly,
    output reg        alert_latched
);

  wire [2:0] score_inc = (anomaly_score >= 3'd6) ? 3'd7 : (anomaly_score + 3'd2);
  wire [2:0] score_dec = (anomaly_score == 3'd0) ? 3'd0 : (anomaly_score - 3'd1);
  wire [2:0] score_next = current_event_anomaly ? score_inc : score_dec;
  wire any_anomaly_next = current_event_anomaly || (score_next >= 3'd4);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      anomaly_score <= 3'd0;
      any_anomaly <= 1'b0;
      alert_latched <= 1'b0;
    end else begin
      anomaly_score <= score_next;
      any_anomaly <= any_anomaly_next;

      if (clear_latch) begin
        alert_latched <= 1'b0;
      end else if (any_anomaly_next) begin
        alert_latched <= 1'b1;
      end
    end
  end

endmodule
