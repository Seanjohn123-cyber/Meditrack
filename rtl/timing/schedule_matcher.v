`timescale 1ns/1ps

module schedule_matcher (
    input  wire        clk,              // 100 MHz system clock
    input  wire        rst_n,            // Active-low asynchronous reset
    
    // Time interface from timer_unit
    input  wire [2:0]  curr_day,         // 0=Sun .. 6=Sat
    input  wire [4:0]  curr_hour,        // 0..23
    input  wire [5:0]  curr_minute,      // 0..59
    input  wire        minute_tick,      // 1-cycle minute rollover strobe
    
    // Synchronous SRAM schedule interface (256 x 16-bit)
    // Word format: [15]=Valid, [14]=Reserved, [13:11]=Day, [10:6]=Hour, [5:0]=Minute
    input  wire [15:0] mem_data,
    output reg  [7:0]  mem_addr,
    
    // Downstream actuator interface
    output reg         trigger_dispense  // 1-cycle dispense trigger pulse
);

    // FSM state encoding
    localparam [1:0] IDLE    = 2'd0,
                     FETCH   = 2'd1,
                     COMPARE = 2'd2;

    reg [1:0] state;
    reg [7:0] slot_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= IDLE;
            mem_addr         <= 8'd0;
            slot_count       <= 8'd0;
            trigger_dispense <= 1'b0;
        end else begin
            // Default low to enforce single-cycle pulse behavior
            trigger_dispense <= 1'b0;

            case (state)
                IDLE: begin
                    mem_addr   <= 8'd0;
                    slot_count <= 8'd0;
                    if (minute_tick) begin
                        state <= FETCH;
                    end
                end

                FETCH: begin
                    // Drive address bus; allow 1 cycle for synchronous SRAM read latency
                    mem_addr <= slot_count;
                    state    <= COMPARE;
                end

                COMPARE: begin
                    // Evaluate valid bit and unpacked timestamp fields
                    if (mem_data[15] &&
                        (mem_data[13:11] == curr_day) &&
                        (mem_data[10:6]  == curr_hour) &&
                        (mem_data[5:0]   == curr_minute)) begin
                        trigger_dispense <= 1'b1;
                    end

                    // Sweep all 256 schedule slots before returning to sleep
                    if (slot_count == 8'd255) begin
                        state <= IDLE;
                    end else begin
                        slot_count <= slot_count + 8'd1;
                        state      <= FETCH;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule