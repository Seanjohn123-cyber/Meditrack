// =============================================================================
// File        : tb/unit/tb_schedule_memory.v
// Project     : MediTrack - Processor-Free Medication Reminder SoC
// Owner       : Person 1 (Configuration & Caregiver Communication)
// Description : Self-checking unit testbench for schedule_memory.v
//               Tests:
//                 1. Reset clears all enables and records
//                 2. Write then read across all 12 slots (packed + split buses)
//                 3. Overwrite existing slot without disturbing other slots
//                 4. Atomic write during continuous read (never half-old/new)
//                 5. Post-population reset clears all enables
// =============================================================================

`timescale 1ns / 1ps

module tb_schedule_memory;

    localparam integer NUM_SLOTS  = 12;
    localparam integer RECORD_W   = 14;
    localparam integer CLK_PERIOD = 10;

    // DUT Signals
    reg                         clk;
    reg                         rst_n;
    reg                         mem_wr_en;
    reg  [3:0]                  mem_slot_idx;
    reg  [1:0]                  mem_med_id;
    reg  [4:0]                  mem_hour;
    reg  [5:0]                  mem_minute;
    reg                         mem_enable;

    reg  [3:0]                  rd_slot_idx;
    wire                        rd_enable;
    wire [1:0]                  rd_med_id;
    wire [4:0]                  rd_hour;
    wire [5:0]                  rd_minute;
    wire [RECORD_W-1:0]         rd_record;

    wire [NUM_SLOTS-1:0]        slot_en;
    wire [NUM_SLOTS*2-1:0]      slot_med_id_flat;
    wire [NUM_SLOTS*5-1:0]      slot_hour_flat;
    wire [NUM_SLOTS*6-1:0]      slot_min_flat;
    wire [NUM_SLOTS*RECORD_W-1:0] schedule_flat;

    integer pass_count = 0;
    integer fail_count = 0;
    integer s;

    // Instantiate DUT
    schedule_memory #(
        .NUM_SLOTS  (NUM_SLOTS),
        .SLOT_WIDTH (4),
        .MED_ID_W   (2),
        .RECORD_W   (RECORD_W)
    ) dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .mem_wr_en        (mem_wr_en),
        .mem_slot_idx     (mem_slot_idx),
        .mem_med_id       (mem_med_id),
        .mem_hour         (mem_hour),
        .mem_minute       (mem_minute),
        .mem_enable       (mem_enable),
        .rd_slot_idx      (rd_slot_idx),
        .rd_enable        (rd_enable),
        .rd_med_id        (rd_med_id),
        .rd_hour          (rd_hour),
        .rd_minute        (rd_minute),
        .rd_record        (rd_record),
        .slot_en          (slot_en),
        .slot_med_id_flat (slot_med_id_flat),
        .slot_hour_flat   (slot_hour_flat),
        .slot_min_flat    (slot_min_flat),
        .schedule_flat    (schedule_flat)
    );

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Helper task: Write a slot on a single clock edge
    task write_slot(
        input [3:0] idx,
        input [1:0] med,
        input [4:0] hr,
        input [5:0] mn,
        input       en
    );
        begin
            @(negedge clk);
            mem_wr_en    = 1'b1;
            mem_slot_idx = idx;
            mem_med_id   = med;
            mem_hour     = hr;
            mem_minute   = mn;
            mem_enable   = en;
            @(posedge clk);
            #1;
            @(negedge clk);
            mem_wr_en    = 1'b0;
        end
    endtask

    // Helper task: Verify a slot across ALL outputs (packed, split, and indexed)
    task verify_slot(
        input [3:0]        idx,
        input [1:0]        exp_med,
        input [4:0]        exp_hr,
        input [5:0]        exp_mn,
        input              exp_en,
        input [80*8:1]     label
    );
        reg [RECORD_W-1:0] exp_rec;
        reg [RECORD_W-1:0] got_packed;
        reg                got_en_split;
        reg [1:0]          got_med_split;
        reg [4:0]          got_hr_split;
        reg [5:0]          got_mn_split;
        begin
            exp_rec       = {exp_en, exp_med, exp_hr, exp_mn};
            rd_slot_idx   = idx;
            #1; // Allow combinational read mux to settle

            got_packed    = schedule_flat[idx*RECORD_W +: RECORD_W];
            got_en_split  = slot_en[idx];
            got_med_split = slot_med_id_flat[idx*2 +: 2];
            got_hr_split  = slot_hour_flat[idx*5 +: 5];
            got_mn_split  = slot_min_flat[idx*6 +: 6];

            if (got_packed === exp_rec &&
                {got_en_split, got_med_split, got_hr_split, got_mn_split} === exp_rec &&
                rd_record === exp_rec &&
                rd_enable === exp_en &&
                rd_med_id === exp_med &&
                rd_hour   === exp_hr &&
                rd_minute === exp_mn) begin
                pass_count = pass_count + 1;
                $display("[PASS] %0s (Slot %0d = {en=%b, med=%0d, %02d:%02d})",
                         label, idx, exp_en, exp_med, exp_hr, exp_mn);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s (Slot %0d) | Packed=%h Split=%h Indexed=%h | Exp=%h",
                         label, idx, got_packed,
                         {got_en_split, got_med_split, got_hr_split, got_mn_split},
                         rd_record, exp_rec);
            end
        end
    endtask

    // Main Test Sequence
    initial begin
        $dumpfile("tb_schedule_memory.vcd");
        $dumpvars(0, tb_schedule_memory);

        rst_n        = 1'b0;
        mem_wr_en    = 1'b0;
        mem_slot_idx = 4'd0;
        mem_med_id   = 2'd0;
        mem_hour     = 5'd0;
        mem_minute   = 6'd0;
        mem_enable   = 1'b0;
        rd_slot_idx  = 4'd0;

        // ---------------------------------------------------------------------
        // Test 1: Initial Reset State Clears All Enables
        // ---------------------------------------------------------------------
        repeat (3) @(posedge clk);
        #1;
        if (slot_en === 12'h000 && schedule_flat === {NUM_SLOTS*RECORD_W{1'b0}}) begin
            pass_count = pass_count + 1;
            $display("[PASS] 1. Initial reset clears all 12 slot enables and records");
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] 1. Initial reset state non-zero: slot_en=%b", slot_en);
        end

        @(negedge clk);
        rst_n = 1'b1;

        // ---------------------------------------------------------------------
        // Test 2: Write Then Read Across All 12 Slots
        // ---------------------------------------------------------------------
        for (s = 0; s < NUM_SLOTS; s = s + 1) begin
            write_slot(s[3:0], s[1:0], (s + 5'd6), (s * 6'd4 + 6'd5), 1'b1);
        end

        for (s = 0; s < NUM_SLOTS; s = s + 1) begin
            verify_slot(s[3:0], s[1:0], (s + 5'd6), (s * 6'd4 + 6'd5), 1'b1,
                        "2. Write-then-read verification");
        end

        // ---------------------------------------------------------------------
        // Test 3: Overwrite Existing Slot & Verify Neighbor Isolation
        // ---------------------------------------------------------------------
        // Overwrite Slot 4 with new values: med=3, 22:55, en=1
        write_slot(4'd4, 2'd3, 5'd22, 6'd55, 1'b1);
        verify_slot(4'd4, 2'd3, 5'd22, 6'd55, 1'b1, "3a. Overwrite Slot 4 with new time/med");

        // Overwrite Slot 4 to disable it: en=0
        write_slot(4'd4, 2'd3, 5'd22, 6'd55, 1'b0);
        verify_slot(4'd4, 2'd3, 5'd22, 6'd55, 1'b0, "3b. Overwrite Slot 4 to disabled (en=0)");

        // Confirm neighbors Slot 3 and Slot 5 were not altered
        verify_slot(4'd3, 2'd3, 5'd9,  6'd17, 1'b1, "3c. Neighbor Slot 3 undisturbed");
        verify_slot(4'd5, 2'd1, 5'd11, 6'd25, 1'b1, "3d. Neighbor Slot 5 undisturbed");

        // ---------------------------------------------------------------------
        // Test 4: Atomic Write During Continuous Read
        // ---------------------------------------------------------------------
        // Point continuous read at Slot 7 (currently {en=1, med=3, hr=13, min=33})
        rd_slot_idx = 4'd7;
        @(negedge clk);
        mem_wr_en    = 1'b1;
        mem_slot_idx = 4'd7;
        mem_med_id   = 2'd0;
        mem_hour     = 5'd23;
        mem_minute   = 6'd59;
        mem_enable   = 1'b1;

        // 1ns before posedge clk: matcher/reader MUST still see exact old record
        #(CLK_PERIOD / 2 - 1);
        if (schedule_flat[7*RECORD_W +: RECORD_W] === {1'b1, 2'd3, 5'd13, 6'd33} &&
            rd_record === {1'b1, 2'd3, 5'd13, 6'd33}) begin
            pass_count = pass_count + 1;
            $display("[PASS] 4a. Write-during-read pre-edge holds exact old record atomically");
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] 4a. Pre-edge data corrupted before clock edge: %h", rd_record);
        end

        // 1ns after posedge clk: matcher/reader MUST see exact new record
        @(posedge clk);
        #1;
        if (schedule_flat[7*RECORD_W +: RECORD_W] === {1'b1, 2'd0, 5'd23, 6'd59} &&
            rd_record === {1'b1, 2'd0, 5'd23, 6'd59}) begin
            pass_count = pass_count + 1;
            $display("[PASS] 4b. Write-during-read post-edge updates to exact new record atomically");
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] 4b. Post-edge atomic update failed: %h", rd_record);
        end

        @(negedge clk);
        mem_wr_en = 1'b0;

        // ---------------------------------------------------------------------
        // Test 5: Reset Mid-Operation Clears All Enables
        // ---------------------------------------------------------------------
        @(negedge clk);
        rst_n = 1'b0;
        #1;
        if (slot_en === 12'h000 && schedule_flat === {NUM_SLOTS*RECORD_W{1'b0}}) begin
            pass_count = pass_count + 1;
            $display("[PASS] 5. Asynchronous reset clears all 12 populated slots immediately");
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] 5. Reset failed to clear populated slots: slot_en=%b", slot_en);
        end

        @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // ---------------------------------------------------------------------
        // Summary Report
        // ---------------------------------------------------------------------
        $display("==========================================================");
        $display("tb_schedule_memory Summary: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("==========================================================");
        if (fail_count != 0) $finish(1);
        $finish(0);
    end

endmodule
