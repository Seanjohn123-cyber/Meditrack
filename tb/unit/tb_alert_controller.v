`timescale 1ns/1ps
// Self-checking testbench for alert_controller (steady and blink variants).
module tb_alert_controller;
    reg clk = 0, rst_n = 0, active = 0;
    wire buz_s, led_s, buz_b, led_b;
    integer errors = 0;

    alert_controller #(.BLINK_EN(0))                         dut_steady
        (.clk(clk), .rst_n(rst_n), .reminder_active(active), .buzzer(buz_s), .led(led_s));
    alert_controller #(.BLINK_EN(1), .BLINK_HALF_PERIOD(4))  dut_blink
        (.clk(clk), .rst_n(rst_n), .reminder_active(active), .buzzer(buz_b), .led(led_b));

    always #5 clk = ~clk;

    initial begin $dumpfile("sim/build/tb_alert_controller.vcd"); $dumpvars(0, tb_alert_controller); end

    task check(input cond, input [8*48-1:0] msg);
        begin
            if (!cond) begin errors = errors + 1; $display("FAIL @%0t: %0s", $time, msg); end
        end
    endtask

    integer i;
    initial begin
        // ---- reset: everything off ------------------------------------------
        #1; check(buz_s===0 && led_s===0 && buz_b===0 && led_b===0, "off during reset");
        @(negedge clk); @(negedge clk); rst_n = 1;

        // ---- inactive -> off --------------------------------------------------
        @(negedge clk);
        check(buz_s===0 && led_s===0 && buz_b===0 && led_b===0, "off when not active");

        // ---- steady: on when active, off when not ---------------------------
        active = 1; #1;
        check(buz_s===1 && led_s===1, "steady on when active");
        @(negedge clk); check(buz_s===1 && led_s===1, "steady stays on");
        active = 0; #1;
        check(buz_s===0 && led_s===0, "steady off when active drops");

        // ---- blink pattern (HALF=4): high 4, low 4, high ---------------------
        @(negedge clk);
        active = 1; #1;
        check(buz_b===1 && led_b===1, "blink starts HIGH (N0)");
        @(negedge clk); check(buz_b===1, "blink high N1");
        @(negedge clk); check(buz_b===1, "blink high N2");
        @(negedge clk); check(buz_b===1, "blink high N3");
        @(negedge clk); check(buz_b===0 && led_b===0, "blink low N4");
        @(negedge clk); check(buz_b===0, "blink low N5");
        @(negedge clk); check(buz_b===0, "blink low N6");
        @(negedge clk); check(buz_b===0, "blink low N7");
        @(negedge clk); check(buz_b===1 && led_b===1, "blink high again N8");
        check(buz_s===1, "steady still on during blink test");

        // ---- drop while in HIGH or LOW phase -> off immediately --------------
        @(negedge clk); @(negedge clk); @(negedge clk); @(negedge clk); // now low phase
        check(buz_b===0, "in low phase");
        active = 0; #1;
        check(buz_b===0 && led_b===0 && buz_s===0, "all off when active drops");

        // ---- restart after a 1-cycle gap -> pattern restarts HIGH -------------
        @(negedge clk);
        active = 1; #1;
        check(buz_b===1 && led_b===1, "blink restarts HIGH after gap");

        // ---- rapid start/stop (toggle every cycle) ---------------------------
        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clk); active = ~active; #1;
            check(buz_s === active, "steady follows rapid toggle");
            check(led_s === active, "steady LED follows rapid toggle");
            if (!active) check(buz_b===0 && led_b===0, "blink off when toggled off");
        end

        // ---- reset while active in low phase -> pattern resets ---------------
        active = 1;
        repeat (6) @(negedge clk);           // into low phase
        rst_n = 0; #1;
        check(buz_b===1, "reset forces phase back to HIGH");
        @(negedge clk); rst_n = 1;
        active = 0; #1;
        check(buz_s===0 && buz_b===0, "off after reset with inactive");

        if (errors == 0) $display("PASS: tb_alert_controller");
        else             $display("FAILED: tb_alert_controller, %0d error(s)", errors);
        $finish;
    end
endmodule
