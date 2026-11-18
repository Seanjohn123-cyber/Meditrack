// =============================================================================
// File        : rtl/configuration/schedule_memory.v
// Project     : MediTrack - Processor-Free Medication Reminder SoC
// Owner       : Person 1 (Configuration & Caregiver Communication)
// Description : 15-slot synchronous schedule register file with 7-day calendar.
//               - Updates records atomically on posedge clk when mem_wr_en=1.
//               - Clears all slot enables and fields on reset.
//               - Continuously exposes all 15 slot records via both a packed
//                 255-bit bus and split field buses for schedule_matcher.
//               - Provides a combinational indexed read port for peripherals.
// =============================================================================

`timescale 1ns / 1ps

module schedule_memory #(
    parameter integer NUM_SLOTS  = 15,
    parameter integer SLOT_WIDTH = 4,
    parameter integer MED_ID_W   = 2,
    parameter integer DAY_W      = 3,
    parameter integer RECORD_W   = 17 // {enable[1], med_id[1:0], day[2:0], hour[4:0], minute[5:0]}
) (
    input  wire                          clk,
    input  wire                          rst_n,

    // Write Port from config_interface
    input  wire                          mem_wr_en,
    input  wire [SLOT_WIDTH-1:0]         mem_slot_idx,
    input  wire [MED_ID_W-1:0]           mem_med_id,
    input  wire [DAY_W-1:0]              mem_day,
    input  wire [4:0]                    mem_hour,
    input  wire [5:0]                    mem_minute,
    input  wire                          mem_enable,

    // Combinational Indexed Read Port (for Peripherals / Verification)
    input  wire [SLOT_WIDTH-1:0]         rd_slot_idx,
    output wire                          rd_enable,
    output wire [MED_ID_W-1:0]           rd_med_id,
    output wire [DAY_W-1:0]              rd_day,
    output wire [4:0]                    rd_hour,
    output wire [5:0]                    rd_minute,
    output wire [RECORD_W-1:0]           rd_record,

    // Continuous Parallel Outputs to schedule_matcher (Split Buses)
    output wire [NUM_SLOTS-1:0]          slot_en,
    output wire [NUM_SLOTS*MED_ID_W-1:0] slot_med_id_flat,
    output wire [NUM_SLOTS*DAY_W-1:0]    slot_day_flat,
    output wire [NUM_SLOTS*5-1:0]        slot_hour_flat,
    output wire [NUM_SLOTS*6-1:0]        slot_min_flat,

    // Continuous Parallel Output to schedule_matcher (Packed Bus)
    output wire [NUM_SLOTS*RECORD_W-1:0] schedule_flat
);

    // -------------------------------------------------------------------------
    // Internal 15 x 17-bit Register Array
    // Bit layout per slot:
    // [16]=enable, [15:14]=med_id, [13:11]=day, [10:6]=hour, [5:0]=min
    // -------------------------------------------------------------------------
    reg [RECORD_W-1:0] slot_reg [0:NUM_SLOTS-1];

    integer i;

    // -------------------------------------------------------------------------
    // Atomic Synchronous Write & Reset Logic
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_SLOTS; i = i + 1) begin
                slot_reg[i] <= {RECORD_W{1'b0}};
            end
        end else if (mem_wr_en && (mem_slot_idx < NUM_SLOTS)) begin
            slot_reg[mem_slot_idx] <= {mem_enable, mem_med_id, mem_day, mem_hour, mem_minute};
        end
    end

    // -------------------------------------------------------------------------
    // Continuous Parallel Bus Assignments (Zero-Latency Exposure)
    // -------------------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < NUM_SLOTS; g = g + 1) begin : gen_slot_buses
            assign slot_en[g]                                = slot_reg[g][16];
            assign slot_med_id_flat[g*MED_ID_W +: MED_ID_W] = slot_reg[g][15:14];
            assign slot_day_flat[g*DAY_W +: DAY_W]           = slot_reg[g][13:11];
            assign slot_hour_flat[g*5 +: 5]                  = slot_reg[g][10:6];
            assign slot_min_flat[g*6 +: 6]                   = slot_reg[g][5:0];
            assign schedule_flat[g*RECORD_W +: RECORD_W]     = slot_reg[g];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Combinational Indexed Read Port (Safe Out-of-Range Guard)
    // -------------------------------------------------------------------------
    assign rd_record = (rd_slot_idx < NUM_SLOTS) ? slot_reg[rd_slot_idx] : {RECORD_W{1'b0}};
    assign rd_enable = rd_record[16];
    assign rd_med_id = rd_record[15:14];
    assign rd_day    = rd_record[13:11];
    assign rd_hour   = rd_record[10:6];
    assign rd_minute = rd_record[5:0];

endmodule
