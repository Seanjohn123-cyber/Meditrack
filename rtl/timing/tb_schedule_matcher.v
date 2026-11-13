`timescale 1ns/1ps

module tb_schedule_matcher();

    // --- Stimulus Signals (Driven into UUT) ---
    reg         clk;
    reg         rst_n;
    reg  [2:0]  curr_day;
    reg  [4:0]  curr_hour;
    reg  [5:0]  curr_minute;
    reg         minute_tick;
    reg  [15:0] mem_data;

    // --- Observation Signals (Driven from UUT) ---
    wire [7:0]  mem_addr;
    wire        trigger_dispense;

    // --- Fake Synchronous SRAM ---
    reg [15:0] fake_sram [0:255];
    integer i;

    // --- Unit Under Test (UUT) ---
    schedule_matcher uut (
        .clk              (clk),
        .rst_n            (rst_n),
        .curr_day         (curr_day),
        .curr_hour        (curr_hour),
        .curr_minute      (curr_minute),
        .minute_tick      (minute_tick),
        .mem_data         (mem_data),
        .mem_addr         (mem_addr),
        .trigger_dispense (trigger_dispense)
    );

    // --- Clock Generation ---
    always #5 clk = ~clk;

    // --- Behavioral SRAM Read Model ---
    always @(posedge clk) begin
        mem_data <= fake_sram[mem_addr];
    end

    // --- Test Stimulus Sequence ---
    initial begin
        $dumpfile("matcher_waves.vcd");
        $dumpvars(0, tb_schedule_matcher);

        // 1. Initialization
        clk         = 1'b0;
        rst_n       = 1'b0;
        curr_day    = 3'd0;
        curr_hour   = 5'd0;
        curr_minute = 6'd0;
        minute_tick = 1'b0;
        mem_data    = 16'd0;

        for (i = 0; i < 256; i = i + 1) begin
            fake_sram[i] = 16'h0000;
        end

        // 2. Program Test Prescriptions
        // Word format: {Valid[15], Reserved[14], Day[13:11], Hour[10:6], Minute[5:0]}
        fake_sram[0]  = {1'b0, 1'b0, 3'd0, 5'd0,  6'd0};  // Slot 0: Disabled Sunday 00:00
        fake_sram[42] = {1'b1, 1'b0, 3'd3, 5'd14, 6'd30}; // Slot 42: Active Wednesday 14:30

        // 3. Release Reset
        #20;
        rst_n = 1'b1;
        #20;

        // 4. Test Case 1: Trigger at Sunday 00:00 (Should NOT dispense)
        @(posedge clk);
        curr_day    = 3'd0;
        curr_hour   = 5'd0;
        curr_minute = 6'd0;
        minute_tick = 1'b1;
        
        @(posedge clk);
        minute_tick = 1'b0;

        // Wait for FSM to sweep all 256 slots
        #5200;

        // 5. Test Case 2: Trigger at Wednesday 14:30 (SHOULD dispense at Slot 42)
        @(posedge clk);
        curr_day    = 3'd3;
        curr_hour   = 5'd14;
        curr_minute = 6'd30;
        minute_tick = 1'b1;
        
        @(posedge clk);
        minute_tick = 1'b0;

        // Wait for sweep completion to observe the 1-cycle match pulse
        #5200;

        $finish;
    end

endmodule