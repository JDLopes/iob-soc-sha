`timescale 1ns / 1ps
`include "defs.vh"

module expdiff #( 
         parameter EXP_MAX_W = 16
   )
   (
         input signed [EXP_MAX_W-1:0]         e_a,
         input signed [EXP_MAX_W-1:0]         e_b,
         output signed [EXP_MAX_W:0]          diff_out,
         output signed [EXP_MAX_W-1:0]        e_larger     
   );
			
  wire signed [EXP_MAX_W:0] diff= e_a-e_b;
  
  assign e_larger = (e_a>e_b) ? e_a : e_b; 
  assign diff_out = (diff[EXP_MAX_W]) ? -diff: diff;	
		
endmodule
