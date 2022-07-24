////////////////////////////////////////////////////////////////////////////////
//
// UART MODULE
// 	bytevect_out 	: bitstream of received bits
// 	rx_size_ready 	: number of bytes in the received bistream
// 	rx_buffer_full 	: active high flag to indicate when the rx_buffer is full
// 	tx_line 		: the TX data coming out of the UART
// 	rx_line 		: the RX data line going into the UART
// 	rx_reset 		: active high, reset the RX part of the uart
// 	clk 			: 50MHz clock
// 	bytevect_in 	: bitstream of bytes to send out
// 	tx_size 		: number of bytes in the bytevect_in to send out
// 	tx_go 			: active high, signal to begin transmission of data
//
// PARAMETERS
// 	RX_PACKET_SIZE 	: capacity of the bytevector_out
// 	TX_PACKET_SIZE 	: capacity of the bytevector_in
// 	BIT_TIMING 		: division for the 50MHz clk to achieve the target BAUD rate
//
////////////////////////////////////////////////////////////////////////////////

module uart(bytevect_out, rx_size_ready, rx_buffer_full, tx_done, rx_state_out, tx_line, rx_line, rx_reset, clk, bytevect_in, tx_size, tx_reset);

parameter RX_PACKET_SIZE = 64;
parameter TX_PACKET_SIZE = 64;
parameter BIT_TIMING 	 = 434;
parameter IDLE_TIME 	 = BIT_TIMING;

output [8*RX_PACKET_SIZE-1:0] bytevect_out; 	// vector of bytes that have been read 
output [15:0] rx_size_ready; 						// to indicate how many bytes have been read
output rx_buffer_full;
output tx_done;
output [2:0] rx_state_out;
output tx_line; 										// data line going to the outside world
input rx_line; 										// input from the outside world
input rx_reset; 										// reset signal for the RX block
input clk;
input [8*TX_PACKET_SIZE-1:0] bytevect_in; 	// vector of bytes fed in from user
input [15:0] tx_size; 								// number of bytes to transmit
input tx_reset; 											// signal to indicate when to begin transmitting		

parameter 		TX_INIT 			= 0,
				TX_SEND_START_BIT 	= 1,
				TX_SEND_DATA_BIT 	= 2,
				TX_SEND_STOP_BIT 	= 3,
				TX_IDLE 			= 4;

parameter 		RX_INIT 				= 0,
				RX_WAIT_FOR_START_BIT 	= 1,
				RX_RECEIVE_DATA			= 2,
				RX_WAIT_FOR_STOP_BIT	= 3,
				RX_BUFFER_FULL 			= 4;

reg last_rx_line = 1;
reg [8*RX_PACKET_SIZE-1:0] rx_bytevect;
reg [15:0] rx_byte_ind = 0;
reg [15:0] rx_bit_ind = 0;
reg [15:0] tx_byte_ind = 0;
reg [15:0] tx_bit_ind = 0;
reg [2:0] rx_state = RX_WAIT_FOR_START_BIT;
reg [2:0] tx_state = TX_IDLE;
reg tx_data = 1;
reg rx_buf_full_reg = 0;
reg tx_done_reg = 0;
reg [31:0] rx_timer = 0;
reg [31:0] tx_timer = 0;
reg start_cond_detected = 0;

assign bytevect_out = rx_bytevect;
assign rx_size_ready = rx_byte_ind;
assign tx_line = tx_data;
assign rx_buffer_full = rx_buf_full_reg;
assign tx_done = tx_done_reg;
assign rx_state_out = rx_state;

