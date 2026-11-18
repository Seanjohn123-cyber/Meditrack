// =============================================================================
// File        : tb/unit/tb_schedule_memory.v
// Project     : MediTrack - Processor-Free Medication Reminder SoC
// Owner       : Person 1 (Configuration & Caregiver Communication)
// Description : Self-checking unit testbench for schedule_memory.v
//               Updated for 15 slots and 7-day weekly schedule.
// =============================================================================

`timescale 1ns / 1ps

module tb_schedule_memory;

    localparam CLK_PERIOD = 10;
    localparam NUM_SLOTS  = 15;
    localparam RECORD_W   = 17;

    reg         clk;
    reg         rst_n;
    reg         mem_wr_en;
    reg  [3:0]  mem_slot_idx;
    reg  [1:0]  mem_med_id;
    reg  [2:0]  mem_day;
    reg  [4:0]  mem_hour;
    reg  [5:0]  mem_minute;
    reg         mem_enable;

    reg  [3:0]  rd_slot_idx;
    wire        rd_enable;
    wire [1:0]  rd_med_id;
    wire [2:0]  rd_day;
    wire [4:0]  rd_hour;
    wire [5:0]  rd_minute;
    wire [RECORD_W-1:0] rd_record;

    wire [NUM_SLOTS-1:0]          slot_en;
    wire [NUM_SLOTS*2-1:0]        slot_med_id_flat;
    wire [NUM_SLOTS*3-1:0]        slot_day_flat;
    wire [NUM_SLOTS*5-1:0]        slot_hour_flat;
    wire [NUM_SLOTS*6-1:0]        slot_min_flat;
    wire [NUM_SLOTS*RECORD_W-1:0] schedule_flat;

    integer pass_count = 0;
    integer fail_count = 0;
    integer s;

    schedule_memory #(
        .NUM_SLOTS(NUM_SLOTS),
        .RECORD_W(RECORD_W)
    ) dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .mem_wr_en        (mem_wr_en),
        .mem_slot_idx     (mem_slot_idx),
        .mem_med_id       (mem_med_id),
        .mem_day          (mem_day),
        .mem_hour         (mem_hour),
        .mem_minute       (mem_minute),
        .mem_enable       (mem_enable),
        .rd_slot_idx      (rd_slot_idx),
        .rd_enable        (rd_enable),
        .rd_med_id        (rd_med_id),
        .rd_day           (rd_day),
        .rd_hour          (rd_hour),
        .rd_minute        (rd_minute),
        .rd_record        (rd_record),
        .slot_en          (slot_en),
        .slot_med_id_flat (slot_med_id_flat),
        .slot_day_flat    (slot_day_flat),
        .slot_hour_flat   (slot_hour_flat),
        .slot_min_flat    (slot_min_flat),
        .schedule_flat    (schedule_flat)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    task write_slot(
        input [3:0] slot,
        input [1:0] med,
        input [2:0] dy,
        input [4:0] hr,
        input [5:0] mn,
        input       en
    );
        begin
            @(negedge clk);
            mem_wr_en    = 1'b1;
            mem_slot_idx = slot;
            mem_med_id   = med;
            mem_day      = dy;
            mem_hour     = hr;
            mem_minute   = mn;
            mem_enable   = en;
            @(negedge clk);
            mem_wr_en    = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("tb_schedule_memory.vcd");
        $dumpvars(0, tb_schedule_memory);

        rst_n        = 1'b0;
        mem_wr_en    = 1'b0;
        mem_slot_idx = 4'd0;
        mem_med_id   = 2'd0;
        mem_day      = 3'd0;
        mem_hour     = 5'd0;
        mem_minute   = 6'd0;
        mem_enable   = 1'b0;
        rd_slot_idx  = 4'd0;

        #(CLK_PERIOD * 2);
        rst_n = 1'b1;
        @(posedge clk);

        // Test 1: Reset clears all 15 slot enables
        if (slot_en === 15'd0 && schedule_flat === { (NUM_SLOTS*RECORD_W){1'b0} }) begin
            $display("[PASS] 1. Initial reset clears all 15 slot enables and records");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] 1. Reset failed!");
            fail_count = fail_count + 1;
        end

        // Test 2: Write then read across all 15 slots
        for (s = 0; s < NUM_SLOTS; s = s + 1) begin
            write_slot(s[3:0], s[1:0], s % 7, s + 6, s * 3, 1'b1);
            rd_slot_idx = s[3:0];
            #1;
            if (rd_enable === 1'b1 && rd_med_id === s[1:0] && rd_day === (s % 7) &&
                rd_hour === (s + 6) && rd_minute === (s * 3)) begin
                $display("[PASS] 2. Write-then-read Slot %0d verified", s);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] 2. Readback mismatch on slot %0d", s);
                fail_count = fail_count + 1;
            end
        end

        // Test 3: Overwrite slot 14
        write_slot(4'd14, 2'd3, 3'd6, 5'd23, 6'd59, 1'b1);
        rd_slot_idx = 4'd14;
        #1;
        if (rd_record === {1'b1, 2'd3, 3'd6, 5'd23, 6'd59}) begin
            $display("[PASS] 3. Overwrite Slot 14 with Day 6 23:59 verified");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] 3. Overwrite Slot 14 failed!");
            fail_count = fail_count + 1;
        end

        // Test 4: Asynchronous reset clears all 15 slots immediately
        rst_n = 1'b0;
        #5;
        if (slot_en === 15'd0) begin
            $display("[PASS] 4. Asynchronous reset clears all 15 populated slots immediately");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] 4. Async reset failed!");
            fail_count = fail_count + 1;
        end

        #(CLK_PERIOD * 2);
        $display("==========================================================");
        $display("tb_schedule_memory Summary: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("==========================================================");

        $finish;
    end

endmodule
