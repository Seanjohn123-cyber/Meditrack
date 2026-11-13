`timescale 1ns/1ps

module tb_schedule_matcher();

    reg         clk;
    reg         rst_n;
    reg         minute_tick;
    reg  [4:0]  curr_hour;
    reg  [5:0]  curr_minute;
    
    reg  [14:0] sched_enables;
    reg  [74:0] sched_hours;
    reg  [89:0] sched_minutes;
    
    wire [14:0] due_vector;

    schedule_matcher uut (
        .clk           (clk),
        .rst_n         (rst_n),
        .minute_tick   (minute_tick),
        .curr_hour     (curr_hour),
        .curr_minute   (curr_minute),
        .sched_enables (sched_enables),
        .sched_hours   (sched_hours),
        .sched_minutes (sched_minutes),
        .due_vector    (due_vector)
    );

    always #5 clk = ~clk; // 100 MHz clock

    initial begin
        $dumpfile("matcher_waves.vcd");
        $dumpvars(0, tb_schedule_matcher);

        // --- Initialization ---
        clk           = 1'b0;
        rst_n         = 1'b0;
        minute_tick   = 1'b0;
        curr_hour     = 5'd0;
        curr_minute   = 6'd0;
        sched_enables = 15'd0;
        sched_hours   = 75'd0;
        sched_minutes = 90'd0;

        // --- Program the 15 Schedule Slots ---
        
        // Slot 0: 08:30 (Enabled - Standard)
        sched_enables[0]       = 1'b1;
        sched_hours[0*5 +: 5]  = 5'd8;
        sched_minutes[0*6 +: 6]= 6'd30;

        // Slot 1: 08:30 (Enabled - Simultaneous match with Slot 0)
        sched_enables[1]       = 1'b1;
        sched_hours[1*5 +: 5]  = 5'd8;
        sched_minutes[1*6 +: 6]= 6'd30;

        // Slot 2: 14:15 (Disabled - Testing suppression)
        sched_enables[2]       = 1'b0;
        sched_hours[2*5 +: 5]  = 5'd14;
        sched_minutes[2*6 +: 6]= 6'd15;

        // Slot 14: 00:00 (Enabled - Midnight rollover)
        sched_enables[14]       = 1'b1;
        sched_hours[14*5 +: 5]  = 5'd0;
        sched_minutes[14*6 +: 6]= 6'd0;

        #20;
        rst_n = 1'b1; // Release reset
        #20;

        // --- Scenario 1 & 2: Single & Simultaneous Matches (08:30) ---
        @(posedge clk);
        curr_hour   = 5'd8;
        curr_minute = 6'd30;
        minute_tick = 1'b1;
        @(posedge clk);
        minute_tick = 1'b0;
        // Verify in GTKWave: due_vector drops exactly 15'b000000000000011 (Slots 0 and 1 HIGH)
        #50;

        // --- Scenario 3: Disabled Slot Suppression (14:15) ---
        @(posedge clk);
        curr_hour   = 5'd14;
        curr_minute = 6'd15;
        minute_tick = 1'b1;
        @(posedge clk);
        minute_tick = 1'b0;
        // Verify in GTKWave: due_vector remains 15'b000000000000000
        #50;

        // --- Scenario 4: Midnight Rollover (00:00) ---
        @(posedge clk);
        curr_hour   = 5'd0;
        curr_minute = 6'd0;
        minute_tick = 1'b1;
        @(posedge clk);
        minute_tick = 1'b0;
        // Verify in GTKWave: due_vector drops exactly 15'b100000000000000 (Slot 14 HIGH)
        
        // --- Scenario 5: Same-minute No-retrigger ---
        // Holding the time at 00:00 for multiple cycles without minute_tick firing again
        #50;
        // Verify in GTKWave: due_vector immediately returned to 0 and stayed flat.

        $finish;
    end
endmodule