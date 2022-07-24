module debounce(btn_out, clk, btn_in);

output btn_out;
input clk;
input btn_in;

parameter DEBOUNCE_CLKS = 2500000; // 50ms

reg [31:0] counter = 0;
reg edge_detected = 0;
reg reset_edge_detect = 0;
reg btn_state = 1; // btn starts unpressed

assign btn_out = btn_state;


always @(btn_in) begin
	if(btn_in != btn_state) begin
		edge_detected = 'b1;
	end else begin
		edge_detected ='b0;
	end
end

always @(posedge clk) begin
	if(edge_detected) begin
		counter = counter + 1;
		if(counter >= DEBOUNCE_CLKS) begin
			btn_state = ~btn_state; // toggle btn_state
			counter = 0;
		end
	end
end

endmodule
