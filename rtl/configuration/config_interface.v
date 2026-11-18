// =============================================================================
// File        : rtl/configuration/config_interface.v
// Project     : MediTrack - Processor-Free Medication Reminder SoC
// Owner       : Person 1 (Configuration & Caregiver Communication)
// Description : Validates incoming medication schedule write requests.
//               - Valid requests emit a 1-cycle mem_wr_en strobe and update
//                 aligned output registers to schedule_memory.
//               - Supports 15 schedule slots (0-14) and 7-day weekly schedule (0-6).
//               - Invalid requests emit a 1-cycle cfg_error flag and alter
//                 nothing.
//               - Reset clears all outputs and disables write strobes.
// =============================================================================

`timescale 1ns / 1ps

module config_interface #(
    parameter integer NUM_SLOTS    = 15,
    parameter integer SLOT_WIDTH   = 4,
    parameter integer MED_ID_IN_W  = 4,
    parameter integer MED_ID_OUT_W = 2,
    parameter integer NUM_MEDS     = 4,
    parameter integer MAX_DAY      = 6,
    parameter integer MAX_HOUR     = 23,
    parameter integer MAX_MIN      = 59
) (
    input  wire                    clk,
    input  wire                    rst_n,

    // Upstream Configuration Write Bus
    input  wire                    cfg_wr_en,
    input  wire [SLOT_WIDTH-1:0]   cfg_slot_idx,
    input  wire [MED_ID_IN_W-1:0]  cfg_med_id,
    input  wire [2:0]              cfg_day,      // 0=Day 0 ... 6=Day 6 (7-day week)
    input  wire [4:0]              cfg_hour,
    input  wire [5:0]              cfg_minute,
    input  wire                    cfg_enable,

    // Validation Status Output
    output reg                     cfg_error,

    // Downstream Write Interface to schedule_memory
    output reg                     mem_wr_en,
    output reg  [SLOT_WIDTH-1:0]   mem_slot_idx,
    output reg  [MED_ID_OUT_W-1:0] mem_med_id,
    output reg  [2:0]              mem_day,
    output reg  [4:0]              mem_hour,
    output reg  [5:0]              mem_minute,
    output reg                     mem_enable,
    output wire [16:0]             mem_slot_record
);

    // -------------------------------------------------------------------------
    // Combinational Range Validation
    // -------------------------------------------------------------------------
    wire slot_valid = (cfg_slot_idx < NUM_SLOTS);
    wire med_valid  = (cfg_med_id   < NUM_MEDS);
    wire day_valid  = (cfg_day      <= MAX_DAY);
    wire hour_valid = (cfg_hour     <= MAX_HOUR);
    wire min_valid  = (cfg_minute   <= MAX_MIN);

    wire req_valid  = slot_valid && med_valid && day_valid && hour_valid && min_valid;

    // Pack atomic 17-bit record: {en[1], med_id[1:0], day[2:0], hour[4:0], min[5:0]}
    assign mem_slot_record = {mem_enable, mem_med_id, mem_day, mem_hour, mem_minute};

    // -------------------------------------------------------------------------
    // Synchronous Gatekeeper & Strobe Generation
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_error    <= 1'b0;
            mem_wr_en    <= 1'b0;
            mem_slot_idx <= {SLOT_WIDTH{1'b0}};
            mem_med_id   <= {MED_ID_OUT_W{1'b0}};
            mem_day      <= 3'd0;
            mem_hour     <= 5'd0;
            mem_minute   <= 6'd0;
            mem_enable   <= 1'b0;
        end else begin
            if (cfg_wr_en) begin
                if (req_valid) begin
                    cfg_error    <= 1'b0;
                    mem_wr_en    <= 1'b1;
                    mem_slot_idx <= cfg_slot_idx;
                    mem_med_id   <= cfg_med_id[MED_ID_OUT_W-1:0];
                    mem_day      <= cfg_day;
                    mem_hour     <= cfg_hour;
                    mem_minute   <= cfg_minute;
                    mem_enable   <= cfg_enable;
                end else begin
                    // Invalid request: raise error flag and preserve state
                    cfg_error    <= 1'b1;
                    mem_wr_en    <= 1'b0;
                end
            end else begin
                cfg_error <= 1'b0;
                mem_wr_en <= 1'b0;
            end
        end
    end

endmodule
