// =============================================================================
// File        : tb/unit/tb_config_interface.v
// Project     : MediTrack - Processor-Free Medication Reminder SoC
// Owner       : Person 1 (Configuration & Caregiver Communication)
// Description : Self-checking unit testbench for config_interface.v
// =============================================================================

`timescale 1ns / 1ps

module tb_config_interface;

    // Parameters
    localparam CLK_PERIOD = 10; // 100 MHz simulation clock

    // DUT Signals
    reg         clk;
    reg         rst_n;
    reg         cfg_wr_en;
    reg  [3:0]  cfg_slot_idx;
    reg  [3:0]  cfg_med_id;
    reg  [4:0]  cfg_hour;
    reg  [5:0]  cfg_minute;
    reg         cfg_enable;

    wire        cfg_error;
    wire        mem_wr_en;
    wire [3:0]  mem_slot_idx;
    wire [1:0]  mem_med_id;
    wire [4:0]  mem_hour;
    wire [5:0]  mem_minute;
    wire        mem_enable;
    wire [13:0] mem_slot_record;

    // Test tracking
    integer pass_count = 0;
    integer fail_count = 0;

    // Snapshot registers to verify invalid writes do not alter state
    reg [3:0] snap_slot;
    reg [1:0] snap_med;
    reg [4:0] snap_hour;
    reg [5:0] snap_min;
    reg       snap_en;

    // Instantiate DUT
    config_interface dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .cfg_wr_en       (cfg_wr_en),
        .cfg_slot_idx    (cfg_slot_idx),
        .cfg_med_id      (cfg_med_id),
        .cfg_hour        (cfg_hour),
        .cfg_minute      (cfg_minute),
        .cfg_enable      (cfg_enable),
        .cfg_error       (cfg_error),
        .mem_wr_en       (mem_wr_en),
        .mem_slot_idx    (mem_slot_idx),
        .mem_med_id      (mem_med_id),
        .mem_hour        (mem_hour),
        .mem_minute      (mem_minute),
        .mem_enable      (mem_enable),
        .mem_slot_record (mem_slot_record)
    );

    // Clock Generator
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Helper task: Drive a single 1-cycle write request
    task drive_write(
        input [3:0] slot,
        input [3:0] med,
        input [4:0] hr,
        input [5:0] mn,
        input       en
    );
        begin
            @(negedge clk);
            cfg_wr_en    = 1'b1;
            cfg_slot_idx = slot;
            cfg_med_id   = med;
            cfg_hour     = hr;
            cfg_minute   = mn;
            cfg_enable   = en;
            @(negedge clk);
            cfg_wr_en    = 1'b0;
        end
    endtask

    // Helper task: Capture current mem_* outputs
    task capture_snapshot;
        begin
            snap_slot = mem_slot_idx;
            snap_med  = mem_med_id;
            snap_hour = mem_hour;
            snap_min  = mem_minute;
            snap_en   = mem_enable;
        end
    endtask

    // Helper task: Check expected outputs 1ns after posedge clk
    task check_result(
        input        exp_wr_en,
        input        exp_err,
        input [3:0]  exp_slot,
        input [1:0]  exp_med,
        input [4:0]  exp_hr,
        input [5:0]  exp_mn,
        input        exp_en,
        input [80*8:1] test_name
    );
        begin
            if (mem_wr_en    === exp_wr_en &&
                cfg_error    === exp_err   &&
                mem_slot_idx === exp_slot  &&
                mem_med_id   === exp_med   &&
                mem_hour     === exp_hr    &&
                mem_minute   === exp_mn    &&
                mem_enable   === exp_en    &&
                mem_slot_record === {exp_en, exp_med, exp_hr, exp_mn}) begin
                pass_count = pass_count + 1;
                $display("[PASS] %0s", test_name);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s | Got wr=%b err=%b slot=%0d med=%0d %02d:%02d en=%b | Exp wr=%b err=%b slot=%0d med=%0d %02d:%02d en=%b",
                         test_name,
                         mem_wr_en, cfg_error, mem_slot_idx, mem_med_id, mem_hour, mem_minute, mem_enable,
                         exp_wr_en, exp_err, exp_slot, exp_med, exp_hr, exp_mn, exp_en);
            end
        end
    endtask

    // Main Stimulus Sequence
    initial begin
        $dumpfile("tb_config_interface.vcd");
        $dumpvars(0, tb_config_interface);

        // Initialize inputs
        rst_n        = 1'b0;
        cfg_wr_en    = 1'b0;
        cfg_slot_idx = 4'd0;
        cfg_med_id   = 4'd0;
        cfg_hour     = 5'd0;
        cfg_minute   = 6'd0;
        cfg_enable   = 1'b0;

        // ---------------------------------------------------------------------
        // Test 1: Reset State Verification
        // ---------------------------------------------------------------------
        repeat (3) @(posedge clk);
        #1;
        check_result(1'b0, 1'b0, 4'd0, 2'd0, 5'd0, 6'd0, 1'b0, "1. Reset clears all outputs and disables slot");

        @(negedge clk);
        rst_n = 1'b1;

        // ---------------------------------------------------------------------
        // Test 2: Valid Writes (Lower & Upper Boundaries)
        // ---------------------------------------------------------------------
        // Lower boundary: Slot 0, Med 0, 00:00, Enable = 1
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_slot_idx = 4'd0; cfg_med_id = 4'd0;
        cfg_hour  = 5'd0; cfg_minute   = 6'd0; cfg_enable = 1'b1;
        @(posedge clk); #1;
        check_result(1'b1, 1'b0, 4'd0, 2'd0, 5'd0, 6'd0, 1'b1, "2a. Valid lower boundary write (Slot 0, Med 0, 00:00, en=1)");

        @(negedge clk);
        cfg_wr_en = 1'b0;
        @(posedge clk); #1;
        check_result(1'b0, 1'b0, 4'd0, 2'd0, 5'd0, 6'd0, 1'b1, "2b. Write strobe deasserts after 1 cycle");

        // Upper boundary: Slot 11, Med 3, 23:59, Enable = 1
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_slot_idx = 4'd11; cfg_med_id = 4'd3;
        cfg_hour  = 5'd23; cfg_minute  = 6'd59; cfg_enable = 1'b1;
        @(posedge clk); #1;
        check_result(1'b1, 1'b0, 4'd11, 2'd3, 5'd23, 6'd59, 1'b1, "2c. Valid upper boundary write (Slot 11, Med 3, 23:59, en=1)");
        capture_snapshot();

        @(negedge clk);
        cfg_wr_en = 1'b0;

        // ---------------------------------------------------------------------
        // Test 3: Out-of-Range Field Rejections (Must preserve snapshot)
        // ---------------------------------------------------------------------
        // 3a: Invalid Slot Index (12)
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_slot_idx = 4'd12; cfg_med_id = 4'd1;
        cfg_hour  = 5'd8; cfg_minute   = 6'd30; cfg_enable = 1'b0;
        @(posedge clk); #1;
        check_result(1'b0, 1'b1, snap_slot, snap_med, snap_hour, snap_min, snap_en, "3a. Reject invalid slot_idx=12");

        // 3b: Invalid Slot Index (15)
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_slot_idx = 4'd15;
        @(posedge clk); #1;
        check_result(1'b0, 1'b1, snap_slot, snap_med, snap_hour, snap_min, snap_en, "3b. Reject invalid slot_idx=15");

        // 3c: Invalid Medication ID (4)
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_slot_idx = 4'd2; cfg_med_id = 4'd4;
        cfg_hour  = 5'd8; cfg_minute   = 6'd30; cfg_enable = 1'b1;
        @(posedge clk); #1;
        check_result(1'b0, 1'b1, snap_slot, snap_med, snap_hour, snap_min, snap_en, "3c. Reject invalid med_id=4");

        // 3d: Invalid Medication ID (15)
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_med_id = 4'd15;
        @(posedge clk); #1;
        check_result(1'b0, 1'b1, snap_slot, snap_med, snap_hour, snap_min, snap_en, "3d. Reject invalid med_id=15");

        // 3e: Invalid Hour (24)
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_slot_idx = 4'd3; cfg_med_id = 4'd2;
        cfg_hour  = 5'd24; cfg_minute  = 6'd15; cfg_enable = 1'b1;
        @(posedge clk); #1;
        check_result(1'b0, 1'b1, snap_slot, snap_med, snap_hour, snap_min, snap_en, "3e. Reject invalid hour=24");

        // 3f: Invalid Hour (31)
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_hour = 5'd31;
        @(posedge clk); #1;
        check_result(1'b0, 1'b1, snap_slot, snap_med, snap_hour, snap_min, snap_en, "3f. Reject invalid hour=31");

        // 3g: Invalid Minute (60)
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_slot_idx = 4'd4; cfg_med_id = 4'd1;
        cfg_hour  = 5'd12; cfg_minute  = 6'd60; cfg_enable = 1'b1;
        @(posedge clk); #1;
        check_result(1'b0, 1'b1, snap_slot, snap_med, snap_hour, snap_min, snap_en, "3g. Reject invalid minute=60");

        // 3h: Invalid Minute (63)
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_minute = 6'd63;
        @(posedge clk); #1;
        check_result(1'b0, 1'b1, snap_slot, snap_med, snap_hour, snap_min, snap_en, "3h. Reject invalid minute=63");

        @(negedge clk);
        cfg_wr_en = 1'b0;
        @(posedge clk); #1;
        check_result(1'b0, 1'b0, snap_slot, snap_med, snap_hour, snap_min, snap_en, "3i. Error flag clears when cfg_wr_en deasserts");

        // ---------------------------------------------------------------------
        // Test 4: Back-to-Back Writes (Valid -> Valid -> Invalid -> Valid)
        // ---------------------------------------------------------------------
        // Cycle 1: Valid Write (Slot 1, Med 1, 07:30, en=1)
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_slot_idx = 4'd1; cfg_med_id = 4'd1;
        cfg_hour  = 5'd7; cfg_minute   = 6'd30; cfg_enable = 1'b1;
        @(posedge clk); #1;
        check_result(1'b1, 1'b0, 4'd1, 2'd1, 5'd7, 6'd30, 1'b1, "4a. Back-to-back Cycle 1 (Valid Slot 1)");

        // Cycle 2: Immediate Valid Write (Slot 5, Med 2, 14:45, en=1)
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_slot_idx = 4'd5; cfg_med_id = 4'd2;
        cfg_hour  = 5'd14; cfg_minute  = 6'd45; cfg_enable = 1'b1;
        @(posedge clk); #1;
        check_result(1'b1, 1'b0, 4'd5, 2'd2, 5'd14, 6'd45, 1'b1, "4b. Back-to-back Cycle 2 (Valid Slot 5)");

        // Cycle 3: Immediate Invalid Write (Slot 13 -> out of range)
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_slot_idx = 4'd13; cfg_med_id = 4'd0;
        cfg_hour  = 5'd9; cfg_minute   = 6'd0;  cfg_enable = 1'b0;
        @(posedge clk); #1;
        check_result(1'b0, 1'b1, 4'd5, 2'd2, 5'd14, 6'd45, 1'b1, "4c. Back-to-back Cycle 3 (Invalid Slot 13 rejected, Slot 5 held)");

        // Cycle 4: Immediate Valid Write (Slot 5 disabled)
        @(negedge clk);
        cfg_wr_en = 1'b1; cfg_slot_idx = 4'd5; cfg_med_id = 4'd2;
        cfg_hour  = 5'd14; cfg_minute  = 6'd45; cfg_enable = 1'b0;
        @(posedge clk); #1;
        check_result(1'b1, 1'b0, 4'd5, 2'd2, 5'd14, 6'd45, 1'b0, "4d. Back-to-back Cycle 4 (Valid Slot 5 disable)");

        @(negedge clk);
        cfg_wr_en = 1'b0;
        repeat (2) @(posedge clk);

        // ---------------------------------------------------------------------
        // Summary Report
        // ---------------------------------------------------------------------
        $display("==========================================================");
        $display("tb_config_interface Summary: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("==========================================================");
        if (fail_count != 0) $finish(1);
        $finish(0);
    end

endmodule
