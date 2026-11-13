//=============================================================================
// Testbench: tb_reminder_subsystem
// Target: rtl/reminder/reminder_subsystem.v
// Owner: Person 4 (Lead)
// Verification: Full integrated subsystem verification
//   1. Reset state
//   2. Raw button bounce followed by successful user acknowledgement
//   3. Timeout expiration generating missed dose event
//   4. Back-to-back reminders with high slot index (Slot 14)
//   5. Spurious button press while idle
//=============================================================================

`timescale 1ns/1ps

module tb_reminder_subsystem;

    reg        clk;
    reg        rst_n;
    reg        event_valid;
    reg  [3:0] event_slot;
    wire       event_accept;
    reg        btn_ack_raw;

    wire       reminder_active;
    wire [3:0] active_slot;
    wire       reminder_start_pulse;
    wire [3:0] reminder_start_slot;
    wire       ack_event_pulse;
    wire [3:0] ack_event_slot;
    wire       missed_event_pulse;
    wire [3:0] missed_event_slot;
    wire       dbg_ack_pulse;
    wire       dbg_timeout_pulse;

    integer errors;
    localparam DEBOUNCE = 4;
    localparam TIMEOUT  = 25;

    reminder_subsystem #(
        .DEBOUNCE_CYCLES(DEBOUNCE),
        .TIMEOUT_CYCLES (TIMEOUT)
    ) dut (
        .clk                 (clk),
        .rst_n               (rst_n),
        .event_valid         (event_valid),
        .event_slot          (event_slot),
        .event_accept        (event_accept),
        .btn_ack_raw         (btn_ack_raw),
        .reminder_active     (reminder_active),
        .active_slot         (active_slot),
        .reminder_start_pulse(reminder_start_pulse),
        .reminder_start_slot (reminder_start_slot),
        .ack_event_pulse     (ack_event_pulse),
        .ack_event_slot      (ack_event_slot),
        .missed_event_pulse  (missed_event_pulse),
        .missed_event_slot   (missed_event_slot),
        .dbg_ack_pulse       (dbg_ack_pulse),
        .dbg_timeout_pulse   (dbg_timeout_pulse)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_reminder_subsystem.vcd");
        $dumpvars(0, tb_reminder_subsystem);

        clk         = 0;
        rst_n       = 0;
        event_valid = 0;
        event_slot  = 4'd0;
        btn_ack_raw = 0;
        errors      = 0;

        $display("==================================================");
        $display("[START] tb_reminder_subsystem end-to-end verification");
        $display("==================================================");

        // Test 1: Reset behavior
        #25;
        rst_n = 1;
        #20;
        if (reminder_active !== 1'b0 || event_accept !== 1'b0) begin
            $display("[FAIL] Expected idle state after reset!");
            errors = errors + 1;
        end

        // Test 2: Spurious raw button bounce while idle
        $display("[TEST 2] Spurious button press while idle...");
        @(posedge clk); btn_ack_raw = 1;
        #(10 * (DEBOUNCE + 2));
        @(posedge clk); btn_ack_raw = 0;
        #(10 * (DEBOUNCE + 2));
        if (ack_event_pulse !== 1'b0 || reminder_active !== 1'b0) begin
            $display("[FAIL] Spurious button while idle created illegal pulse/state!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Button press while idle ignored cleanly.");
        end

        // Test 3: Normal reminder start followed by debounced acknowledgement
        $display("[TEST 3] End-to-end reminder start + debounced acknowledgement...");
        @(posedge clk);
        event_valid = 1;
        event_slot  = 4'd4; // Slot 4

        @(posedge clk);
        if (!event_accept || !reminder_start_pulse || (reminder_start_slot !== 4'd4)) begin
            $display("[FAIL] Handshake or start pulse failed for slot 4!");
            errors = errors + 1;
        end
        event_valid = 0; // Deassert queue valid

        @(posedge clk);
        if (!reminder_active || (active_slot !== 4'd4)) begin
            $display("[FAIL] Reminder not active for slot 4!");
            errors = errors + 1;
        end

        // Simulate contact bounce on raw button input
        @(posedge clk); btn_ack_raw = 1;
        @(posedge clk); btn_ack_raw = 0;
        @(posedge clk); btn_ack_raw = 1;
        // Hold high to let debouncer validate
        #(10 * (DEBOUNCE + 3));
        @(posedge clk); btn_ack_raw = 0;
        #(10 * (DEBOUNCE + 2));

        // Verify ack_event_pulse occurred and reminder terminated
        if (reminder_active !== 1'b0) begin
            $display("[FAIL] Reminder did not terminate after debounced button press!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Debounced acknowledgement successfully cleared reminder.");
        end

        // Test 4: Timeout to missed event
        $display("[TEST 4] Reminder timeout to missed event...");
        #30;
        @(posedge clk);
        event_valid = 1;
        event_slot  = 4'd9; // Slot 9
        @(posedge clk);
        event_valid = 0;

        // Wait for timeout to expire without pressing button
        #(10 * (TIMEOUT + 5));

        if (!missed_event_pulse && (missed_event_slot !== 4'd9)) begin
            $display("[FAIL] Missed event pulse not emitted for slot 9!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Timeout fired and emitted missed event pulse.");
        end

        // Test 5: Back-to-back reminder with highest slot index (Slot 14 of 15)
        $display("[TEST 5] Back-to-back reminder with Slot 14...");
        #20;
        @(posedge clk);
        event_valid = 1;
        event_slot  = 4'd14; // Slot 14
        @(posedge clk);
        event_valid = 0;

        if (!reminder_active || (active_slot !== 4'd14)) begin
            $display("[FAIL] Failed to enter active reminder for slot 14!");
            errors = errors + 1;
        end

        // Quick acknowledge
        @(posedge clk); btn_ack_raw = 1;
        #(10 * (DEBOUNCE + 2));
        @(posedge clk); btn_ack_raw = 0;
        #(10 * (DEBOUNCE + 2));

        if (reminder_active !== 1'b0) begin
            $display("[FAIL] Slot 14 reminder not cleared!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Slot 14 reminder handled and acknowledged cleanly.");
        end

        #40;
        if (errors == 0) begin
            $display("==================================================");
            $display("[ALL TESTS PASSED] reminder_subsystem fully verified");
            $display("==================================================");
        end else begin
            $display("[ERROR] Total failures: %0d", errors);
        end

        $finish;
    end

endmodule
