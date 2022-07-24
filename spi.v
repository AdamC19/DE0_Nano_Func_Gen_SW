////////////////////////////////////////////////////////////////////////////////
//
//  spi_controller
//  ==============
//  USAGE:
//  - spi_begin starts LOW.
//  - set mode and msb_first as required.
//  - load spi_tx_data with the data you wish to send and set spi_xfer_len.
//  - take spi_begin HIGH (starts spi transaction).
//  - monitor cs output to know when xfer is complete.
//  - data received on miso appears in spi_rx_data as it comes in.
//  - received data len = spi_xfer_len
//
//  PARAMETER(s):
//  -------------
//      (none that one should change)
//
//  OUTPUT(s)           : BITS  : DESCRIPTION
//  -----------------------------------------
//      spi_rx_data     : 64    : vector containing the data received in last xfer
//      sclk            : 1     : SPI clock output
//      mosi            : 1     : MOSI data output
//      cs              : 1     : Chip Select line output
//
//  INPUT(s):           : BITS  : DESCRIPTION
//  -----------------------------------------
//      miso            : 1     : MISO data in
//      clk_50          : 1     : 50MHz system clock
//      clk_div         : 32    : how much to divide clk_50 by to produce sclk
//      mode            : 2     : standard spi mode {CPOL, CPHA}
//      msb_first       : 1     : indicates if MS BIT should come first (in & out)
//      spi_tx_data     : 64    : vector containing data to transmit in next xfer
//      spi_xfer_len    : 8     : number of bits to transfer in next transaction
//      spi_begin       : 1     : rising edge signals module to start transaction
//
////////////////////////////////////////////////////////////////////////////////
module spi_controller(
    spi_rx_data, 
    sclk,
    mosi,
    cs,
    miso,
    clk_50, 
    clk_div, 
    mode, 
    msb_first,
    spi_tx_data, 
    spi_xfer_len, 
    spi_begin
);

output [63:0] spi_rx_data;
output sclk;
output mosi;
output cs;

input miso;
input clk_50; // 50 MHz clock in
input [31:0] clk_div;
input [1:0] mode; // the spi mode
input msb_first; // 1 indicates data comes and goes MSB first
input [63:0] spi_tx_data; // data to send
input [7:0] spi_xfer_len; // bytes of data to send
input spi_begin;

wire spi_clk;

divider CLOCK_DIV(spi_clk, clk_50, clk_div);

parameter   STATE_STARTUP   = 0,
            STATE_IDLE      = 1,
            STATE_INIT      = 2,
            STATE_TRANSFER  = 3;

reg last_spi_begin;
reg [2:0] spi_state;
reg txfer_done_reg;
reg signed [7:0] txfer_bit_ind;

reg cs_reg = 1;
reg mosi_reg = 0;
reg en_sclk = 0;
reg sclk_reg = 0; // state of the sclk line (different from the internal spi_clk)

assign cs = cs_reg;
assign mosi = mosi_reg;
assign sclk = sclk_reg;

always @(posedge spi_begin or spi_clk) begin
    if (spi_begin && !last_spi_begin) begin
        // go to init state
        spi_state <= STATE_INIT;
    end
    last_spi_begin <= spi_begin;

    // handle data
    case (spi_state)
        STATE_STARTUP: begin
            last_spi_begin <= spi_begin;
            spi_state <= STATE_IDLE;
            txfer_done_reg <= 'b0;
            cs_reg <= 'b1;
            mosi_reg <= 'b0;
        end
        STATE_IDLE:begin
            sclk_reg <= mode[1]; // keep clock in correct idle mode
        end
        STATE_INIT: begin
            cs_reg <= 'b0; // will be low for 1 cycle before clock pulses start
            
            if (msb_first) begin
                txfer_bit_ind <= spi_xfer_len - 1; // set this to end index
            end else begin
                txfer_bit_ind <= 8'h00; // set this to 0
            end
            
            txfer_done_reg <= 'b0;
            if (mode[0] == 'b0) begin
                // need to set up MOSI with first data bit before leading edge of sclk
                if(msb_first) begin
                    mosi_reg <= spi_tx_data[spi_xfer_len - 1];
                end else begin
                    mosi_reg <= spi_tx_data[0];
                end
                
            end
        end
        STATE_TRANSFER: begin
            if (spi_clk) begin
                // we detected the leading edge of spi_clk

                if ((msb_first && tx_bit_ind < 0) || (!msb_first && tx_bit_ind >= spi_xfer_len)) begin
                    // we've sent all our bits already so
                    // don't produce another clock pulse.
                    // flag that we're done and enter IDLE state
                    txfer_done_reg <= 'b1;
                    spi_state <= STATE_IDLE;
                end else begin
                    // so produce leading edge of sclk
                    sclk_reg <= ~mode[1]; // ASSERT SCLK

                    if (mode[0] == 'b0) begin
                        // need to sample data on MISO
                        spi_rx_data[txfer_bit_ind] <= miso;

                        // inc or dec to next bit so when we hit trailing edge, we're ready
                        if (msb_first) begin
                            txfer_bit_ind <= txfer_bit_ind - 1;
                        end else begin
                            txfer_bit_ind <= txfer_bit_ind + 1;
                        end
                    end else begin
                        // CPHA == 1
                        // need to change MOSI
                        mosi_reg <= spi_tx_data[txfer_bit_ind];
                    end
                end
                
                
            end else begin
                // we detected the trailing edge of spi_clk
                sclk_reg <= mode[1]; // DEASSERT SCLK

                if (mode[0] == 'b0) begin
                    // CPHA = 0
                    // need to change state of MOSI with new data bit
                    mosi_reg <= spi_tx_data[txfer_bit_ind];
                end else begin
                    // CPHA = 1
                    // need to sample MISO
                    spi_rx_data[txfer_bit_ind] <= miso;

                    // advance to next bit
                    if (msb_first) begin
                        txfer_bit_ind <= txfer_bit_ind - 1;
                    end else begin
                        txfer_bit_ind <= txfer_bit_ind + 1;
                    end
                end
            end
        end
    endcase
end

endmodule