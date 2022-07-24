
//=======================================================
//  This code is generated by Terasic System Builder
//=======================================================

module function_generator(

	//////////// CLOCK //////////
	CLOCK_50,

	//////////// LED //////////
	LED,

	//////////// KEY //////////
	KEY,

	//////////// SW //////////
	SW,

	//////////// SDRAM //////////
	DRAM_ADDR,
	DRAM_BA,
	DRAM_CAS_N,
	DRAM_CKE,
	DRAM_CLK,
	DRAM_CS_N,
	DRAM_DQ,
	DRAM_DQM,
	DRAM_RAS_N,
	DRAM_WE_N,

	//////////// EPCS //////////
	EPCS_ASDO,
	EPCS_DATA0,
	EPCS_DCLK,
	EPCS_NCSO,

	//////////// Accelerometer and EEPROM //////////
	G_SENSOR_CS_N,
	G_SENSOR_INT,
	I2C_SCLK,
	I2C_SDAT,

	//////////// ADC //////////
	ADC_CS_N,
	ADC_SADDR,
	ADC_SCLK,
	ADC_SDAT,

	//////////// 2x13 GPIO Header //////////
	GPIO_2,
	GPIO_2_IN,

	//////////// GPIO_0, GPIO_0 connect to GPIO Default //////////
	gpio0,
	gpio0_IN,

	//////////// GPIO_1, GPIO_1 connect to GPIO Default //////////
	gpio1,
	gpio1_IN 
);

//=======================================================
//  PARAMETER declarations
//=======================================================


//=======================================================
//  PORT declarations
//=======================================================

//////////// CLOCK //////////
input 		          		CLOCK_50;

//////////// LED //////////
output		     [7:0]		LED;

//////////// KEY //////////
input 		     [1:0]		KEY;

//////////// SW //////////
input 		     [3:0]		SW;

//////////// SDRAM //////////
output		    [12:0]		DRAM_ADDR;
output		     [1:0]		DRAM_BA;
output		          		DRAM_CAS_N;
output		          		DRAM_CKE;
output		          		DRAM_CLK;
output		          		DRAM_CS_N;
inout 		    [15:0]		DRAM_DQ;
output		     [1:0]		DRAM_DQM;
output		          		DRAM_RAS_N;
output		          		DRAM_WE_N;

//////////// EPCS //////////
output		          		EPCS_ASDO;
input 		          		EPCS_DATA0;
output		          		EPCS_DCLK;
output		          		EPCS_NCSO;

//////////// Accelerometer and EEPROM //////////
output		          		G_SENSOR_CS_N;
input 		          		G_SENSOR_INT;
output		          		I2C_SCLK;
inout 		          		I2C_SDAT;

//////////// ADC //////////
output		          		ADC_CS_N;
output		          		ADC_SADDR;
output		          		ADC_SCLK;
input 		          		ADC_SDAT;

//////////// 2x13 GPIO Header //////////
inout 		    [12:0]		GPIO_2;
input 		     [2:0]		GPIO_2_IN;

//////////// GPIO_0, GPIO_0 connect to GPIO Default //////////
inout 		    [33:0]		gpio0;
input 		     [1:0]		gpio0_IN;

//////////// GPIO_1, GPIO_1 connect to GPIO Default //////////
inout 		    [33:0]		gpio1;
input 		     [1:0]		gpio1_IN;


//=======================================================
//  REG/WIRE declarations
//=======================================================

/* UART STUFF */
parameter STRING_BUF_SIZE = 80; // 80 characters is the width of a standard terminal
reg [STRING_BUF_SIZE*8-1:0] uart_tx_buf;
wire [STRING_BUF_SIZE*8-1:0] uart_rx_buf; // whatever we receive from the uart
wire [15:0] rx_size;
wire rx_buf_full;
wire tx_done;
reg [15:0] tx_size;
reg tx_reset;
reg rx_reset;

/* SWITCH STUFF */
wire [3:0] sw_states;
reg [3:0] led_states;

