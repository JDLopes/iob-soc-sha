//Leading Zeros/Ones Detector
`timescale 1ns / 1ps
`include "defs.vh"

module unum4_clz #(	
        parameter MAN_MAX_W = 29,
        parameter EXP_MAX_W = 16,
        parameter EXTRA = 0        
   )
   (
        input [MAN_MAX_W-1+EXTRA:0]     data_in,
        output reg[EXP_MAX_W-1:0]       data_out
   );

  integer i,stop;  

   
  always @ (*) begin 
    data_out=0;
    stop=0;
    for ( i = MAN_MAX_W-1+EXTRA; i >=1; i = i - 1) begin
    if(stop==0) begin
      if (data_in[i]!=data_in[i-1])
        stop=1;
      else
        data_out=data_out+1;
      end 
   end
  end 
     
endmodule
