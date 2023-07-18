// Pack unit
`timescale 1ns/1ps
`include "defs.vh"

module unum4_pack0 #(	
        parameter DATA_W = 32,
        parameter MAN_MAX_W = 29,
        parameter EXP_SZ_W = 4,
        parameter EXP_MAX_W = 16,
        parameter EXTRA = 0
   )   
   (
        input                                clk,
        input                                rst,
        input                                start,
        output reg                           done,
        input[EXP_MAX_W-1:0]                 exp,
        input[MAN_MAX_W-1:0]                 mant,
        output reg[DATA_W-1:0]               o
   );

  wire [EXP_MAX_W-1:0]          lz;
  wire [EXP_SZ_W-1:0]           exp_size;
  wire [EXP_MAX_W-1:0]          stcomp_exp;
  
  integer signed                i,k,n,z,y;
  
  reg [DATA_W-1:0]              data_out;
  reg [EXP_MAX_W-1:0]           exp_reg;
  reg[MAN_MAX_W-1:0]            mant_reg;
  reg [EXP_MAX_W-1:0]           stcomp_exp_reg;
  reg                           ready, done_reg1;
  

//Pipeline Stage 1  
  always @(posedge clk) begin
    if(rst) begin
      exp_reg <= {EXP_MAX_W{1'b0}};
      mant_reg <= {MAN_MAX_W{1'b0}};
      ready <= 1'b0;
    end else begin
      exp_reg <= exp;
      mant_reg <= mant;
      ready <= start;
    end
  end
  
// Exponent Conversion (1's Complement)  
  assign stcomp_exp = (exp_reg[EXP_MAX_W-1]==1'b1)? (mant_reg[MAN_MAX_W-1]==mant_reg[MAN_MAX_W-2])? exp_reg-EXP_MAX_W'(2): exp_reg-1'b1:exp_reg;
 
// Pipeline Stage 2 
  always @(posedge clk) begin
    if(rst) begin
      stcomp_exp_reg <= {EXP_MAX_W{1'b0}};
      
      done_reg1 <= 1'b0;
    end else begin
      stcomp_exp_reg <= stcomp_exp;
      
      done_reg1 <= ready;
    end
  end
  
 // Exponent Size Calculation      
  unum4_clz #(.MAN_MAX_W(EXP_MAX_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA)) exp_lz (
        .data_in(stcomp_exp_reg),
        .data_out(lz)
   );  

  assign exp_size = (mant_reg[MAN_MAX_W-1] == mant_reg[MAN_MAX_W-2])? (stcomp_exp_reg == {EXP_MAX_W{1'b0}})? {EXP_SZ_W{1'b0}} :{EXP_SZ_W{1'b1}}: {EXP_MAX_W'(EXP_MAX_W-1)-lz}[EXP_SZ_W-1:0];

// Pack  
  always @(*) begin
    z=0;	    
    y = {{32-EXP_SZ_W{1'b0}}, exp_size};
    data_out=0;
    if(exp_size ==0)
      data_out = {mant_reg[MAN_MAX_W-2:0],exp_size};
    else begin
      for(i=0;i<EXP_SZ_W;i=i+1) begin
        data_out[i] = exp_size[i];
      end
      for(k=EXP_SZ_W;k<DATA_W;k=k+1) begin
        if(k<DATA_W-{{32-EXP_SZ_W{1'b0}},exp_size}) begin
	data_out[k] = mant_reg[y];
	y=y+1'b1;
	end
      end
      for(n=0; n<DATA_W; n=n+1) begin
        if(n>=DATA_W-{{32-EXP_SZ_W{1'b0}},exp_size}) begin
        data_out[n] = stcomp_exp[z]; 
        z=z+1'b1;
        end
      end
    end
  end

// Pipeline Stage 3 
  always @(posedge clk) begin
    if (rst) begin
      o <= 0;
      done <= 1'b0;
    end else begin
      o <= data_out;
      done <= done_reg1;
    end
  end 
  
  

endmodule
	  
