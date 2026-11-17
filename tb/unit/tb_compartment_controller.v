
`timescale 1ns/1ps

// Self-checking testbench for compartment_controller (15 compartments).
module tb_compartment_controller;

    localparam NUM = 15, CYC = 6;

    reg clk = 0;
    reg rst_n = 1;
    reg req_valid = 0;
    reg relock_req = 0;
    reg [3:0] req_slot = 0;

    wire [NUM-1:0] unlock;
    wire unlock_active;
    wire invalid_pulse;
    wire reject_pulse;

    integer errors = 0;
    integer i;

    compartment_controller #(
        .NUM_SLOTS(NUM),
        .UNLOCK_CYCLES(CYC)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(req_valid),
        .req_slot(req_slot),
        .relock_req(relock_req),
        .unlock(unlock),
        .unlock_active(unlock_active),
        .invalid_pulse(invalid_pulse),
        .reject_pulse(reject_pulse)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/build/tb_compartment_controller.vcd");
        $dumpvars(0, tb_compartment_controller);
    end

    task check(input cond, input [8*56-1:0] msg);
        begin
            if (!cond) begin
                errors = errors + 1;
                $display("FAIL @%0t: %0s", $time, msg);
            end
        end
    endtask

    // Invariant: never more than one compartment unlocked.
    always @(posedge clk) begin
        #1;
        if ((unlock & (unlock - 1'b1)) != 0) begin
            errors = errors + 1;
            $display("FAIL @%0t: MORE THAN ONE COMPARTMENT UNLOCKED", $time);
        end
    end

    // Drive a one-cycle request.
    task request(input [3:0] slot);
        begin
            @(negedge clk);
            req_slot = slot;
            req_valid = 1;
            @(negedge clk);
            req_valid = 0;
        end
    endtask

    initial begin

        // ---- Reset: all compartments locked -------------------------------
        #1;
        rst_n = 0;
        #1;

        check(unlock === 0 && unlock_active === 0,
              "locked in reset");

        repeat (3) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        check(unlock === 0, "locked after reset release");

        // ---- Changing req_slot without req_valid does nothing -------------
        req_slot = 4;
        repeat (2) @(negedge clk);

        check(unlock === 0 && !invalid_pulse && !reject_pulse,
              "no valid request -> no action");

        // ---- Valid request and automatic relock ---------------------------
        request(3);

        check(unlock === (15'd1 << 3), "slot 3 unlocked");
        check(unlock_active === 1, "unlock_active high");

        for (i = 1; i < CYC; i = i + 1) begin
            @(negedge clk);
            check(unlock === (15'd1 << 3),
                  "still unlocked before timer ends");
        end

        @(negedge clk);
        check(unlock === 0, "auto-relocked after UNLOCK_CYCLES");

        // ---- Invalid slot: 15 ----------------------------------------------
        request(15);

        check(unlock === 0, "slot 15 rejected, no unlock");
        check(invalid_pulse === 1, "invalid_pulse for slot 15");

        @(negedge clk);
        check(invalid_pulse === 0, "invalid_pulse is one cycle");

        // ---- Boundary: slot 0 is valid -------------------------------------
        request(0);

        check(unlock === (15'd1 << 0), "slot 0 valid");

        @(negedge clk);
        relock_req = 1;
        @(negedge clk);
        relock_req = 0;

        check(unlock === 0, "early relock from relock_req");

        // ---- Slot 11 is valid ----------------------------------------------
        request(11);

        check(unlock === (15'd1 << 11), "slot 11 valid");

        @(negedge clk);
        relock_req = 1;
        @(negedge clk);
        relock_req = 0;

        check(unlock === 0, "slot 11 relocked");

        // ---- Highest valid slot: 14 ----------------------------------------
        request(14);

        check(unlock === (15'd1 << 14), "slot 14 valid");

        @(negedge clk);
        relock_req = 1;
        @(negedge clk);
        relock_req = 0;

        check(unlock === 0, "slot 14 relocked");

        // ---- Second request while one compartment is open -----------------
        request(2);

        check(unlock === (15'd1 << 2), "slot 2 open");

        request(5);

        check(reject_pulse === 1,
              "reject_pulse on second request");
        check(unlock === (15'd1 << 2),
              "open slot unchanged by rejected request");

        @(negedge clk);
        check(reject_pulse === 0, "reject_pulse is one cycle");

        relock_req = 1;
        @(negedge clk);
        relock_req = 0;

        check(unlock === 0, "relocked after rejected test");

        // ---- New request works after relocking -----------------------------
        request(5);

        check(unlock === (15'd1 << 5),
              "slot 5 opens after relock");

        // ---- Asynchronous reset while open --------------------------------
        rst_n = 0;
        #1;

        check(unlock === 0 && unlock_active === 0,
              "reset while open locks immediately");

        repeat (2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        check(unlock === 0, "still locked after reset release");

        // ---- Final result --------------------------------------------------
        if (errors == 0)
            $display("PASS: tb_compartment_controller");
        else
            $display("FAILED: tb_compartment_controller, %0d error(s)", errors);

        $finish;
    end

endmodule
