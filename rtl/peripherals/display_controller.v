`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// display_controller.v  --  MediTrack, Person 5
// Shows system status from reminder_active and active_slot (Person 4) ONLY.
// Purely combinational: no state, so there is nothing to reset. During reset
// Person 4's reminder_active is 0, so the display shows IDLE.
//
// Encoding (frozen at D1 -- keep in docs/module_interfaces.md):
//   display_active : 1 = reminder active, 0 = idle
//   display_slot   : active_slot while active; 4'hF while idle
//   display_seg    : 7-segment {a,b,c,d,e,f,g}, active-high, hex digit of the
//                    slot while active; blank (0000000) while idle.
//                    Slots 10 and 11 show as A and B.
// Only two states exist because only reminder_active/active_slot are consumed.
// A slot value >= 12 while active is passed through unchanged (not validated
// here; schedule/queue own slot validity).
// -----------------------------------------------------------------------------
module display_controller (
    input  wire       reminder_active,
    input  wire [3:0] active_slot,
    output wire       display_active,
    output wire [3:0] display_slot,
    output reg  [6:0] display_seg
);

assign display_active = reminder_active;
assign display_slot   = reminder_active ? active_slot : 4'hF;

always @(*) begin
    if (!reminder_active) begin
        display_seg = 7'b0000000;
    end else begin
        case (active_slot)
            4'h0: display_seg = 7'b1111110;
            4'h1: display_seg = 7'b0110000;
            4'h2: display_seg = 7'b1101101;
            4'h3: display_seg = 7'b1111001;
            4'h4: display_seg = 7'b0110011;
            4'h5: display_seg = 7'b1011011;
            4'h6: display_seg = 7'b1011111;
            4'h7: display_seg = 7'b1110000;
            4'h8: display_seg = 7'b1111111;
            4'h9: display_seg = 7'b1111011;
            4'hA: display_seg = 7'b1110111;
            4'hB: display_seg = 7'b0011111;
            4'hC: display_seg = 7'b1001110;
            4'hD: display_seg = 7'b0111101;
            4'hE: display_seg = 7'b1001111;
            4'hF: display_seg = 7'b1000111;
            default: display_seg = 7'b0000000;
        endcase
    end
end

endmodule
