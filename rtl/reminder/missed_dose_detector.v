//=============================================================================
// Module: missed_dose_detector
// Project: MediTrack SoC Prototype
// Author: Person 4 (Lead - Reminder Lifecycle & Acknowledgement)
// Description: Counts elapsed system clock cycles while reminder_active is asserted.
//              Generates strictly one single-cycle timeout_pulse per reminder.
//              Resets immediately when reminder ends or when a new reminder starts.
//              Never declares a reminder missed directly and never touches counters.
//=============================================================================

`timescale 1ns/1ps

module missed_dose_detector #(
    parameter integer TIMEOUT_CYCLES = 50
)(
    input  wire clk,
    input  wire rst_n,
    input  wire reminder_active,
    input  wire reminder_start_pulse, // Optional strobe for back-to-back instant re-arm
    output reg  timeout_pulse
);

    reg [$clog2(TIMEOUT_CYCLES > 1 ? TIMEOUT_CYCLES : 2):0] timer_count;
    reg timeout_fired;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer_count   <= 'd0;
            timeout_pulse <= 1'b0;
            timeout_fired <= 1'b0;
        end else if (!reminder_active || reminder_start_pulse) begin
            // Reset counter whenever reminder is inactive or a new reminder initiates
            timer_count   <= 'd0;
            timeout_pulse <= 1'b0;
            timeout_fired <= 1'b0;
        end else begin
            if (!timeout_fired) begin
                if (timer_count >= TIMEOUT_CYCLES - 1) begin
                    timeout_pulse <= 1'b1;
                    timeout_fired <= 1'b1;
                end else begin
                    timer_count   <= timer_count + 1'b1;
                    timeout_pulse <= 1'b0;
                end
            end else begin
                // Exactly one single-cycle timeout_pulse is emitted
                timeout_pulse <= 1'b0;
            end
        end
    end

endmodule
