module square_wave(dac_out, clk, clk_div, duty_cycle);

parameter DUTY_CYCLE_BITS = 9;
output reg [7:0] dac_out;
input clk;
input [31:0] clk_div;
input [DUTY_CYCLE_BITS-1:0] duty_cycle;

wire dac_clk;
reg [DUTY_CYCLE_BITS-1:0] counter;


divider CLK_DIV(dac_clk, clk, clk_div);

always @(dac_clk) begin
    counter <= counter + 1;

    if(counter < duty_cycle) begin
        dac_out <= 8'hFF;
    end else begin
        dac_out <= 8'h00;
    end
    
    if (counter == ((1 << DUTY_CYCLE_BITS) - 1)) begin
        counter <= 0;
    end
end

endmodule