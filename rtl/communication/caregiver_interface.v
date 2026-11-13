// =============================================================================
// File        : rtl/communication/caregiver_interface.v
// Project     : MediTrack - Processor-Free Medication Reminder SoC
// Owner       : Person 1 (Configuration & Caregiver Communication)
// Description : Isolated caregiver telemetry FIFO and valid/ready transmitter.
//               - Captures canonical start, ack, and missed event pulses.
//               - Holds comm_valid and payload stable until (comm_valid && comm_ready).
//               - Buffers up to FIFO_DEPTH records so slow external receivers
//                 never stall local timers, queues, or reminders.
//               - On FIFO full overflow, drops the new arrival, raises
//                 overflow flags/counter, and never corrupts records in flight.
// =============================================================================

`timescale 1ns / 1ps

module caregiver_interface #(
    parameter integer FIFO_DEPTH = 8,
    parameter integer PTR_W      = 3,  // log2(FIFO_DEPTH)
    parameter integer CNT_W      = 4,  // log2(FIFO_DEPTH) + 1
    parameter integer SLOT_WIDTH = 4,
    parameter integer PAYLOAD_W  = 17  // {type[1:0], slot[3:0], hour[4:0], min[5:0]}
) (
    input  wire                  clk,
    input  wire                  rst_n,

    // Canonical Event Pulses from reminder_controller (Person 4)
    input  wire                  reminder_start_pulse,
    input  wire [SLOT_WIDTH-1:0] reminder_start_slot,
    input  wire                  ack_event_pulse,
    input  wire [SLOT_WIDTH-1:0] ack_event_slot,
    input  wire                  missed_event_pulse,
    input  wire [SLOT_WIDTH-1:0] missed_event_slot,

    // Current Time Input from timer_unit (Person 2) for Event Timestamping
    input  wire [4:0]            cur_hour,
    input  wire [5:0]            cur_minute,

    // Caregiver Valid/Ready Telemetry Link
    output wire                  comm_valid,
    input  wire                  comm_ready,
    output wire [PAYLOAD_W-1:0]  payload,

    // FIFO & Overflow Diagnostics
    output wire                  fifo_empty,
    output wire                  fifo_full,
    output reg  [CNT_W-1:0]      fifo_count,
    output reg                   fifo_overflow_pulse,
    output reg                   fifo_overflow,
    output reg  [7:0]            overflow_count
);

    // -------------------------------------------------------------------------
    // Event Type Encodings
    // -------------------------------------------------------------------------
    localparam [1:0] EVT_NONE   = 2'b00;
    localparam [1:0] EVT_START  = 2'b01;
    localparam [1:0] EVT_ACK    = 2'b10;
    localparam [1:0] EVT_MISSED = 2'b11;

    // -------------------------------------------------------------------------
    // Incoming Event Capture & Priority Encoding (ACK > MISSED > START)
    // -------------------------------------------------------------------------
    wire                  evt_in_valid;
    reg  [1:0]            evt_in_type;
    reg  [SLOT_WIDTH-1:0] evt_in_slot;
    wire [PAYLOAD_W-1:0]  evt_in_record;

    assign evt_in_valid = ack_event_pulse | missed_event_pulse | reminder_start_pulse;

    always @(*) begin
        if (ack_event_pulse) begin
            evt_in_type = EVT_ACK;
            evt_in_slot = ack_event_slot;
        end else if (missed_event_pulse) begin
            evt_in_type = EVT_MISSED;
            evt_in_slot = missed_event_slot;
        end else if (reminder_start_pulse) begin
            evt_in_type = EVT_START;
            evt_in_slot = reminder_start_slot;
        end else begin
            evt_in_type = EVT_NONE;
            evt_in_slot = {SLOT_WIDTH{1'b0}};
        end
    end

    assign evt_in_record = {evt_in_type, evt_in_slot, cur_hour, cur_minute};

    // -------------------------------------------------------------------------
    // Synchronous FWFT FIFO Storage & Pointers
    // -------------------------------------------------------------------------
    reg [PAYLOAD_W-1:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [PTR_W-1:0]     wr_ptr;
    reg [PTR_W-1:0]     rd_ptr;

    assign fifo_empty = (fifo_count == {CNT_W{1'b0}});
    assign fifo_full  = (fifo_count == FIFO_DEPTH[CNT_W-1:0]);

    // First-Word Fall-Through (FWFT) Output Stage:
    // Head record stays completely stable until (comm_valid && comm_ready)
    assign comm_valid = ~fifo_empty;
    assign payload    = fifo_empty ? {PAYLOAD_W{1'b0}} : fifo_mem[rd_ptr];

    // Handshake qualifiers
    wire pop_en       = comm_valid && comm_ready;
    // Drop incoming event if FIFO is full (protects in-flight record at rd_ptr)
    wire push_en      = evt_in_valid && !fifo_full;
    wire overflow_evt = evt_in_valid && fifo_full;

    integer i;

    // -------------------------------------------------------------------------
    // FIFO Pointer, Memory, and Overflow Sequential Logic
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr              <= {PTR_W{1'b0}};
            rd_ptr              <= {PTR_W{1'b0}};
            fifo_count          <= {CNT_W{1'b0}};
            fifo_overflow_pulse <= 1'b0;
            fifo_overflow       <= 1'b0;
            overflow_count      <= 8'd0;
            for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
                fifo_mem[i] <= {PAYLOAD_W{1'b0}};
            end
        end else begin
            // Write path
            if (push_en) begin
                fifo_mem[wr_ptr] <= evt_in_record;
                wr_ptr           <= (wr_ptr == FIFO_DEPTH - 1) ? {PTR_W{1'b0}} : (wr_ptr + 1'b1);
            end

            // Read path (advance only on valid && ready handshake)
            if (pop_en) begin
                rd_ptr <= (rd_ptr == FIFO_DEPTH - 1) ? {PTR_W{1'b0}} : (rd_ptr + 1'b1);
            end

            // Occupancy counter update
            case ({push_en, pop_en})
                2'b10:   fifo_count <= fifo_count + 1'b1;
                2'b01:   fifo_count <= fifo_count - 1'b1;
                default: fifo_count <= fifo_count; // 2'b00 or 2'b11 (simultaneous push & pop)
            endcase

            // Overflow tracking (drop incoming record, never corrupt FIFO)
            if (overflow_evt) begin
                fifo_overflow_pulse <= 1'b1;
                fifo_overflow       <= 1'b1;
                if (overflow_count != 8'hFF) begin
                    overflow_count <= overflow_count + 8'd1;
                end
            end else begin
                fifo_overflow_pulse <= 1'b0;
            end
        end
    end

endmodule
