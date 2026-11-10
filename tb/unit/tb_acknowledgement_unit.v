//=============================================================================
// Testbench: tb_acknowledgement_unit
// Target: rtl/reminder/acknowledgement_unit.v
// Owner: Person 4 (Lead)
// Verification: Contact bounce, long button hold, repeated presses, reset
//=============================================================================

`timescale 1ns/1ps

module tb_acknowledgement_unit;

    reg clk;
    reg rst_n;
    reg btn_ack_raw;
    wire ack_pulse;

    integer pulse_count;
    integer errors;

    localparam DEBOUNCE = 4;

    acknowledgement_unit #(
        .DEBOUNCE_CYCLES(DEBOUNCE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .btn_ack_raw(btn_ack_raw),
        .ack_pulse(ack_pulse)
    );

    // Clock generation: 100MHz (10ns period)
    always #5 clk = ~clk;

    // Pulse monitor
    always @(posedge clk) begin
        if (ack_pulse) begin
            pulse_count = pulse_count + 1;
        end
    end

    initial begin
        $dumpfile("tb_acknowledgement_unit.vcd");
        $dumpvars(0, tb_acknowledgement_unit);

        clk = 0;
        rst_n = 0;
        btn_ack_raw = 0;
        pulse_count = 0;
        errors = 0;

        $display("==================================================");
        $display("[START] tb_acknowledgement_unit verification");
        $display("==================================================");

        // Test 1: Reset behavior
        #25;
        rst_n = 1;
        #20;
        if (ack_pulse !== 1'b0) begin
            $display("[FAIL] Expected ack_pulse=0 after reset, got %b", ack_pulse);
            errors = errors + 1;
        end

        // Test 2: Contact bounce simulation
        $display("[TEST 2] Contact bounce simulation...");
        pulse_count = 0;
        // Bouncing for 2 cycles high, 1 low, 2 high, etc. (less than DEBOUNCE_CYCLES consecutive)
        @(posedge clk); btn_ack_raw = 1;
        @(posedge clk); btn_ack_raw = 0;
        @(posedge clk); btn_ack_raw = 1;
        @(posedge clk); btn_ack_raw = 0;
        #30;
        if (pulse_count !== 0) begin
            $display("[FAIL] Glitches caused unwanted ack_pulse!");
            errors = errors + 1;
        end

        // Now settle high for > DEBOUNCE_CYCLES
        @(posedge clk); btn_ack_raw = 1;
        #(10 * (DEBOUNCE + 4));
        if (pulse_count !== 1) begin
            $display("[FAIL] Valid debounced press failed to produce exactly 1 pulse! Count=%0d", pulse_count);
            errors = errors + 1;
        end else begin
            $display("[PASS] Debounced press emitted exactly 1 pulse.");
        end

        // Test 3: Long hold button test
        $display("[TEST 3] Long button hold test...");
        // Keep button high for 20 clock cycles
        #(10 * 20);
        if (pulse_count !== 1) begin
            $display("[FAIL] Button hold generated repeated pulses! Count=%0d", pulse_count);
            errors = errors + 1;
        end else begin
            $display("[PASS] Long hold generated no spurious repeat pulses.");
        end

        // Release button and let it debounce low
        @(posedge clk); btn_ack_raw = 0;
        #(10 * (DEBOUNCE + 4));

        // Test 4: Repeated presses
        $display("[TEST 4] Repeated press test...");
        pulse_count = 0;

        // Press 1
        @(posedge clk); btn_ack_raw = 1;
        #(10 * (DEBOUNCE + 2));
        @(posedge clk); btn_ack_raw = 0;
        #(10 * (DEBOUNCE + 2));

        // Press 2
        @(posedge clk); btn_ack_raw = 1;
        #(10 * (DEBOUNCE + 2));
        @(posedge clk); btn_ack_raw = 0;
        #(10 * (DEBOUNCE + 2));

        if (pulse_count !== 2) begin
            $display("[FAIL] Repeated press failed! Expected 2, got %0d", pulse_count);
            errors = errors + 1;
        end else begin
            $display("[PASS] Exactly 2 pulses for 2 distinct presses.");
        end

        #50;
        if (errors == 0) begin
            $display("==================================================");
            $display("[ALL TESTS PASSED] acknowledgement_unit verified");
            $display("==================================================");
        end else begin
            $display("[ERROR] Total failures: %0d", errors);
        end

        $finish;
    end

endmodule