// 
always @(posedge clk or posedge rx_reset or posedge tx_reset) begin

	// ==== The RX block ====
	if (rx_reset) begin
		// hold in reset
		rx_state = RX_INIT;
	end else begin
		// normal operation
		rx_timer = rx_timer + 1;

		// RX STATE MACHINE
		case (rx_state)
			RX_INIT: begin
				// just reset everything
				rx_byte_ind = 0;
				rx_bit_ind = 0;
				last_rx_line = rx_line;
				rx_state = RX_WAIT_FOR_START_BIT;
				rx_timer = 0;
				rx_buf_full_reg = 0;
				start_cond_detected = 0;
			end
			RX_WAIT_FOR_START_BIT: begin
				// look for start of start bit
				if (!rx_line && last_rx_line) begin
					// this is the start of the start condition
					start_cond_detected = 1;
					rx_timer = 0;
				end
				
				if (start_cond_detected && rx_timer >= BIT_TIMING) begin  // begin data collection
					rx_state = RX_RECEIVE_DATA;
					rx_timer = BIT_TIMING >> 1; // set this to halfway thru a sample period for timing
					rx_bit_ind = 0;
				end
				last_rx_line <= rx_line;
			end
			RX_RECEIVE_DATA: begin
				if(rx_timer >= BIT_TIMING) begin
					// sample the rx_bitline and store in RX byte-vector
					rx_bytevect[(rx_byte_ind << 3) + rx_bit_ind] = rx_line;
					rx_bit_ind = rx_bit_ind + 1;
					rx_timer = 0;
				end
				
				// check if we've seen the last data bit
				if (rx_bit_ind == 8) begin
					rx_byte_ind = rx_byte_ind + 1;
					rx_timer = 0;
					rx_state = RX_WAIT_FOR_STOP_BIT;
				end
			end
			RX_WAIT_FOR_STOP_BIT: begin
				if (rx_timer >= (BIT_TIMING >> 1)) begin
					if (rx_line) begin
						// the end is here!
						last_rx_line = rx_line;
						rx_timer = 0;
						start_cond_detected = 0;
						rx_state = RX_WAIT_FOR_START_BIT;
						if(rx_byte_ind >= RX_PACKET_SIZE) begin
							rx_buf_full_reg = 'b1;
							rx_state = RX_BUFFER_FULL;
						end
					end
				end
			end
			RX_BUFFER_FULL: begin
				// idle here until a reset condition occurs
				rx_buf_full_reg = 'b1;
			end
			default: begin
				rx_state <= RX_INIT;
			end
		endcase
	end // end else


	// ==== The TX block ====
	if (tx_reset) begin
		// hold tx block in reset
		tx_state = TX_INIT;
	end else begin

		tx_timer = tx_timer + 1;

		// TX STATE MACHINE
		case (tx_state) 
			TX_INIT: begin
				tx_byte_ind = 0;
				tx_bit_ind = 0;
				tx_timer = 0;
				tx_done_reg = 0;
				tx_state = TX_SEND_START_BIT;
			end
			TX_SEND_START_BIT: begin
				tx_data = 0;
				// tx_timer = tx_timer + 1;
				if (tx_timer >= BIT_TIMING) begin
					tx_timer = 0;
					tx_bit_ind = 0;
					tx_state = TX_SEND_DATA_BIT;
				end
			end
			TX_SEND_DATA_BIT: begin
				tx_data = bytevect_in[(tx_byte_ind << 3) + (tx_bit_ind)];
				// tx_timer = tx_timer + 1;
				if (tx_timer >= BIT_TIMING) begin
					tx_bit_ind = tx_bit_ind + 1;
					tx_timer = 0;
				end

				if (tx_bit_ind >= 8) begin
					tx_byte_ind = tx_byte_ind + 1;
					tx_timer = 0;
					tx_state = TX_SEND_STOP_BIT;
				end
			end
			TX_SEND_STOP_BIT: begin
				tx_data = 'b1;
				if (tx_timer >= (BIT_TIMING + IDLE_TIME)) begin
					tx_timer = 0;
					if (tx_byte_ind >= tx_size || tx_byte_ind >= TX_PACKET_SIZE) begin
						tx_done_reg = 'b1;
						tx_state = TX_IDLE;
					end else begin
						tx_state = TX_SEND_START_BIT;
					end
				end
			end
			default: begin
				tx_state = TX_IDLE;
			end
		endcase
	end // end else
end

endmodule
