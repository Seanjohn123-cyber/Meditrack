`timescale 1ns/1ps

module tb_timer_unit();

    // --- Signal Declarations ---
    // Inputs to UUT (Stimulus)
    reg clk;
    reg rst_n;
    reg time_load_en;
    reg [2:0] load_day;
    reg [4:0] load_hour;
    reg [5:0] load_minute;

    // Outputs from UUT (Observation)
    wire [2:0] curr_day;
    wire [4:0] curr_hour;
    wire [5:0] curr_minute;
    wire minute_tick;

    // --- Unit Under Test (UUT) Instantiation ---
    timer_unit #(
        .CLKS_PER_SECOND(10),
        .SECS_PER_MINUTE(6)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .time_load_en(time_load_en),
        .load_day(load_day),
        .load_hour(load_hour),
        .load_minute(load_minute),
        .curr_day(curr_day),
        .curr_hour(curr_hour),
        .curr_minute(curr_minute),
        .minute_tick(minute_tick)
    );

    // --- Clock Generation ---
    // 10ns clock period (100 MHz)
    always #5 clk = ~clk;

    // --- Stimulus Generation ---
    initial begin
        // VCD waveform dumping
        $dumpfile("timer_waves.vcd");
        $dumpvars(0, tb_timer_unit);

        // Initialize all inputs
        clk = 0;
        time_load_en = 0;
        load_day = 0; 
        load_hour = 0; 
        load_minute = 0;
        
        // Assert active-low asynchronous reset
        rst_n = 0;      
        #20;            
        rst_n = 1; // De-assert reset
        
        // Allow hardware to run from Sunday 00:00 briefly
        #200;

        // Load new timezone configuration (Tuesday 23:59)
        @(posedge clk);
        time_load_en = 1;
        load_day = 3'd2;       
        load_hour = 5'd23;     
        load_minute = 6'd59;   
        
        @(posedge clk);
        time_load_en = 0;

        // Run simulation to observe the cascade and day rollover
        // Note: 1 simulated day = 864,000 ns
        #1000000;

        // Terminate simulation
        $finish;
    end

endmodule