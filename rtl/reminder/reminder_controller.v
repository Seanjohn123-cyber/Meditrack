//=============================================================================
// Module: reminder_controller
// Project: MediTrack SoC Prototype
// Author: Person 4 (Lead - Reminder Lifecycle & Acknowledgement)
// Description: Central reminder finite state machine and sole arbiter for 
//              active reminders, acknowledgement acceptance, and timeout detection.
//              Enforces the strict Golden Rule: Acknowledgement beats timeout
//              on the exact same clock edge.
//=============================================================================

`timescale 1ns/1ps

module reminder_controller (
    input  wire        clk,
    input  wire        rst_n,

    // Queue interface (from Person 3)
    input  wire        event_valid,
    input  wire [3:0]  event_slot,
    output reg         event_accept,

    // Button and timeout inputs
    input  wire        ack_pulse,
    input  wire        timeout_pulse,

    // Reminder status to Peripherals (Person 5) and Timeout Detector
    output reg         reminder_active,
    output reg  [3:0]  active_slot,

    // Event pulses to Tracker (Person 3) and Caregiver Interface (Person 1)
    output reg         reminder_start_pulse,
    output reg  [3:0]  reminder_start_slot,
    output reg         ack_event_pulse,
    output reg  [3:0]  ack_event_slot,
    output reg         missed_event_pulse,
    output reg  [3:0]  missed_event_slot
);

    // State encoding
    localparam STATE_IDLE   = 1'b0;
    localparam STATE_ACTIVE = 1'b1;

    reg state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                <= STATE_IDLE;
            event_accept         <= 1'b0;
            reminder_active      <= 1'b0;
            active_slot          <= 4'd0;
            reminder_start_pulse <= 1'b0;
            reminder_start_slot  <= 4'd0;
            ack_event_pulse      <= 1'b0;
            ack_event_slot       <= 4'd0;
            missed_event_pulse   <= 1'b0;
            missed_event_slot    <= 4'd0;
        end else begin
            // Default pulse de-assertions (strictly 1-cycle pulses)
            event_accept         <= 1'b0;
            reminder_start_pulse <= 1'b0;
            ack_event_pulse      <= 1'b0;
            missed_event_pulse   <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    reminder_active <= 1'b0;

                    // Idle state ignores any ack_pulse or stale timeout_pulse
                    if (event_valid) begin
                        // Accept head event from queue
                        event_accept         <= 1'b1;
                        active_slot          <= event_slot;
                        reminder_start_slot  <= event_slot;
                        reminder_start_pulse <= 1'b1;
                        reminder_active      <= 1'b1;
                        state                <= STATE_ACTIVE;
                    end
                end

                STATE_ACTIVE: begin
                    reminder_active <= 1'b1;

                    // Accept no further queue events while active
                    event_accept <= 1'b0;

                    // CRITICAL PRIORITY ARBITRATION:
                    // If ack_pulse and timeout_pulse occur on the exact same cycle,
                    // acknowledgement wins unconditionally. Missed event is suppressed.
                    if (ack_pulse) begin
                        ack_event_pulse    <= 1'b1;
                        ack_event_slot     <= active_slot;
                        missed_event_pulse <= 1'b0;
                        reminder_active    <= 1'b0;
                        state              <= STATE_IDLE;
                    end else if (timeout_pulse) begin
                        missed_event_pulse <= 1'b1;
                        missed_event_slot  <= active_slot;
                        ack_event_pulse    <= 1'b0;
                        reminder_active    <= 1'b0;
                        state              <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
