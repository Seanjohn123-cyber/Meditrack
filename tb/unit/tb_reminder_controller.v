//=============================================================================
// Testbench: tb_reminder_controller
// Target: rtl/reminder/reminder_controller.v
// Owner: Person 4 (Lead)
// Verification:
//   1. Reset state
//   2. Normal acknowledgement path
//   3. Timeout to missed event path
//   4. CRITICAL: Same-edge ack_pulse & timeout_pulse collision (Ack wins!)
//   5. Spurious ack_pulse while idle is ignored
//   6. Queue event arriving during active reminder is blocked
//   7. Back-to-back reminders sequence
//=============================================================================

`timescale 1ns/1ps

module tb_reminder_controller;

    reg        clk;
    reg        rst_n;
    reg        event_valid;
    reg  [3:0] event_slot;
    wire       event_accept;
    reg        ack_pulse;
    reg        timeout_pulse;

    wire       reminder_active;
    wire [3:0] active_slot;
    wire       reminder_start_pulse;
    wire [3:0] reminder_start_slot;
    wire       ack_event_pulse;
    wire [3:0] ack_event_slot;
    wire       missed_event_pulse;
    wire [3:0] missed_event_slot;

    integer errors;

    reminder_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .event_valid(event_valid),
        .event_slot(event_slot),
        .event_accept(event_accept),
        .ack_pulse(ack_pulse),
        .timeout_pulse(timeout_pulse),
        .reminder_active(reminder_active),
        .active_slot(active_slot),
        .reminder_start_pulse(reminder_start_pulse),
        .reminder_start_slot(reminder_start_slot),
        .ack_event_pulse(ack_event_pulse),
        .ack_event_slot(ack_event_slot),
        .missed_event_pulse(missed_event_pulse),
        .missed_event_slot(missed_event_slot)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_reminder_controller.vcd");
        $dumpvars(0, tb_reminder_controller);

        clk = 0;
        rst_n = 0;
        event_valid = 0;
        event_slot = 4'd0;
        ack_pulse = 0;
        timeout_pulse = 0;
        errors = 0;

        $display("==================================================");
        $display("[START] tb_reminder_controller verification");
        $display("==================================================");

        // Test 1: Reset behavior
        #25;
        rst_n = 1;
        #20;
        if (reminder_active !== 1'b0 || event_accept !== 1'b0) begin
            $display("[FAIL] Idle state not 0 after reset!");
            errors = errors + 1;
        end

        // Test 2: Ack while idle is ignored
        $display("[TEST 2] Spurious ack while idle...");
        @(posedge clk);
        ack_pulse = 1;
        @(posedge clk);
        ack_pulse = 0;
        #10;
        if (ack_event_pulse !== 1'b0 || reminder_active !== 1'b0) begin
            $display("[FAIL] Ack while idle generated illegal pulse or state transition!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Ack while idle ignored cleanly.");
        end

        // Test 3: Normal reminder start & acknowledgement
        $display("[TEST 3] Normal acknowledgement sequence...");
        @(posedge clk);
        event_valid = 1;
        event_slot  = 4'd5; // Slot 5

        @(posedge clk);
        // On accept cycle, event_accept and reminder_start_pulse must be 1
        if (!event_accept || !reminder_start_pulse || (reminder_start_slot !== 4'd5)) begin
            $display("[FAIL] Handshake or start pulse failed! accept=%b, start=%b, slot=%0d",
                     event_accept, reminder_start_pulse, reminder_start_slot);
            errors = errors + 1;
        end
        event_valid = 0; // Queue removed event

        @(posedge clk);
        if (!reminder_active || (active_slot !== 4'd5)) begin
            $display("[FAIL] reminder_active not asserted or wrong slot! active=%b, slot=%0d",
                     reminder_active, active_slot);
            errors = errors + 1;
        end

        // User acknowledges after 3 cycles
        repeat (3) @(posedge clk);
        ack_pulse = 1;
        @(posedge clk);
        ack_pulse = 0;

        // Verify ack_event_pulse emitted
        if (!ack_event_pulse || (ack_event_slot !== 4'd5)) begin
            $display("[FAIL] ack_event_pulse not emitted properly!");
            errors = errors + 1;
        end
        @(posedge clk);
        if (reminder_active !== 1'b0) begin
            $display("[FAIL] reminder_active did not clear after acknowledgement!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Normal acknowledgement verified.");
        end

        // Test 4: Timeout to missed event
        $display("[TEST 4] Timeout to missed event sequence...");
        #20;
        @(posedge clk);
        event_valid = 1;
        event_slot  = 4'd2; // Slot 2
        @(posedge clk);
        event_valid = 0;
        @(posedge clk);

        // Simulate timeout pulse
        repeat (4) @(posedge clk);
        timeout_pulse = 1;
        @(posedge clk);
        timeout_pulse = 0;

        if (!missed_event_pulse || (missed_event_slot !== 4'd2)) begin
            $display("[FAIL] missed_event_pulse not emitted properly!");
            errors = errors + 1;
        end
        @(posedge clk);
        if (reminder_active !== 1'b0) begin
            $display("[FAIL] reminder_active did not clear after timeout!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Timeout to missed event verified.");
        end

        // Test 5: CRITICAL PRIORITY RULE - Same edge ack and timeout
        $display("[TEST 5] CRITICAL PRIORITY: Same-edge ack and timeout...");
        #20;
        @(posedge clk);
        event_valid = 1;
        event_slot  = 4'd8; // Slot 8
        @(posedge clk);
        event_valid = 0;
        @(posedge clk);

        // Assert both ack_pulse and timeout_pulse on the EXACT same clock cycle!
        @(posedge clk);
        ack_pulse     = 1;
        timeout_pulse = 1;
        @(posedge clk);
        ack_pulse     = 0;
        timeout_pulse = 0;

        // Check outputs: ack MUST be emitted, missed MUST NEVER be emitted!
        if (!ack_event_pulse) begin
            $display("[FAIL] Acknowledgement did not win same-edge collision!");
            errors = errors + 1;
        end
        if (missed_event_pulse) begin
            $display("[FAIL] Missed event was spuriously emitted during collision!");
            errors = errors + 1;
        end
        if (ack_event_pulse && !missed_event_pulse) begin
            $display("[PASS] PRIORITY CONFIRMED: Acknowledgement won same-edge collision!");
        end

        // Test 6: Queue event arriving while active must be ignored/held
        $display("[TEST 6] Queue event arriving while reminder active...");
        #20;
        @(posedge clk);
        event_valid = 1;
        event_slot  = 4'd3;
        @(posedge clk);
        // Now active: pretend queue has another slot ready
        event_valid = 1;
        event_slot  = 4'd7;
        @(posedge clk);
        if (event_accept !== 1'b0 || active_slot !== 4'd3) begin
            $display("[FAIL] Accepted incoming queue event while active! accept=%b", event_accept);
            errors = errors + 1;
        end else begin
            $display("[PASS] Queue event locked out while reminder active.");
        end

        // Clear active reminder via ack
        ack_pulse = 1;
        @(posedge clk);
        ack_pulse = 0;
        @(posedge clk);

        // Test 7: Back-to-back reminders
        $display("[TEST 7] Back-to-back reminders...");
        // Slot 7 is pending in queue
        @(posedge clk);
        if (event_accept && (active_slot === 4'd7)) begin
            $display("[PASS] Back-to-back reminder accepted smoothly.");
        end
        event_valid = 0;
        repeat (2) @(posedge clk);
        ack_pulse = 1;
        @(posedge clk);
        ack_pulse = 0;
        #30;

        if (errors == 0) begin
            $display("==================================================");
            $display("[ALL TESTS PASSED] reminder_controller fully verified");
            $display("==================================================");
        end else begin
            $display("[ERROR] Total failures: %0d", errors);
        end

        $finish;
    end

endmodule
