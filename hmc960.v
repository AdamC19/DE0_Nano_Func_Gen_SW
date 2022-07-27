////////////////////////////////////////////////////////////////////////////////
//
//  hmc960
//  ======
//  The HMC960 uses a slightly non-standard SPI-esque serial interface. This
//  module implements that interface.
// 
//  USAGE:
//  ------
//  - xfer_begin starts LOW.
//  - load tx_data with the data you wish to send.
//  - take xfer_begin HIGH (starts spi transaction).
//  - monitor cs output to know when xfer is complete.
//  - data received on miso appears in rx_data as it comes in.
//
//  PARAMETER(s):
//  -------------
//      (none that one should change)
//
//  OUTPUT(s)           : BITS  : DESCRIPTION
//  -----------------------------------------
//      rx_data         : 32    : vector containing the data received in last xfer
//      sclk            : 1     : SPI clock output
//      mosi            : 1     : MOSI (HMC960 SDI) data out line
//      cs              : 1     : Chip Select line (HMC960 SEN) output
//
//  INPUT(s):           : BITS  : DESCRIPTION
//  -----------------------------------------
//      miso            : 1     : MISO (HMC960 SDO) data in line
//      clk             : 1     : 50MHz system clock
//      clk_div         : 32    : how much to divide clk_50 by to produce sclk
//      tx_data         : 32    : vector containing data to transmit in next xfer
//      xfer_begin      : 1     : rising edge signals module to start transaction
//      reset           : 1     : active high signal to hold everything in reset.
//                      :       :   goes to IDLE state upon release.
//
////////////////////////////////////////////////////////////////////////////////
module hmc960(
    rx_data,
    sclk,
    mosi,
    cs,
    miso,
    clk,
    clk_div,
    tx_data,
    xfer_begin,
    reset
);

parameter BITS = 32; // 32 clock cycles per transaction
parameter CHIP_ADDR = 3'b110; // fixed chip address bits

output [BITS-1:0] rx_data;
output sclk;
output mosi;
output cs;

input miso;
input clk;
input [31:0] clk_div;
input [BITS-1:0] tx_data;
input xfer_begin;
input reset;

wire spi_sys_clk;
reg spi_clk = 'b0;

reg last_xfer_begin;
reg last_reset;
reg [2:0] spi_state = STATE_IDLE;
reg signed [7:0] tx_bit_ind;
reg signed [7:0] rx_bit_ind;
reg [BITS-1:0] rx_data_reg;

reg cs_reg;
reg mosi_reg;
reg sclk_reg; // state of the sclk line (different from the internal spi_clk)

assign cs = cs_reg;
assign mosi = mosi_reg;
assign sclk = sclk_reg;
assign rx_data = rx_data_reg;

divider CLOCK_DIV(spi_sys_clk, clk, clk_div << 1); // spi_sys_clk runs twice as fast as spi_clk


parameter   STATE_IDLE      = 0,
            STATE_INIT      = 1,
            STATE_TRANSFER  = 2,
            STATE_FINAL_CLK = 3,
            STATE_SCLK_TO_SEN = 4;

always @(posedge reset or posedge spi_sys_clk or posedge xfer_begin) begin
    if(reset) begin
        // hold module in reset
        cs_reg <= 'b1;
        sclk_reg <= 'b0; // ensure SCLK is LOW
        mosi_reg <= 'b0;
        spi_state <= STATE_IDLE;
    end else if(xfer_begin) begin
        // while xfer_begin line is high, ensure we'll enter the start condition
        cs_reg <= 'b1;
        sclk_reg <= 'b0; // ensure SCLK is LOW
        mosi_reg <= 'b0;
        spi_state <= STATE_INIT;
    end else if (spi_sys_clk) begin
        spi_clk <= ~spi_clk; // toggle the actual SPI bus clock register
        case (spi_state)
            STATE_IDLE: begin
                sclk_reg <= 'b0; // ensure SCLK is LOW
                mosi_reg <= 'b0;
                cs_reg <= 'b1; // ensure SEN is de-asserted
                tx_bit_ind <= BITS-1;
                rx_bit_ind <= BITS-1;
            end
            STATE_INIT: begin
                cs_reg <= 'b0; // will be low at least 1/2 cycle before clock pulses start
                sclk_reg <= 'b0; // no point in sending this high until STATE_TRANSFER

                if (!spi_clk) begin
                    // for timing purposes, ensure this is a falling edge of spi_clk
                    
                    // setup data on MOSI (HMC960 SDI) line before leading edge of first clk
                    mosi_reg <= tx_data[tx_bit_ind];
                    tx_bit_ind <= tx_bit_ind - 1;

                    spi_state <= STATE_TRANSFER;
                end 
                // else begin
                //     spi_state = STATE_INIT;
                // end
            end
            STATE_TRANSFER: begin
                cs_reg <= 'b0;
                sclk_reg <= spi_clk; // produce clk pulse, must do it this way to prevent glitching

                if (!spi_clk) begin
                    // TRAILING EDGE
                    rx_data_reg[rx_bit_ind] <= miso;     // sample data on MISO (HMC960 SDO)
                    rx_bit_ind <= rx_bit_ind - 1;    // decrement

                    mosi_reg <= tx_data[tx_bit_ind]; // change MOSI (HMC960 SDI) data

                    if (tx_bit_ind == 0) begin
                        // this is our last trailing edge
                        spi_state <= STATE_FINAL_CLK;
                    end else begin
                        tx_bit_ind <= tx_bit_ind - 1;    // decrement to point to next tx bit
                        // spi_state <= STATE_TRANSFER;
                    end
                    
                end
            end
            STATE_FINAL_CLK: begin
                sclk_reg <= spi_clk;
                if (spi_clk) begin
                    spi_state <= STATE_SCLK_TO_SEN;
                end
            end
            STATE_SCLK_TO_SEN: begin
                sclk_reg <= spi_clk;
                spi_state <= STATE_IDLE;
            end
            default: begin
                cs_reg = 'b1;
                spi_state = STATE_IDLE;
            end
        endcase

    end

end


endmodule