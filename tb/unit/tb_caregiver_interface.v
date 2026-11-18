// =============================================================================
// File        : tb/unit/tb_caregiver_interface.v
// Project     : MediTrack - Processor-Free Medication Reminder SoC
// Owner       : Person 1 (Configuration & Caregiver Communication)
// Description : Self-checking unit testbench for caregiver_interface.v
//               Tests:
//                 1. Reset state initialization
//                 2. Prolonged backpressure (comm_ready=0 for many cycles,
//                    verifying comm_valid and payload stability)
//                 3. Burst of three records (START, ACK, MISSED)
//                 4. comm_ready toggling handshake
//                 5. FIFO full overflow (drop & flag without corrupting in-flight data)
//                 6. Reset mid-transfer
// =============================================================================

`timescale 1ns / 1ps

module tb_caregiver_interface;

    localparam integer FIFO_DEPTH = 8;
    localparam integer PAYLOAD_W  = 17;
    localparam integer CLK_PERIOD = 10;

    localparam [1:0] EVT_START  = 2'b00;
    localparam [1:0] EVT_ACK    = 2'b01;
    localparam [1:0] EVT_MISSED = 2'b10;

    // DUT Signals
    reg                  clk;
    reg                  rst_n;
    reg                  reminder_start_pulse;
    reg  [3:0]           reminder_start_slot;
    reg                  ack_event_pulse;
    reg  [3:0]           ack_event_slot;
    reg                  missed_event_pulse;
    reg  [3:0]           missed_event_slot;
    reg  [4:0]           cur_hour;
    reg  [5:0]           cur_minute;

    wire                 comm_valid;
    reg                  comm_ready;
    wire [PAYLOAD_W-1:0] payload;

    wire                 fifo_empty;
    wire                 fifo_full;
    wire [3:0]           fifo_count;
    wire                 fifo_overflow_pulse;
    wire                 fifo_overflow;
    wire [7:0]           overflow_count;

    integer pass_count = 0;
    integer fail_count = 0;
    integer c;
    reg [PAYLOAD_W-1:0] expected_payload;
    reg                 stable_ok;

    // Instantiate DUT
    caregiver_interface #(
        .FIFO_DEPTH (FIFO_DEPTH),
        .PTR_W      (3),
        .CNT_W      (4),
        .SLOT_WIDTH (4),
        .PAYLOAD_W  (PAYLOAD_W)
    ) dut (
        .clk                  (clk),
        .rst_n                (rst_n),
        .reminder_start_pulse (reminder_start_pulse),
        .reminder_start_slot  (reminder_start_slot),
        .ack_event_pulse      (ack_event_pulse),
        .ack_event_slot       (ack_event_slot),
        .missed_event_pulse   (missed_event_pulse),
        .missed_event_slot    (missed_event_slot),
        .cur_hour             (cur_hour),
        .cur_minute           (cur_minute),
        .comm_valid           (comm_valid),
        .comm_ready           (comm_ready),
        .payload              (payload),
        .fifo_empty           (fifo_empty),
        .fifo_full            (fifo_full),
        .fifo_count           (fifo_count),
        .fifo_overflow_pulse  (fifo_overflow_pulse),
        .fifo_overflow        (fifo_overflow),
        .overflow_count       (overflow_count)
    );

    // Clock Generator
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Helper Task: Clear all event inputs
    task clear_pulses;
        begin
            reminder_start_pulse = 1'b0;
            reminder_start_slot  = 4'd0;
            ack_event_pulse      = 1'b0;
            ack_event_slot       = 4'd0;
            missed_event_pulse   = 1'b0;
            missed_event_slot    = 4'd0;
        end
    endtask

    // Helper Task: Drive a 1-cycle canonical event pulse
    task push_event(
        input [1:0] ev_type,
        input [3:0] slot,
        input [4:0] hr,
        input [5:0] mn
    );
        begin
            @(negedge clk);
            clear_pulses();
            cur_hour   = hr;
            cur_minute = mn;
            case (ev_type)
                EVT_START: begin
                    reminder_start_pulse = 1'b1;
                    reminder_start_slot  = slot;
                end
                EVT_ACK: begin
                    ack_event_pulse = 1'b1;
                    ack_event_slot  = slot;
                end
                EVT_MISSED: begin
                    missed_event_pulse = 1'b1;
                    missed_event_slot  = slot;
                end
            endcase
            @(posedge clk);
            #1;
            @(negedge clk);
            clear_pulses();
        end
    endtask

    // Helper Task: Pop and verify front record on valid && ready
    task pop_and_check(
        input [1:0]      exp_type,
        input [3:0]      exp_slot,
        input [4:0]      exp_hr,
        input [5:0]      exp_mn,
        input [80*8:1]   label
    );
        reg [PAYLOAD_W-1:0] exp_rec;
        begin
            exp_rec = {exp_type, exp_slot, exp_hr, exp_mn};
            @(negedge clk);
            if (comm_valid === 1'b1 && payload === exp_rec) begin
                pass_count = pass_count + 1;
                $display("[PASS] %0s | payload={type=%b, slot=%0d, %02d:%02d}",
                         label, payload[16:15], payload[14:11], payload[10:6], payload[5:0]);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s | Got valid=%b payload=%h | Exp valid=1 payload=%h",
                         label, comm_valid, payload, exp_rec);
            end
            comm_ready = 1'b1;
            @(posedge clk);
            #1;
            @(negedge clk);
            comm_ready = 1'b0;
        end
    endtask

    // Main Verification Sequence
    initial begin
        $dumpfile("tb_caregiver_interface.vcd");
        $dumpvars(0, tb_caregiver_interface);

        rst_n      = 1'b0;
        comm_ready = 1'b0;
        cur_hour   = 5'd0;
        cur_minute = 6'd0;
        clear_pulses();

        // ---------------------------------------------------------------------
        // Test 1: Reset State Verification
        // ---------------------------------------------------------------------
        repeat (3) @(posedge clk);
        #1;
        if (comm_valid === 1'b0 && fifo_empty === 1'b1 && fifo_full === 1'b0 &&
            fifo_count === 4'd0 && fifo_overflow === 1'b0 && overflow_count === 8'd0) begin
            pass_count = pass_count + 1;
            $display("[PASS] 1. Reset initializes FIFO empty and comm_valid=0");
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] 1. Reset state mismatch");
        end

        @(negedge clk);
        rst_n = 1'b1;

        // ---------------------------------------------------------------------
        // Test 2: comm_ready Low for Many Cycles (Payload Stability Under Backpressure)
        // ---------------------------------------------------------------------
        comm_ready = 1'b0;
        push_event(EVT_START, 4'd3, 5'd8, 6'd15);
        expected_payload = {EVT_START, 4'd3, 5'd8, 6'd15};

        // Hold comm_ready low for 15 clock cycles while changing cur_hour/cur_minute
        stable_ok = 1'b1;
        for (c = 0; c < 15; c = c + 1) begin
            @(negedge clk);
            cur_hour   = c[4:0]; // Attempt to perturb live timestamp inputs
            cur_minute = c[5:0];
            @(posedge clk);
            #1;
            if (comm_valid !== 1'b1 || payload !== expected_payload) begin
                stable_ok = 1'b0;
            end
        end

        if (stable_ok) begin
            pass_count = pass_count + 1;
            $display("[PASS] 2a. comm_valid and payload held stable across 15 stalled cycles");
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] 2a. Payload or comm_valid glitched while comm_ready=0");
        end

        pop_and_check(EVT_START, 4'd3, 5'd8, 6'd15, "2b. Stalled record accepted cleanly on comm_ready=1");

        if (comm_valid === 1'b0 && fifo_empty === 1'b1) begin
            pass_count = pass_count + 1;
            $display("[PASS] 2c. comm_valid deasserts immediately after last record accepted");
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] 2c. FIFO did not empty after pop");
        end

        // ---------------------------------------------------------------------
        // Test 3: Back-to-Back Burst of Three Records (START -> ACK -> MISSED)
        // ---------------------------------------------------------------------
        @(negedge clk);
        comm_ready = 1'b0;
        // Cycle 1: START on Slot 2 at 09:00
        clear_pulses();
        reminder_start_pulse = 1'b1; reminder_start_slot = 4'd2;
        cur_hour = 5'd9; cur_minute = 6'd0;
        @(negedge clk);
        // Cycle 2: ACK on Slot 2 at 09:01
        clear_pulses();
        ack_event_pulse = 1'b1; ack_event_slot = 4'd2;
        cur_hour = 5'd9; cur_minute = 6'd1;
        @(negedge clk);
        // Cycle 3: MISSED on Slot 5 at 09:30
        clear_pulses();
        missed_event_pulse = 1'b1; missed_event_slot = 4'd5;
        cur_hour = 5'd9; cur_minute = 6'd30;
        @(negedge clk);
        clear_pulses();

        if (fifo_count === 4'd3 && comm_valid === 1'b1) begin
            pass_count = pass_count + 1;
            $display("[PASS] 3a. Burst of 3 back-to-back events buffered (fifo_count=3)");
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] 3a. Burst count mismatch: fifo_count=%0d", fifo_count);
        end

        // Drain the 3 burst records using toggling comm_ready
        // ---------------------------------------------------------------------
        // Test 4: comm_ready Toggling Between Transfers
        // ---------------------------------------------------------------------
        pop_and_check(EVT_START,  4'd2, 5'd9, 6'd0,  "4a. Drain burst record 1 (START) with ready toggle");
        repeat (2) @(posedge clk); // comm_ready=0 pause
        pop_and_check(EVT_ACK,    4'd2, 5'd9, 6'd1,  "4b. Drain burst record 2 (ACK) with ready toggle");
        repeat (3) @(posedge clk); // comm_ready=0 pause
        pop_and_check(EVT_MISSED, 4'd5, 5'd9, 6'd30, "4c. Drain burst record 3 (MISSED) with ready toggle");

        // ---------------------------------------------------------------------
        // Test 5: FIFO Full & Overflow Behaviour (No In-Flight Corruption)
        // ---------------------------------------------------------------------
        comm_ready = 1'b0;
        for (c = 0; c < FIFO_DEPTH; c = c + 1) begin
            push_event(EVT_START, c[3:0], (5'd10 + c[4:0]), (6'd10 + c[5:0]));
        end

        if (fifo_full === 1'b1 && fifo_count === 4'd8 && fifo_overflow === 1'b0) begin
            pass_count = pass_count + 1;
            $display("[PASS] 5a. FIFO reached full capacity (8 records) with zero overflow");
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] 5a. FIFO full state incorrect: full=%b count=%0d", fifo_full, fifo_count);
        end

        // Attempt to push 2 extra records while FIFO is full
        expected_payload = {EVT_START, 4'd0, 5'd10, 6'd10}; // Head record in flight
        @(negedge clk);
        missed_event_pulse = 1'b1; missed_event_slot = 4'd11;
        cur_hour = 5'd22; cur_minute = 6'd59;
        @(posedge clk);
        #1;
        if (fifo_overflow_pulse === 1'b1 && fifo_overflow === 1'b1 &&
            overflow_count === 8'd1 && payload === expected_payload) begin
            pass_count = pass_count + 1;
            $display("[PASS] 5b. Overflow #1 flagged and dropped; head payload in flight untouched");
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] 5b. Overflow #1 handling failed");
        end

        @(negedge clk);
        ack_event_pulse = 1'b1; ack_event_slot = 4'd9;
        missed_event_pulse = 1'b0;
        @(posedge clk);
        #1;
        if (fifo_overflow_pulse === 1'b1 && overflow_count === 8'd2 && payload === expected_payload) begin
            pass_count = pass_count + 1;
            $display("[PASS] 5c. Overflow #2 counted (overflow_count=2); head payload still intact");
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] 5c. Overflow #2 handling failed: count=%0d", overflow_count);
        end
        @(negedge clk);
        clear_pulses();

        // Drain all 8 records and verify none were corrupted by the overflow attempts
        for (c = 0; c < FIFO_DEPTH; c = c + 1) begin
            pop_and_check(EVT_START, c[3:0], (5'd10 + c[4:0]), (6'd10 + c[5:0]),
                          "5d. Verify intact FIFO record after overflow");
        end

        // ---------------------------------------------------------------------
        // Test 6: Reset Mid-Transfer
        // ---------------------------------------------------------------------
        comm_ready = 1'b0;
        push_event(EVT_MISSED, 4'd7, 5'd18, 6'd45);
        push_event(EVT_ACK,    4'd8, 5'd18, 6'd46);

        // Confirm transfer is active on the link (comm_valid=1, comm_ready=0)
        if (comm_valid === 1'b1 && fifo_count === 4'd2) begin
            // Assert asynchronous reset mid-transfer
            @(negedge clk);
            rst_n = 1'b0;
            #1;
            if (comm_valid === 1'b0 && payload === {PAYLOAD_W{1'b0}} &&
                fifo_empty === 1'b1 && fifo_count === 4'd0 &&
                fifo_overflow === 1'b0 && overflow_count === 8'd0) begin
                pass_count = pass_count + 1;
                $display("[PASS] 6. Reset mid-transfer cleanly aborts transfer and clears FIFO/flags");
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] 6. Reset mid-transfer left residual state");
            end
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] 6. Mid-transfer setup failed");
        end

        @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // ---------------------------------------------------------------------
        // Summary Report
        // ---------------------------------------------------------------------
        $display("==========================================================");
        $display("tb_caregiver_interface Summary: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("==========================================================");
        if (fail_count != 0) $finish(1);
        $finish(0);
    end

endmodule
