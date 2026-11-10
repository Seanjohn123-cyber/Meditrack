//=============================================================================
// Testbench: tb_missed_dose_detector
// Target: rtl/reminder/missed_dose_detector.v
// Owner: Person 4 (Lead)
// Verification: Timeout fires once, reminder ends early, immediate new
//               reminder (back-to-back), reset
//=============================================================================

`timescale 1ns/1ps

module tb_missed_dose_detector;

    reg clk;
    reg rst_n;
    reg reminder_active;
    reg reminder_start_pulse;
    wire timeout_pulse;

    integer timeout_pulses_seen;
    integer errors;

    localparam TIMEOUT = 20;

    missed_dose_detector #(
        .TIMEOUT_CYCLES(TIMEOUT)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .reminder_active(reminder_active),
        .reminder_start_pulse(reminder_start_pulse),
        .timeout_pulse(timeout_pulse)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (timeout_pulse) begin
            timeout_pulses_seen = timeout_pulses_seen + 1;
        end
    end

    initial begin
        $dumpfile("tb_missed_dose_detector.vcd");
        $dumpvars(0, tb_missed_dose_detector);

        clk = 0;
        rst_n = 0;
        reminder_active = 0;
        reminder_start_pulse = 0;
        timeout_pulses_seen = 0;
        errors = 0;

        $display("==================================================");
        $display("[START] tb_missed_dose_detector verification");
        $display("==================================================");

        // Test 1: Reset check
        #25;
        rst_n = 1;
        #20;
        if (timeout_pulse !== 1'b0) begin
            $display("[FAIL] Expected timeout_pulse=0 on reset");
            errors = errors + 1;
        end

        // Test 2: Timeout fires exactly once
        $display("[TEST 2] Timeout count up to expiration...");
        timeout_pulses_seen = 0;
        @(posedge clk);
        reminder_active = 1;

        // Wait past timeout threshold
        #(10 * (TIMEOUT + 15));
        if (timeout_pulses_seen !== 1) begin
            $display("[FAIL] Expected exactly 1 timeout pulse, got %0d", timeout_pulses_seen);
            errors = errors + 1;
        end else begin
            $display("[PASS] Timeout fired exactly once at threshold.");
        end

        // Test 3: Reminder ends early (user acknowledged before timeout)
        $display("[TEST 3] Reminder ends early before timeout...");
        @(posedge clk);
        reminder_active = 0; // Reminder ends
        #20;
        timeout_pulses_seen = 0;

        @(posedge clk);
        reminder_active = 1;
        // Run for half the timeout duration (10 cycles out of 20)
        #(10 * 10);
        @(posedge clk);
        reminder_active = 0; // Early acknowledge
        #(10 * 15);
        if (timeout_pulses_seen !== 0) begin
            $display("[FAIL] Premature timeout fired! Count=%0d", timeout_pulses_seen);
            errors = errors + 1;
        end else begin
            $display("[PASS] No timeout emitted when reminder ends early.");
        end

        // Test 4: Back-to-back reminders with immediate restart
        $display("[TEST 4] Back-to-back reminders test...");
        timeout_pulses_seen = 0;
        @(posedge clk);
        reminder_active = 1;
        #(10 * 12); // Partially elapsed

        // Trigger immediate new reminder
        @(posedge clk);
        reminder_start_pulse = 1;
        @(posedge clk);
        reminder_start_pulse = 0;

        // Counter should have reset! Run for 15 cycles (less than full 20)
        #(10 * 15);
        if (timeout_pulses_seen !== 0) begin
            $display("[FAIL] Counter did not reset upon immediate new reminder start!");
            errors = errors + 1;
        end

        // Now run remaining cycles to verify it completes and fires on new reminder
        #(10 * 10);
        if (timeout_pulses_seen !== 1) begin
            $display("[FAIL] Expected 1 timeout after restart, got %0d", timeout_pulses_seen);
            errors = errors + 1;
        end else begin
            $display("[PASS] Back-to-back reminder timer reset cleanly.");
        end

        #50;
        if (errors == 0) begin
            $display("==================================================");
            $display("[ALL TESTS PASSED] missed_dose_detector verified");
            $display("==================================================");
        end else begin
            $display("[ERROR] Total failures: %0d", errors);
        end

        $finish;
    end

endmodule
