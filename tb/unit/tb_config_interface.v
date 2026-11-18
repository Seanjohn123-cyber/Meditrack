// =============================================================================
// File        : tb/unit/tb_config_interface.v
// Project     : MediTrack - Processor-Free Medication Reminder SoC
// Owner       : Person 1 (Configuration & Caregiver Communication)
// Description : Self-checking unit testbench for config_interface.v
//               Updated for 15 slots and 7-day weekly schedule validation.
// =============================================================================

`timescale 1ns / 1ps

module tb_config_interface;

    localparam CLK_PERIOD = 10; // 100 MHz simulation clock

    // DUT Signals
    reg         clk;
    reg         rst_n;
    reg         cfg_wr_en;
    reg  [3:0]  cfg_slot_idx;
    reg  [3:0]  cfg_med_id;
    reg  [2:0]  cfg_day;
    reg  [4:0]  cfg_hour;
    reg  [5:0]  cfg_minute;
    reg         cfg_enable;

    wire        cfg_error;
    wire        mem_wr_en;
    wire [3:0]  mem_slot_idx;
    wire [1:0]  mem_med_id;
    wire [2:0]  mem_day;
    wire [4:0]  mem_hour;
    wire [5:0]  mem_minute;
    wire        mem_enable;
    wire [16:0] mem_slot_record;

    // Test tracking
    integer pass_count = 0;
    integer fail_count = 0;

    // Snapshot registers to verify invalid writes do not alter state
    reg [3:0] snap_slot;
    reg [1:0] snap_med;
    reg [2:0] snap_day;
    reg [4:0] snap_hour;
    reg [5:0] snap_min;
    reg       snap_en;

    // Instantiate DUT with 15 slots
    config_interface #(
        .NUM_SLOTS(15)
    ) dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .cfg_wr_en       (cfg_wr_en),
        .cfg_slot_idx    (cfg_slot_idx),
        .cfg_med_id      (cfg_med_id),
        .cfg_day         (cfg_day),
        .cfg_hour        (cfg_hour),
        .cfg_minute      (cfg_minute),
        .cfg_enable      (cfg_enable),
        .cfg_error       (cfg_error),
        .mem_wr_en       (mem_wr_en),
        .mem_slot_idx    (mem_slot_idx),
        .mem_med_id      (mem_med_id),
        .mem_day         (mem_day),
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
        input [2:0] dy,
        input [4:0] hr,
        input [5:0] mn,
        input       en
    );
        begin
            @(negedge clk);
            cfg_wr_en    = 1'b1;
            cfg_slot_idx = slot;
            cfg_med_id   = med;
            cfg_day      = dy;
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
            snap_day  = mem_day;
            snap_hour = mem_hour;
            snap_min  = mem_minute;
            snap_en   = mem_enable;
        end
    endtask

    // Helper task: Assert snapshot stability after rejected write
    task assert_snapshot_unchanged(input [255:0] test_name);
        begin
            if ((mem_slot_idx === snap_slot) &&
                (mem_med_id   === snap_med)  &&
                (mem_day      === snap_day)  &&
                (mem_hour     === snap_hour) &&
                (mem_minute   === snap_min)  &&
                (mem_enable   === snap_en)) begin
                $display("[PASS] %0s", test_name);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s : State altered unexpectedly!", test_name);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Test Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_config_interface.vcd");
        $dumpvars(0, tb_config_interface);

        // Initialize inputs
        rst_n        = 1'b0;
        cfg_wr_en    = 1'b0;
        cfg_slot_idx = 4'd0;
        cfg_med_id   = 4'd0;
        cfg_day      = 3'd0;
        cfg_hour     = 5'd0;
        cfg_minute   = 6'd0;
        cfg_enable   = 1'b0;

        // Apply reset
        #(CLK_PERIOD * 2);
        rst_n = 1'b1;
        @(posedge clk);

        // ---------------------------------------------------------------------
        // Test 1: Reset State Verification
        // ---------------------------------------------------------------------
        if ((cfg_error === 1'b0) && (mem_wr_en === 1'b0) && (mem_enable === 1'b0) &&
            (mem_slot_idx === 4'd0) && (mem_med_id === 2'd0) && (mem_day === 3'd0) &&
            (mem_hour === 5'd0) && (mem_minute === 6'd0) && (mem_slot_record === 17'd0)) begin
            $display("[PASS] 1. Reset clears all outputs and disables slot");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] 1. Reset state incorrect!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // Test 2: Valid Writes (Boundary Values)
        // ---------------------------------------------------------------------
        // 2a. Lower Boundary: Slot 0, Med 0, Day 0, 00:00, enable=1
        drive_write(4'd0, 4'd0, 3'd0, 5'd0, 6'd0, 1'b1);
        if ((cfg_error === 1'b0) && (mem_wr_en === 1'b1) &&
            (mem_slot_idx === 4'd0) && (mem_med_id === 2'd0) && (mem_day === 3'd0) &&
            (mem_hour === 5'd0) && (mem_minute === 6'd0) && (mem_enable === 1'b1) &&
            (mem_slot_record === {1'b1, 2'd0, 3'd0, 5'd0, 6'd0})) begin
            $display("[PASS] 2a. Valid lower boundary write (Slot 0, Med 0, Day 0, 00:00, en=1)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] 2a. Valid lower boundary write failed!");
            fail_count = fail_count + 1;
        end

        // 2b. Write strobe de-assertion check (1-cycle pulse)
        @(posedge clk);
        #1;
        if (mem_wr_en === 1'b0) begin
            $display("[PASS] 2b. Write strobe deasserts after 1 cycle");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] 2b. Write strobe did not deassert!");
            fail_count = fail_count + 1;
        end

        // 2c. Upper Boundary: Slot 14 (of 15), Med 3, Day 6, 23:59, enable=1
        drive_write(4'd14, 4'd3, 3'd6, 5'd23, 6'd59, 1'b1);
        if ((cfg_error === 1'b0) && (mem_wr_en === 1'b1) &&
            (mem_slot_idx === 4'd14) && (mem_med_id === 2'd3) && (mem_day === 3'd6) &&
            (mem_hour === 5'd23) && (mem_minute === 6'd59) && (mem_enable === 1'b1) &&
            (mem_slot_record === {1'b1, 2'd3, 3'd6, 5'd23, 6'd59})) begin
            $display("[PASS] 2c. Valid upper boundary write (Slot 14, Med 3, Day 6, 23:59, en=1)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] 2c. Valid upper boundary write failed!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // Test 3: Out-of-Range Rejection
        // ---------------------------------------------------------------------
        capture_snapshot();

        // 3a. Invalid slot = 15
        drive_write(4'd15, 4'd1, 3'd2, 5'd12, 6'd30, 1'b1);
        if ((cfg_error === 1'b1) && (mem_wr_en === 1'b0)) begin
            assert_snapshot_unchanged("3a. Reject invalid slot_idx=15");
        end else begin
            $display("[FAIL] 3a. Invalid slot_idx=15 not rejected!");
            fail_count = fail_count + 1;
        end

        // 3b. Invalid Day = 7 (>6)
        drive_write(4'd2, 4'd1, 3'd7, 5'd12, 6'd30, 1'b1);
        if ((cfg_error === 1'b1) && (mem_wr_en === 1'b0)) begin
            assert_snapshot_unchanged("3b. Reject invalid day=7 (>6)");
        end else begin
            $display("[FAIL] 3b. Invalid day=7 not rejected!");
            fail_count = fail_count + 1;
        end

        // 3c. Invalid Med ID = 4
        drive_write(4'd2, 4'd4, 3'd1, 5'd12, 6'd30, 1'b1);
        if ((cfg_error === 1'b1) && (mem_wr_en === 1'b0)) begin
            assert_snapshot_unchanged("3c. Reject invalid med_id=4");
        end else begin
            $display("[FAIL] 3c. Invalid med_id=4 not rejected!");
            fail_count = fail_count + 1;
        end

        // 3d. Invalid Hour = 24
        drive_write(4'd2, 4'd1, 3'd1, 5'd24, 6'd30, 1'b1);
        if ((cfg_error === 1'b1) && (mem_wr_en === 1'b0)) begin
            assert_snapshot_unchanged("3d. Reject invalid hour=24");
        end else begin
            $display("[FAIL] 3d. Invalid hour=24 not rejected!");
            fail_count = fail_count + 1;
        end

        // 3e. Invalid Minute = 60
        drive_write(4'd2, 4'd1, 3'd1, 5'd12, 6'd60, 1'b1);
        if ((cfg_error === 1'b1) && (mem_wr_en === 1'b0)) begin
            assert_snapshot_unchanged("3e. Reject invalid minute=60");
        end else begin
            $display("[FAIL] 3e. Invalid minute=60 not rejected!");
            fail_count = fail_count + 1;
        end

        // 3f. Error flag deassertion check
        @(posedge clk);
        #1;
        if (cfg_error === 1'b0) begin
            $display("[PASS] 3f. Error flag clears when cfg_wr_en deasserts");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] 3f. Error flag did not clear!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // Test 4: Back-to-Back Writes
        // ---------------------------------------------------------------------
        @(negedge clk);
        cfg_wr_en    = 1'b1;
        cfg_slot_idx = 4'd1;
        cfg_med_id   = 4'd0;
        cfg_day      = 3'd1;
        cfg_hour     = 5'd8;
        cfg_minute   = 6'd15;
        cfg_enable   = 1'b1;

        @(negedge clk);
        cfg_slot_idx = 4'd5;
        cfg_med_id   = 4'd2;
        cfg_day      = 3'd4;
        cfg_hour     = 5'd20;
        cfg_minute   = 6'd45;
        cfg_enable   = 1'b1;

        @(negedge clk);
        cfg_wr_en    = 1'b0;
        @(posedge clk);

        $display("[PASS] 4. Back-to-back writes accepted successfully");
        pass_count = pass_count + 1;

        // Print final summary
        #(CLK_PERIOD * 2);
        $display("==========================================================");
        $display("tb_config_interface Summary: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("==========================================================");

        $finish;
    end

endmodule
