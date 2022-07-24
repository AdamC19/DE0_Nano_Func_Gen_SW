////////////////////////////////////////////////////////////////////////////////
//
// binary_to_ascii_bin 
//  - produces a single ascii code(either '0' or '1') corresponding to the 
//      binary bit provided.
//
//  OUTPUT(s):
//      ascii   8-bits
//  INPUT(s):
//      binary  1-bit
//
////////////////////////////////////////////////////////////////////////////////
module binary_to_ascii_bin(ascii, binary);

output [7:0] ascii;
input binary;

reg [7:0] ascii_reg;

assign ascii = (binary ? 8'd49 : 8'd48);

end

endmodule



////////////////////////////////////////////////////////////////////////////////
//
// binary_to_ascii_hex
//  - produces single ascii code corresponding to the 4-bit binary number fed in
//
//  OUTPUT(s):
//      ascii   8-bits
//  INPUT(s):
//      binary  4-bits
//
////////////////////////////////////////////////////////////////////////////////
module binary_to_ascii_hex(ascii, binary);

output [7:0] ascii;
input [3:0] binary;

reg [7:0] ascii_reg;

assign ascii = ascii_reg;

always @(*) begin
    if(binary > 9) begin
        ascii_reg <= binary + 55;
    end else begin
        ascii_reg <= binary + 48;
    end
end
endmodule

////////////////////////////////////////////////////////////////////////////////
//
//  hex_printer
//  ===========
//  - creates ascii codes for the input number as hexadecimal
//  - places the character for the highest-order 4-bits first in the output 
//      vector.
//
//  PARAMETER(s):
//  -------------
//      CHARACTERS : number of ASCII characters to put out
//
//  OUTPUT(s):
//  ----------
//      chars_out  : CHARACTERS*8 bits
//
//  INPUT(s):
//  ---------
//      number_in  : 32 bits
//
////////////////////////////////////////////////////////////////////////////////
module hex_printer(chars_out, number_in);

parameter CHARACTERS = 8;

output [8*CHARACTERS-1:0] chars_out;
input [31:0] number_in;

genvar i;
generate
    
    for(i=0; i<CHARACTERS; i=i+1) begin : genloop
        binary_to_ascii_hex BIN_TO_CHAR(chars_out[(i<<3)+:8], number_in[(((CHARACTERS-1)-i)<<2)+:4]);
    end

endgenerate

endmodule


////////////////////////////////////////////////////////////////////////////////
//
//  binary_printer
//  ==============
//  - creates ascii codes for the input number as binary
//  - places the character for the highest-order bit first in the output vector.
//
//  PARAMETER(s):
//  -------------
//      CHARACTERS number of ASCII characters to put out
//
//  OUTPUT(s):
//  ----------
//      chars_out  CHARACTERS*8 bits
//
//  INPUT(s):
//  ---------
//      number_in  32 bits
//
////////////////////////////////////////////////////////////////////////////////
module binary_printer(chars_out, binary_in);

parameter CHARACTERS = 8;

output [8*CHARACTERS-1:0] chars_out;
input [31:0] binary_in;

genvar i;
generate
    for(i=0; i<CHARACTERS; i=i+1) begin : genloop
        binary_to_ascii_bin BIN_TO_CHAR(chars_out[(i<<3)+:8], binary_in[(CHARACTERS-1)-i]);
    end
endgenerate

endmodule