`timescale 1ns / 1ps
`include "defs.vh"

module unum4_addsub #(	
        parameter MAN_MAX_W = 29,
        parameter EXTRA = 0
  	
   )
   
   (
        input                                  op,	
        input signed [MAN_MAX_W-1+EXTRA:0]     in1,
        input signed [MAN_MAX_W-1+EXTRA:0]     in2,
        output signed [MAN_MAX_W+EXTRA:0]      out,
        output                                 overflow
  );	
	
  wire [MAN_MAX_W+EXTRA:0] inverter= (op)? {MAN_MAX_W+1+EXTRA{1'b1}}:{MAN_MAX_W+1+EXTRA{1'b0}};
  wire [MAN_MAX_W+EXTRA:0] b =( inverter ^ {in2[MAN_MAX_W-1+EXTRA],in2})+{{MAN_MAX_W+EXTRA{1'b0}},op};

  assign out = {in1[MAN_MAX_W-1+EXTRA],in1}+{b};
  assign overflow = (op)? (in1[MAN_MAX_W-1+EXTRA] != in2[MAN_MAX_W-1+EXTRA] && out[MAN_MAX_W-1+EXTRA] == in2[MAN_MAX_W-1+EXTRA])?
         1'b1 : 1'b0: (in1[MAN_MAX_W-1+EXTRA] == in2[MAN_MAX_W-1+EXTRA] && out[MAN_MAX_W+-1+EXTRA] != in2[MAN_MAX_W-1+EXTRA])? 
         1'b1 : 1'b0;	
endmodule
