// Unpacking unit
`timescale 1ns/1ps
`include "defs.vh"

module unum4_unpack #(	
        parameter DATA_W = 32,
        parameter MAN_MAX_W = 29,
        parameter EXP_SZ_W = 4,
        parameter EXP_MAX_W = 16
   )
   (
        input                              clk,
        input                              rst,
        input                              start,
        output                             done,	                      
        input [DATA_W-1:0]                 x,   
        output reg [EXP_MAX_W-1:0]         e,
        output reg [MAN_MAX_W-1:0]         m
  );
   
   
  wire [EXP_SZ_W-1:0]                   EXP_W = x[EXP_SZ_W-1:0];
  integer                               i,k,a;
  reg [EXP_MAX_W-1:0]         exp;
  reg [MAN_MAX_W-1:0]         mant;
  reg ready,ready2,done_reg;
  reg exception;
  
  
  always @(posedge clk) begin
    if(rst)
      ready <= 1'b0;
    else
      ready <= start;
  end
  
   
  always @(*) begin
    exception=1'b0;
    if(EXP_W == {EXP_SZ_W{1'b0}})
      exp = 0;
    else begin
      exp = {EXP_MAX_W{~x[DATA_W-1]}}; //exp msb negated repeated `EXP_MAX_W times
      for (i=0; i<EXP_MAX_W; i=i+1) begin//overwrite exponent on the right
        if(i<EXP_W) begin
          exp[i] = x[DATA_W-32'(EXP_W)+i];
        end
      end
      if(exp == {1'b1,{EXP_MAX_W-1{1'b0}}})
        exception=1'b1;
      else if(exp[EXP_MAX_W-1]==1'b1)
        exp=exp+1'b1;
    end
  end
  
  
  always @(posedge clk) begin
    if(rst) begin
      e <= {EXP_MAX_W{1'b0}};
      ready2  <= 1'b0;
    end else begin
      if(exception)
        e <= {1'b1,{EXP_MAX_W-3{1'b0}},2'b10};
      else
        e <= exp;
      ready2 <=ready;
    end
  end

  always @* begin
    if(exception) begin
      mant = {MAN_MAX_W{1'b0}};
      mant[MAN_MAX_W-1]=x[DATA_W-32'(EXP_W)];
      for (k=EXP_SZ_W; k<=EXP_MAX_W;k=k+1) begin
          mant[k+32'(EXP_W)-EXP_SZ_W]=x[k];
      end
    end
    else begin 
      mant = {MAN_MAX_W{1'b0}};
      if(EXP_W==0)
        mant[MAN_MAX_W-1] = ~x[DATA_W-1];
      else
        mant[MAN_MAX_W-1] = ~x[DATA_W-32'(EXP_W)-1];
      for (a=0; a<MAN_MAX_W-1; a=a+1) begin
       if (a<(MAN_MAX_W-32'(EXP_W)-1))
          mant[a+32'(EXP_W)]=x[a+EXP_SZ_W];
      end
    end
  end
  
    always @(posedge clk) begin
    if(rst) begin
      m <= {MAN_MAX_W{1'b0}};
      done_reg <= 1'b0;
    end else begin
      m <= mant;
      done_reg <=ready2;
    end
  end
  
  assign done =done_reg;

endmodule
