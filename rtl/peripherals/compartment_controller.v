`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// compartment_controller.v  --  MediTrack, Person 5
// Controls ACCESS only. Unlocking is NOT an acknowledgement and does not prove
// medication was removed or swallowed. Never touches ack/timeout/event pulses.
//
// Policy (frozen at D1 -- keep in docs/module_interfaces.md):
//  * After reset every compartment is locked.
//  * req_valid with req_slot < NUM_SLOTS and nothing open -> unlock that slot.
//  * req_slot >= NUM_SLOTS (and nothing open)             -> invalid_pulse,
//                                                            no unlock.
//  * Any request while one compartment is open            -> reject_pulse,
//                                                            open slot unchanged.
//  * Relock: automatically after UNLOCK_CYCLES clocks, or earlier on relock_req.
//  * 'unlock' is decoded from ONE slot register, so at most one bit can ever
//    be high (one-hot or zero) -- by construction.
//  * invalid_pulse / reject_pulse are one-cycle pulses.
// The countdown is only a relock timer; it creates no events.
// -----------------------------------------------------------------------------
module compartment_controller #(
    parameter NUM_SLOTS     = 15,
    parameter UNLOCK_CYCLES = 16        // >= 1
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 req_valid,
    input  wire [3:0]           req_slot,
    input  wire                 relock_req,
    output wire [NUM_SLOTS-1:0] unlock,
    output wire                 unlock_active,
    output reg                  invalid_pulse,
    output reg                  reject_pulse
);

reg        open;
reg [3:0]  open_slot;
reg [15:0] cnt;

wire slot_ok = (req_slot < NUM_SLOTS);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        open          <= 1'b0;
        open_slot     <= 4'd0;
        cnt           <= 16'd0;
        invalid_pulse <= 1'b0;
        reject_pulse  <= 1'b0;
    end else begin
        invalid_pulse <= 1'b0;           // default: pulses last one cycle
        reject_pulse  <= 1'b0;

        if (open) begin
            if (req_valid)
                reject_pulse <= 1'b1;    // second request while one is open
            if (relock_req || cnt == 16'd0)
                open <= 1'b0;
            else
                cnt <= cnt - 16'd1;
        end else if (req_valid) begin
            if (slot_ok) begin
                open      <= 1'b1;
                open_slot <= req_slot;
                cnt       <= UNLOCK_CYCLES - 1;
            end else begin
                invalid_pulse <= 1'b1;
            end
        end
    end
end

assign unlock        = open ? ({{(NUM_SLOTS-1){1'b0}}, 1'b1} << open_slot)
                            : {NUM_SLOTS{1'b0}};
assign unlock_active = open;

endmodule
