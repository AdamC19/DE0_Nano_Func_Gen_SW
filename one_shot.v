////////////////////////////////////////////////////////////////////////////////
//
//  one_shot
//  ========
//  An edge-triggered one-shot.
// 
//  USAGE:
//  ------
//  clk is the system clock. The PULSE_DURATION parameter specifies how many
//  clk cycles wide the output pulse is. Trigger is the signal with the edges
//  that we want to detect. edges specifies which edges the one-shot fires on.
//
//  PARAMETER(s):
//  -------------
//      PULSE_DURATION  : number of clk pulses per pulse out
//
//  OUTPUT(s)           : BITS  : DESCRIPTION
//  -----------------------------------------
//      pulse           : 1     : The output one-shot pulse
//
//  INPUT(s):           : BITS  : DESCRIPTION
//  -----------------------------------------
//      clk             : 1     : clock for the system
//      trigger         : 1     : signal to respond to
//      edges           : 2     : 00 for no output, 01 for falling edge, 
//                                10 for leading edge, 11 for both edges
////////////////////////////////////////////////////////////////////////////////
module one_shot(pulse, clk, trigger, edges);

parameter PULSE_DURATION = 4;

output reg pulse;
input clk;
input trigger;
input [1:0] edges;

reg pulse_reg = 'b0;
reg last_trigger_reg = 'b0;
reg [31:0] pulse_width_counter = 'b0;

always @(posedge clk) begin
    if(pulse) begin
        // if pulse is ON, only focus on timing the width
        if(pulse_width_counter == PULSE_DURATION) begin
            pulse <= 'b0; // reset and continue
        end
        pulse_width_counter <= pulse_width_counter + 1;
    end else begin
        case(edges)
            'b00: begin
                // NO OUTPUT
                pulse <= 'b0;
            end
            'b01: begin
                // sensitive to falling edge only
                if(!trigger && last_trigger_reg) begin
                    pulse_width_counter <= 32'b1; // on next clk, we'll see 1
                    pulse <= 'b1; // pulse on
                end
            end
            'b10: begin
                // sensitive to rising edge only
                if(trigger && !last_trigger_reg) begin
                    pulse_width_counter <= 32'b1; // on next clk, we'll see 1
                    pulse <= 'b1; // pulse on
                end
            end
            'b11: begin
                // sensitive to both edges
                if ((trigger && !last_trigger_reg) || (!trigger && last_trigger_reg)) begin
                    pulse_width_counter <= 32'b1; // on next clk, we'll see 1
                    pulse <= 'b1; // pulse on
                end
            end
        endcase
        
        last_trigger_reg <= trigger;
    end
    
    
end

endmodule