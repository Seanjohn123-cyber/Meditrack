`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// alert_controller.v  --  MediTrack, Person 5
// Drives buzzer and LED from reminder_active (Person 4) ONLY.
// Never acknowledges, times out, counts or creates events.
//
// BLINK_EN = 0 (default): outputs are pure combinational copies of
//                         reminder_active -> no extra state at all.
// BLINK_EN = 1          : outputs pulse while active. Pattern is high for
//                         BLINK_HALF_PERIOD clocks, then low for the same.
//                         Pattern always restarts HIGH when a reminder starts.
// Reset (rst_n active low): blink pattern state cleared. In steady mode there
//                         is no state, so reset has nothing to clear.
// -----------------------------------------------------------------------------
module alert_controller #(
    parameter BLINK_EN          = 0,
    parameter BLINK_HALF_PERIOD = 8      // clocks per half period (>= 1)
)(
    input  wire clk,
    input  wire rst_n,
    input  wire reminder_active,
    output wire buzzer,
    output wire led
);

generate
    if (BLINK_EN != 0) begin : g_blink
        reg [15:0] cnt;
        reg        phase;                // 1 = outputs allowed high

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                cnt   <= 16'd0;
                phase <= 1'b1;
            end else if (!reminder_active) begin
                cnt   <= 16'd0;          // restart pattern for next reminder
                phase <= 1'b1;
            end else if (cnt == BLINK_HALF_PERIOD - 1) begin
                cnt   <= 16'd0;
                phase <= ~phase;
            end else begin
                cnt   <= cnt + 16'd1;
            end
        end

        assign buzzer = reminder_active & phase;
        assign led    = reminder_active & phase;
    end else begin : g_steady
        // clk and rst_n are unused in this configuration (no state).
        assign buzzer = reminder_active;
        assign led    = reminder_active;
    end
endgenerate

endmodule
