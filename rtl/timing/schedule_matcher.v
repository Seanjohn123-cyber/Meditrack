`timescale 1ns/1ps

module schedule_matcher (
    input  wire         clk,             // 100 MHz system clock
    input  wire         rst_n,           // Active-low asynchronous reset
    
    // Time interface from timer_unit
    input  wire         minute_tick,     // 1-cycle minute rollover strobe
    input  wire [4:0]   curr_hour,       // 0..23
    input  wire [5:0]   curr_minute,     // 0..59
    
    // 15-Slot Parallel Schedule Interface (Flattened Vectors)
    input  wire [14:0]  sched_enables,   // 1 bit per slot (1 = Active, 0 = Disabled)
    input  wire [74:0]  sched_hours,     // 15 slots * 5 bits 
    input  wire [89:0]  sched_minutes,   // 15 slots * 6 bits 
    
    // Downstream Event Queue Interface
    output reg  [14:0]  due_vector       // 15-bit parallel pulse vector
);

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            due_vector <= 15'b0;
        end else begin
            // Default to 0 on every clock cycle to guarantee strict 1-cycle pulses
            due_vector <= 15'b0;

            // Only evaluate schedules on the exact cycle the minute rolls over
            if (minute_tick) begin
                
                // Synthesizes into 15 parallel hardware comparators
                for (i = 0; i < 15; i = i + 1) begin
                    
                    // Verilog-2001 indexed part-select [base +: width]
                    if (sched_enables[i] && 
                       (sched_hours[i*5 +: 5] == curr_hour) && 
                       (sched_minutes[i*6 +: 6] == curr_minute)) begin
                        
                        // Assert the specific bit for this slot
                        due_vector[i] <= 1'b1; 
                        
                    end
                end
            end
        end
    end

endmodule