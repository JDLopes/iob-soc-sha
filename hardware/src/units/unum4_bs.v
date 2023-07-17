`timescale 1ns/1ps
`include "defs.vh"


module  unum4_bs #(      
        parameter MAN_MAX_W = 29,
        parameter EXP_MAX_W = 16,
        parameter EXTRA = 0        
   )
   (
        input signed [MAN_MAX_W-1+EXTRA:0]             data_in,
        output reg signed [MAN_MAX_W-1+EXTRA:0]        data_out,
        input                               		 left_nright,
        input [EXP_MAX_W-1:0]                          shift
    );

  always @(*)  begin 
    if(left_nright)
      data_out = data_in <<< shift; 
    else 
      data_out = data_in >>> shift;
  end
	
endmodule
