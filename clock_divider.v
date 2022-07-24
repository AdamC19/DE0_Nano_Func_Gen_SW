module divider(clk_out, clk_in, division);

output clk_out;
input clk_in;
input [31:0] division;

reg clk_out_reg = 0;
reg [31:0] counter = 0;

assign clk_out = clk_out_reg;

always @(posedge clk_in) begin
	counter = counter + 1;
	if (counter >= (division >> 1)) begin
		clk_out_reg = ~clk_out_reg;
		counter = 0;
	end
end

endmodule
