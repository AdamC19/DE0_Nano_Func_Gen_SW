module square_wave(dac_out, clk, clk_div, duty_cycle);

parameter DUTY_CYCLE_BITS = 9;
output [7:0] dac_out;
input clk;
input [31:0] clk_div;

wire dac_clk;
reg [DUTY_CYCLE_BITS-1:0] counter;

divider CLK_DIV(dac_clk, clk, clk_div);

always @(dac_clk) begin
    counter <= counter + 1;

    if(counter <= duty_cycle) begin
        dac_out <= 8'hFF;
    end else begin
        dac_out <= 8'h00;
    end
end

endmodule