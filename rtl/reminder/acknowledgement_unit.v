//=============================================================================
// Module: acknowledgement_unit
// Project: MediTrack SoC Prototype
// Author: Person 4 (Lead - Reminder Lifecycle & Acknowledgement)
// Description: Synchronises raw button input across clock domain boundaries,
//              filters mechanical contact bounce with a parameterized counter,
//              and generates exactly one single-cycle active-high ack_pulse.
//              Holding the button asserts ack_pulse for exactly one cycle.
//=============================================================================

`timescale 1ns/1ps

module acknowledgement_unit #(
    parameter integer DEBOUNCE_CYCLES = 4
)(
    input  wire clk,
    input  wire rst_n,
    input  wire btn_ack_raw,
    output reg  ack_pulse
);

    // Two-stage synchronizer to protect against metastability
    reg sync_ff1;
    reg sync_ff2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= btn_ack_raw;
            sync_ff2 <= sync_ff1;
        end
    end

    // Counter-based debouncer
    reg [$clog2(DEBOUNCE_CYCLES > 1 ? DEBOUNCE_CYCLES : 2):0] debounce_counter;
    reg debounced_state;
    reg debounced_state_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_counter   <= 'd0;
            debounced_state    <= 1'b0;
            debounced_state_d1 <= 1'b0;
            ack_pulse          <= 1'b0;
        end else begin
            // Track previous debounced state for rising edge detection
            debounced_state_d1 <= debounced_state;

            if (sync_ff2 != debounced_state) begin
                if (debounce_counter >= DEBOUNCE_CYCLES - 1) begin
                    debounced_state  <= sync_ff2;
                    debounce_counter <= 'd0;
                end else begin
                    debounce_counter <= debounce_counter + 1'b1;
                end
            end else begin
                debounce_counter <= 'd0;
            end

            // Rising edge detection yields a strictly single-cycle pulse
            ack_pulse <= (debounced_state && !debounced_state_d1);
        end
    end

endmodule
