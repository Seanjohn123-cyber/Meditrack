`timescale 1ns/1ps 

module timer_unit #(
    // Configurable simulation parameters
    parameter integer CLKS_PER_SECOND = 10,
    parameter integer SECS_PER_MINUTE = 6
)(
    input  wire       clk,          // Main system clock
    input  wire       rst_n,        // Active-low asynchronous reset
    input  wire       time_load_en, // Enable signal to load initial timezone/time
    input  wire [2:0] load_day,     // 0=Sun, 1=Mon, ..., 6=Sat
    input  wire [4:0] load_hour,    // 0 to 23
    input  wire [5:0] load_minute,  // 0 to 59
    
    output reg  [2:0] curr_day,
    output reg  [4:0] curr_hour,
    output reg  [5:0] curr_minute,
    output reg        minute_tick   // 1-cycle pulse triggered on minute rollover
);

    // Internal down-sampling counters
    integer clk_counter;
    integer sec_counter;

    // --- CHANGE 1: Define the edge detector ---
    reg time_load_en_d1;
    wire load_strobe = time_load_en && !time_load_en_d1;

    always @(posedge clk or negedge rst_n) begin
        
        // --- Asynchronous Reset ---
        if (!rst_n) begin 
            clk_counter <= 0;
            sec_counter <= 0;
            curr_day    <= 3'd0;
            curr_hour   <= 5'd0;
            curr_minute <= 6'd0;
            minute_tick <= 1'b0; 
            
            // --- CHANGE 2: Reset the edge detector register ---
            time_load_en_d1 <= 1'b0;
            
        end else begin
            // --- CHANGE 3: Track previous level for rising-edge detection ---
            time_load_en_d1 <= time_load_en;

            // Default state: ensure tick acts as a single-cycle pulse
            minute_tick <= 1'b0; 

            // --- CHANGE 4: Use 'load_strobe' instead of 'time_load_en' ---
            if (load_strobe) begin
                curr_day    <= load_day;
                curr_hour   <= load_hour;
                curr_minute <= load_minute;
                
                // Flush counters to start counting cleanly from the new time
                clk_counter <= 0;
                sec_counter <= 0;
                
            // --- Normal Clock Ticking ---
            end else begin
                
                // Fast clock down-sampling
                if (clk_counter >= CLKS_PER_SECOND - 1) begin
                    clk_counter <= 0; 
                    
                    // Second down-sampling
                    if (sec_counter >= SECS_PER_MINUTE - 1) begin
                        sec_counter <= 0; 
                        
                        // Fire the downstream trigger
                        minute_tick <= 1'b1; 
                        
                        // --- Calendar Cascade Logic ---
                        if (curr_minute >= 6'd59) begin
                            curr_minute <= 6'd0; 
                            
                            if (curr_hour >= 5'd23) begin
                                curr_hour <= 5'd0; 
                                
                                // Midnight day rollover
                                if (curr_day >= 3'd6) begin
                                    curr_day <= 3'd0; 
                                end else begin
                                    curr_day <= curr_day + 1; 
                                end
                                
                            end else begin
                                curr_hour <= curr_hour + 1; 
                            end
                        end else begin
                            curr_minute <= curr_minute + 1; 
                        end
                        
                    end else begin
                        sec_counter <= sec_counter + 1; 
                    end
                end else begin
                    clk_counter <= clk_counter + 1; 
                end
            end
        end
    end

endmodule