`timescale 1ns/1ps
// Self-checking testbench for display_controller (combinational).
module tb_display_controller;
    reg        reminder_active = 0;
    reg  [3:0] active_slot     = 0;
    wire       display_active;
    wire [3:0] display_slot;
    wire [6:0] display_seg;
    integer errors = 0;

    display_controller dut (.reminder_active(reminder_active), .active_slot(active_slot),
                            .display_active(display_active), .display_slot(display_slot),
                            .display_seg(display_seg));

    initial begin $dumpfile("sim/build/tb_display_controller.vcd"); $dumpvars(0, tb_display_controller); end

    task check(input cond, input [8*48-1:0] msg);
        begin
            if (!cond) begin errors = errors + 1; $display("FAIL @%0t: %0s", $time, msg); end
        end
    endtask

    integer s;
    initial begin
        // Reset state: Person 4 holds reminder_active low -> IDLE display
        #1;
        check(display_active===0 && display_slot===4'hF && display_seg===7'b0000000, "idle during reset");

        // Idle ignores active_slot garbage
        active_slot = 4'd9; #1;
        check(display_active===0 && display_slot===4'hF && display_seg===7'b0000000, "idle ignores slot");

        // Every valid slot
        for (s = 0; s < 12; s = s + 1) begin
            active_slot = s[3:0]; reminder_active = 1; #1;
            check(display_active===1,        "active flag set");
            check(display_slot===s[3:0],     "slot shown");
            check(display_seg !== 7'b0000000,"segment not blank when active");
            reminder_active = 0; #1;
            check(display_active===0 && display_slot===4'hF && display_seg===7'b0000000, "back to idle");
        end

        // Spot-check segment codes
        reminder_active = 1;
        active_slot = 0; #1; check(display_seg===7'b1111110, "seg for 0");
        active_slot = 1; #1; check(display_seg===7'b0110000, "seg for 1");
        active_slot = 8; #1; check(display_seg===7'b1111111, "seg for 8");
        active_slot = 10; #1; check(display_seg===7'b1110111, "seg for A (slot 10)");
        active_slot = 11; #1; check(display_seg===7'b0011111, "seg for b (slot 11)");

        // Status transition while active: slot change shows immediately
        active_slot = 3; #1; check(display_slot===3, "slot 3");
        active_slot = 7; #1; check(display_slot===7, "changes to slot 7");
        reminder_active = 0; #1; check(display_active===0, "idle after reminder ends");

        if (errors == 0) $display("PASS: tb_display_controller");
        else             $display("FAILED: tb_display_controller, %0d error(s)", errors);
        $finish;
    end
endmodule
