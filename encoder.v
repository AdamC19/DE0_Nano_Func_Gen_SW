module encoder(
    total_counts,
    period, 
    direction, 
    clk_50,
    a, 
    b, 
    reset_counts
);

output signed [31:0] total_counts;
output signed [31:0] period;
output direction;
input clk_50;
input a;
input b;
input reset_counts;

reg last_a;
reg last_b;
reg dir_reg;
reg signed [31:0] total_counts_reg;
reg [31:0] clk_counter;
reg [31:0] last_clk_counter;
reg [31:0] period_reg;

assign total_counts = total_counts_reg;
assign direction = dir_reg;
assign period = period_reg;

always @(posedge a or posedge b or posedge reset_counts) begin
    if(reset_counts) begin
        // while reset is high hold in reset
        total_counts <= 32'h00;
    end else begin
        if(a && !b) begin
            // direction is clockwise (positive)
            dir_reg <= 'b0;
            total_counts <= total_counts + 1;
            // be sure the clock counter hasn't rolled over
            if (clk_counter > last_clk_counter) begin
                period_reg <= clk_counter - last_clk_counter;
            end
            last_clk_counter <= clk_counter;
        end else if (b && !a) begin
            // direction is counter-clockwise (negative)
            dir_reg <= 'b1;
            total_counts <= total_counts - 1;
            // be sure the clock counter hasn't rolled over
            if (clk_counter > last_clk_counter) begin
                period_reg <= clk_counter - last_clk_counter;
            end
            last_clk_counter <= clk_counter;
        end
        
    end
end


always @(posedge clk_50) begin
    clk_counter <= clk_counter + 1;
end

endmodule