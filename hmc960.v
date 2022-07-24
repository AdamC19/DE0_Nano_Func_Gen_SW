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
input [BITS-1:0] clk_div;
input [BITS-1:0] tx_data;
input xfer_begin;
input reset;

wire spi_clk;

reg last_xfer_begin;
reg [2:0] spi_state;
reg signed [7:0] tx_bit_ind;
reg signed [7:0] rx_bit_ind;

reg cs_reg = 1;
reg mosi_reg = 0;
reg en_sclk = 0;
reg sclk_reg = 0; // state of the sclk line (different from the internal spi_clk)

assign cs = cs_reg;
assign mosi = mosi_reg;
assign sclk = sclk_reg;

divider CLOCK_DIV(spi_clk, clk_50, clk_div);


parameter   STATE_STARTUP   = 0,
            STATE_IDLE      = 1,
            STATE_INIT      = 2,
            STATE_TRANSFER  = 3;

always @(posedge reset or posedge xfer_begin or spi_clk) begin
    if(reset) begin
        // hold module in reset
        spi_state <= STATE_IDLE;
        cs_reg <= 'b1;
        mosi_reg <= 'b0;
        sclk_reg <= 'b0;
    end else begin

        case (spi_state)
            STATE_STARTUP: begin
                spi_state <= STATE_IDLE;
                cs_reg <= 'b1;
                mosi_reg <= 'b0;
                sclk_reg <= 'b0;
            end
            STATE_IDLE: begin
                sclk_reg <= 'b0; // ensure SCLK is LOW
                cs_rg <= 'b1; // ensure SEN is de-asserted
                tx_bit_ind <= BITS-1;
                rx_bit_ind <= BITS-1;

                // check if the xfer_begin line went high, indicating start condition
                if (xfer_begin && !last_xfer_begin) begin
                    // go to init state
                    spi_state <= STATE_INIT;
                end

            end
            STATE_INIT: begin
                if (!spi_clk) begin
                    // ensure this is a trailing/falling edge of SCLK

                    cs_reg <= 'b0; // will be low 1/2 cycle before clock pulses start

                    // setup data on MOSI (HMC960 SDI) line before leading edge of first clk
                    mosi_reg <= tx_data[tx_bit_ind];
                    tx_bit_ind <= tx_bit_ind - 1;

                    spi_state <= STATE_TRANSFER;
                end
            end
            STATE_TRANSFER: begin
                sclk <= spi_clk; // produce clk pulse, must do it this way to prevent glitching

                if (!spi_clk) begin
                    // TRAILING EDGE
                    rx_data[rx_bit_ind] <= miso;     // sample data on MISO (HMC960 SDO)
                    rx_bit_ind <= rx_bit_ind - 1;    // decrement

                    if (tx_bit_ind >= 0) begin    
                        mosi_reg <= tx_data[tx_bit_ind]; // change MOSI (HMC960 SDI) data
                        tx_bit_ind <= tx_bit_ind - 1;    // decrement to point to next tx bit
                    end else begin
                        // this is our last trailing edge
                        spi_state <= STATE_IDLE;
                    end
                    
                end 
            end
        endcase

        last_xfer_begin <= xfer_begin;
    end
    

end


endmodule