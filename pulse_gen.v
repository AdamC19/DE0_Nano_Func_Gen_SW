module pulse_gen(pulse, clk, trigger);

parameter PULSE_WIDTH = 128;
output pulse;
input clk;
input trigger;

reg pulse_state = 0;
reg last_trigger = 0;
reg [31:0] pulse_counter = 0;

assign pulse = pulse_state;

always @(posedge clk) begin
    pulse_counter = pulse_counter + 1;
    
    // set pulse high and reset counter
    if(trigger && !last_trigger) begin
        pulse_counter = 0;
    end

    // constrain pulse_counter
    if(pulse_counter > PULSE_WIDTH) begin
        pulse_counter = PULSE_WIDTH;
    end 

    // set pulse_state to 0 if less than pulse width
    pulse_state = (pulse_counter < PULSE_WIDTH);

    last_trigger = trigger;
end

endmodule