/* ENCODER STUFF */
wire [31:0] freq_enc_counts;
wire [31:0] freq_enc_period;
wire freq_enc_dir;
reg freq_enc_reset;
wire [31:0] amp_enc_counts;
wire [31:0] amp_enc_period;
wire amp_enc_dir;
reg amp_enc_reset;
reg amp_offset_toggle;

/* HMC960 VGA and SPI STUFF */
wire [31:0] hmc960_rx_data;
reg [31:0] hmc960_clk_div;
reg [31:0] hmc960_tx_data;
wire hmc960_cs;
reg spi_begin;
reg spi_reset;
parameter 	HMC960_STATE_INIT_REG_1 = 0,
			HMC960_STATE_INIT_REG_2 = 1,
			HMC960_STATE_SET_GAIN 	= 2,
			HMC960_STATE_IDLE 		= 3;
reg [2:0] hmc960_state = HMC960_STATE_IDLE;

/* GENERAL FUNCTION GEN STUFF */
parameter 	WAVEFORM_OFF 	= 0,
			WAVEFORM_SINE	= 1,
			WAVEFORM_TRI 	= 2,
			WAVEFORM_SQR 	= 3,
			WAVEFORM_ARB 	= 4;

/* MAIN STATE MACHINE */
parameter 	STATE_STARTUP 	= 0,
			STATE_RUN 		= 1;
parameter 	STARTUP_DELAY 	= 1024;
reg [2:0] waveform_select = WAVEFORM_OFF;
reg [2:0] func_gen_state = STATE_STARTUP;
reg [31:0] func_gen_clk_div = 32'h98;
reg [7:0] gain_setting = 0;
reg [7:0] last_gain_setting = 0;
reg [15:0] startup_counter = 0;
reg [8:0] duty_cycle;
wire [7:0] sine_word;
wire [7:0] tri_word;
wire [7:0] sqr_word;
wire [7:0] arb_word;
reg [7:0] offset = 8'd128;

//=======================================================
//  Structural coding
//=======================================================
/* UART STUFF */
// GPIO_00 is FPGA TX, pipe data from UART out to GPIO_00
// GPIO_01 is FPGA RX, pipe data into UART from GPIO_01
uart UART_BLOCK(uart_rx_buf, rx_size, rx_buf_full, tx_done, rx_state, gpio0[0], gpio0[1], rx_reset, CLOCK_50, uart_tx_buf, tx_size, tx_reset);

/* Switch debouncing */
debounce DEBOUNCER_SW_A(sw_state[0], CLOCK_50, gpio0[10]);
debounce DEBOUNCER_SW_B(sw_state[1], CLOCK_50, gpio0[12]);
debounce DEBOUNCER_SW_C(sw_state[2], CLOCK_50, gpio0[14]);
debounce DEBOUNCER_SW_D(sw_state[3], CLOCK_50, gpio0[16]);

/* LED assignments */
assign gpio0[11] = led_states[0];
assign gpio0[13] = led_states[1];
assign gpio0[15] = led_states[2];
assign gpio0[17] = led_states[3];
assign gpio1[15] = hmc960_cs;

/* ENCODER STUFF */
encoder FREQ_ENC(freq_enc_counts, freq_enc_period, freq_enc_dir, CLOCK_50, gpio0[6], gpio0[7], freq_enc_reset);
encoder AMP_ENC(amp_enc_counts, amp_enc_period, amp_enc_dir, CLOCK_50, gpio0[8], gpio0[9], amp_enc_reset);

/* SPI STUFF */
hmc960 HMC960_CTL(hmc960_rx_data, gpio1[16], gpio1[17], hmc960_cs, gpio1[18], CLOCK_50, hmc960_clk_div, hmc960_tx_data, spi_begin, spi_reset);

/* FUNCTION GENERATION STUFF */
sine_wave SINE_GENERATOR(sine_word, CLOCK_50, func_gen_clk_div);
triangle_wave TRIANGLE_GENERATOR(tri_word, CLOCK_50, func_gen_clk_div);
square_wave #(.DUTY_CYCLE_BITS(9)) SQUARE_GENERATOR(sqr_word, CLOCK_50, func_gen_clk_div, duty_cycle);

