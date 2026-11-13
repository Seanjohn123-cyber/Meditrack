//=============================================================================
// Module: reminder_subsystem
// Project: MediTrack SoC Prototype
// Author: Person 4 (Lead - Reminder Lifecycle & Acknowledgement)
// Description: Unified subsystem top-level wrapper interconnecting:
//              1. acknowledgement_unit (Synchronizer + Debouncer)
//              2. missed_dose_detector (Timeout timer)
//              3. reminder_controller (Master FSM & Priority Arbiter)
//=============================================================================

`timescale 1ns/1ps

module reminder_subsystem #(
    parameter integer DEBOUNCE_CYCLES = 4,
    parameter integer TIMEOUT_CYCLES  = 50
)(
    input  wire        clk,
    input  wire        rst_n,

    // Queue Handshake Interface (from Person 3 - event_queue)
    input  wire        event_valid,
    input  wire [3:0]  event_slot,
    output wire        event_accept,

    // External Physical Button Pin
    input  wire        btn_ack_raw,

    // Status to Peripherals & Display (to Person 5)
    output wire        reminder_active,
    output wire [3:0]  active_slot,

    // Event Pulses to Accounting Tracker (Person 3) & Caregiver (Person 1)
    output wire        reminder_start_pulse,
    output wire [3:0]  reminder_start_slot,
    output wire        ack_event_pulse,
    output wire [3:0]  ack_event_slot,
    output wire        missed_event_pulse,
    output wire [3:0]  missed_event_slot,

    // Diagnostic / Verification Taps
    output wire        dbg_ack_pulse,
    output wire        dbg_timeout_pulse
);

    // Internal interconnect wires
    wire ack_pulse_internal;
    wire timeout_pulse_internal;

    assign dbg_ack_pulse     = ack_pulse_internal;
    assign dbg_timeout_pulse = timeout_pulse_internal;

    //-------------------------------------------------------------------------
    // 1. Button Synchronization & Debouncing Unit
    //-------------------------------------------------------------------------
    acknowledgement_unit #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
    ) u_ack_unit (
        .clk        (clk),
        .rst_n      (rst_n),
        .btn_ack_raw(btn_ack_raw),
        .ack_pulse  (ack_pulse_internal)
    );

    //-------------------------------------------------------------------------
    // 2. Missed Dose Timeout Detector
    //-------------------------------------------------------------------------
    missed_dose_detector #(
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES)
    ) u_missed_detector (
        .clk                 (clk),
        .rst_n               (rst_n),
        .reminder_active     (reminder_active),
        .reminder_start_pulse(reminder_start_pulse),
        .timeout_pulse       (timeout_pulse_internal)
    );

    //-------------------------------------------------------------------------
    // 3. Central Reminder Controller FSM
    //-------------------------------------------------------------------------
    reminder_controller u_reminder_ctrl (
        .clk                 (clk),
        .rst_n               (rst_n),
        .event_valid         (event_valid),
        .event_slot          (event_slot),
        .event_accept        (event_accept),
        .ack_pulse           (ack_pulse_internal),
        .timeout_pulse       (timeout_pulse_internal),
        .reminder_active     (reminder_active),
        .active_slot         (active_slot),
        .reminder_start_pulse(reminder_start_pulse),
        .reminder_start_slot (reminder_start_slot),
        .ack_event_pulse     (ack_event_pulse),
        .ack_event_slot      (ack_event_slot),
        .missed_event_pulse  (missed_event_pulse),
        .missed_event_slot   (missed_event_slot)
    );

endmodule
