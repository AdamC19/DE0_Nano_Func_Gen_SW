module wave_gen(word_out, clk, clk_div, lut);

parameter LUT_SIZE = 4096;
output [7:0] word_out;
input clk;
input [31:0] clk_div;
input [LUT_SIZE-1:0] lut;


wire slow_clk; // the clk that advances us thru the wave LUT
divider CLOCK_DIV(slow_clk, clk, clk_div);
reg [31:0] wave_ind = 0;
reg [7:0] word_reg = 0;

assign word_out = word_reg;

always @(posedge slow_clk) begin
    word_reg <= lut[(((wave_ind + 1)<<3)-1)-:8];
    if(wave_ind >= (LUT_SIZE >> 3)) begin
        wave_ind <= 0;
    end else begin
        wave_ind <= wave_ind + 1;
    end
end

endmodule