assign gpio0[9:2] = (	waveform_select == WAVEFORM_SINE ? sine_word : 
						(waveform_select == WAVEFORM_TRI ? tri_word : 
						(waveform_select == WAVEFORM_SQR ? sqr_word : 
						(waveform_select == WAVEFORM_ARB ? arb_word : 8'h00))));

assign gpio1[26:19] = offset[7:0];

/* MAIN STATE MACHINE */
always @(posedge CLOCK_50) begin
	case (func_gen_state)
		STATE_STARTUP: begin
			startup_counter <= startup_counter + 1;
			if(startup_counter < (STARTUP_DELAY >> 1)) begin
				// Assert reset signals
				spi_reset <= 'b1;
				freq_enc_reset <= 'b1;
				amp_enc_reset <= 'b1;
				tx_reset <= 'b1;
				rx_reset <= 'b1;
				hmc960_state <= HMC960_STATE_IDLE;
			end else if(startup_counter < STARTUP_DELAY) begin
				// deassert reset signals
				spi_reset <= 'b0;
				freq_enc_reset <= 'b0;
				amp_enc_reset <= 'b0;
				tx_reset <= 'b0;
				rx_reset <= 'b0;
				hmc960_state <= HMC960_STATE_INIT_1; // to begin setup on next clock cycle
				
			end else begin
				// STARTUP_DELAY counts have elapsed, but need to check if HMC960 is all set up
				if (!spi_begin && hmc960_cs && hmc960_state == HMC960_STATE_IDLE) begin
					func_gen_state <= STATE_RUN; // finally enter run state
				end
			end

			if (!spi_reset && !spi_begin && hmc960_cs) begin
				// spi is not in reset, spi_begin is deasserted, and spi xfer is not in progress (done)
				// so we can run through the setup state machine
				case (hmc960_state)
					HMC960_STATE_IDLE: begin // do nothing
					end
					HMC960_STATE_INIT_REG_1: begin
						hmc960_tx_data[31:8] <= 24'b10; // enable Q channel, disable I channel
						hmc960_tx_data[7:0] <= {5'h1, 3'b110}; // address reg 1, chip id = 110b
						spi_begin <= 'b1; // send spi_begin high
						hmc960_state <= HMC960_STATE_INIT_REG_2; // goto next state
					end
					HMC960_STATE_INIT_REG_2: begin
						hmc960_tx_data[31:8] <= 24'b00111001; // 
						hmc960_tx_data[7:0] <= {5'h2, 3'b110}; // address reg 2, chip id = 110b
						spi_begin <= 'b1; // send spi_begin high
						hmc960_state <= HMC960_STATE_IDLE; // next we'll set initial gain
					end
					HMC960_STATE_SET_GAIN: begin
						// TODO read last gain from EEPROM
						hmc960_tx_data[31:8] <= 24'b0; // 0dB gain
						hmc960_tx_data[7:0] <= {5'h3, 3'b110}; // address reg 3, chip id = 110b
						spi_begin <= 'b1; // send spi_begin high
						hmc960_state <= HMC960_STATE_IDLE; // done with setup, goto IDLE
					end
					default: begin
						hmc960_state <= HMC960_STATE_IDLE;
					end
				endcase
			end else if (!hmc960_cs) begin
				// spi is in progress, so we can reset spi_begin
				spi_begin <= 'b0;
			end
		end
		STATE_RUN: begin
			if(!spi_begin && hmc960_cs) begin
				if(last_gain_setting != gain_setting) begin
					hmc960_tx_data[14:8] <= gain_setting[6:0]; // 0dB gain
					hmc960_tx_data[7:0] <= {5'h3, 3'b110}; // address reg 3, chip id = 110b
					spi_begin <= 'b1; // send spi_begin high
				end
				last_gain_setting <= gain_setting;
			end else if(!hmc960_cs) begin
				spi_begin <= 'b0;
			end
			
		end
		default: begin
			func_gen_state <= STATE_STARTUP;
		end
	endcase
end

/* CHANGE FREQUENCY */
always @(freq_enc_counts) begin
	// increment or decrement based on period
	// long period indicates small increment
	// small period indicates big increment

	if (freq_enc_period > 25000000) begin // greater than 500ms
		if (freq_enc_dir) begin
			func_gen_clk_div <= func_gen_clk_div - 1;
		end else begin
			func_gen_clk_div <= func_gen_clk_div + 1;
		end
	end else if (freq_enc_period > 5000000) begin // 100ms < period < 500ms
		if (freq_enc_dir) begin
			func_gen_clk_div <= func_gen_clk_div - 5;
		end else begin
			func_gen_clk_div <= func_gen_clk_div + 5;
		end
	end else if (freq_enc_period > 1000000) begin // 20ms < period < 100ms
		if (freq_enc_dir) begin
			func_gen_clk_div <= func_gen_clk_div - 10;
		end else begin
			func_gen_clk_div <= func_gen_clk_div + 10;
		end
	end else begin // anything less than 20ms
		if (freq_enc_dir) begin
			func_gen_clk_div <= func_gen_clk_div - 25;
		end else begin
			func_gen_clk_div <= func_gen_clk_div + 25;
		end
	end
	
end

/* function for changing gain and making sure it doesn't exceed the limits */
function [7:0] change_gain;
	input signed [7:0] gain;
	input signed [7:0] delta;
	input dir;
	begin
		if (dir) begin
			// decrement
			if ((gain - delta) >= 0) begin
				change_gain = gain - delta;
			end else begin
				change_gain = 0;
			end
		end else begin
			// increment
			if ((gain + delta) <= 80) begin
				change_gain = gain + delta;
			end else begin
				change_gain = 8'd80;
			end
		end
	end
endfunction

/* function for changing offset making sure it doesn't exceed the limits */
function [7:0] change_offset;
	input [7:0] offset;
	input signed [7:0] delta;
	begin
		if (delta < 0) begin
			if ((offset + delta) > offset) begin
				change_offset = 0;
			end
		end else begin
			if ((offset + delta) < offset) begin
				change_offset = 255;
			end
		end
	end
endfunction

/* CHANGE AMPLITUDE */
always @(amp_enc_counts) begin
	// increment or decrement based on period
	// long period indicates small increment
	// small period indicates big increment
	if(!amp_offset_toggle) begin
		if (amp_enc_period > 25000000) begin // greater than 500ms
			gain_setting <= change_gain(gain_setting, 1, amp_enc_dir);
		end else if (amp_enc_period > 5000000) begin // 100ms < period < 500ms
			gain_setting <= change_gain(gain_setting, 2, amp_enc_dir);
		end else if (amp_enc_period > 1000000) begin // 20ms < period < 100ms
			gain_setting <= change_gain(gain_setting, 3, amp_enc_dir);
		end else begin // anything less than 20ms
			gain_setting <= change_gain(gain_setting, 4, amp_enc_dir);
		end
	end else begin
		// change offset instead
		if (amp_enc_period > 25000000) begin // greater than 500ms
			offset <= change_offset(offset, 1);
		end else if (amp_enc_period > 5000000) begin // 100ms < period < 500ms
			offset <= change_offset(offset, 2);
		end else if (amp_enc_period > 1000000) begin // 20ms < period < 100ms
			offset <= change_offset(offset, 4);
		end else begin // anything less than 20ms
			offset <= change_offset(offset, 8);
		end
	end
end

always @(negedge sw_state[3]) begin
	amp_offset_toggle <= ~amp_offset_toggle;
end

/* WAVEFORM SELECT BUTTON */
always @(negedge sw_state[0]) begin
	// waveform select button
	if (!sw_state[0]) begin
		if ((waveform_select == WAVEFORM_ARB) begin
			// advance to state 0
			waveform_select <= 0;
		end else begin
			// advance to next state
			waveform_select <= waveform_select + 1;
		end
	end
end

/* UP AND DOWN BUTTONS */
always @(negedge sw_state[1] or negedge sw_state[2]) begin
	if(!sw_state[1]) begin
		// up button pressed
	end else if (!sw_state[2]) begin
		// down button pressed
	end
end

/* ENABLE/DISABLE BUTTON */

endmodule
