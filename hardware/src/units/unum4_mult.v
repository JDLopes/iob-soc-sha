//Multiplication Unit
`timescale 1ns/1ps
`include "defs.vh"

module unum4_mult #(	
        parameter DATA_W = 32,
  	parameter MAN_MAX_W = 29,
        parameter EXP_SZ_W = 4,
        parameter EXP_MAX_W = 16,
        parameter EXTRA = 0        
   )
   (
        input                                   clk,
        input                                   rst,
        input                                   start,
        output reg                              done,
        input signed[MAN_MAX_W-1:0]             m_a,
        input signed[MAN_MAX_W-1:0]             m_b,
        input [EXP_MAX_W-1:0]                   e_a,
        input [EXP_MAX_W-1:0]                   e_b,
        output reg[MAN_MAX_W-1+EXTRA:0]         m_o,
        output reg[EXP_MAX_W-1:0]               e_o,
        output reg                              over,
        output reg                              under
   );

  wire signed[MAN_MAX_W-1+EXTRA:0]    mant, shifted_mant_0, shifted_mant_1, in1, in2;
  wire signed[2*MAN_MAX_W-1:0]        prod_mant;
  wire signed[EXP_MAX_W:0]            temp_exp_add, e_temp, temp_exp;
  wire signed[EXP_MAX_W-1:0]          leadings;
  wire signed[EXP_MAX_W+1:0]          r_shift;
  wire                                sticky;
  
  reg [EXP_MAX_W-1:0]                 e_a_reg;
  reg signed [MAN_MAX_W-1:0]          m_a_reg; 
  reg [EXP_MAX_W-1:0]                 e_b_reg, leadings_reg;
  reg signed [MAN_MAX_W-1:0]          m_b_reg; 
  reg signed[MAN_MAX_W-1+EXTRA:0]     mant_reg, shifted_mant_0_reg;
  reg signed[EXP_MAX_W:0]             temp_exp_add_reg, e_temp_reg, temp_exp_reg;
  reg signed[EXP_MAX_W+1:0]           r_shift_reg;
  reg signed[2*MAN_MAX_W-1:0]         prod_mant_reg,inter;
  reg                                 done_reg1, done_reg2, done_reg3,done_reg4;
  
// Pipeline Stage 1  
  always @(posedge clk) begin
    if (rst) begin
      e_a_reg <= {EXP_MAX_W{1'b0}};
      e_b_reg <= {EXP_MAX_W{1'b0}};
      m_a_reg <= {MAN_MAX_W{1'b0}};
      m_b_reg <= {MAN_MAX_W{1'b0}};
       
      done_reg1 <= 1'b0;
    end else begin
      e_a_reg <= e_a;
      e_b_reg <= e_b;
      m_a_reg <= m_a;
      m_b_reg <= m_b; 
 
      done_reg1 <= start;
    end
  end
  
// Mantissa Multiplication 
   assign in1 = m_a_reg;
   assign in2 = m_b_reg;
   assign prod_mant = in2 *in2;

// Exponent Addition
  unum4_addsub #(.MAN_MAX_W(EXP_MAX_W-EXTRA),.EXTRA(EXTRA)) exp_add (
	  .op(1'b0),
	  .in1(e_a_reg),
	  .in2(e_b_reg),
	  .out(temp_exp_add),
	  .overflow()
  );

// Exponent Adjust 
 assign sticky = (m_a_reg[MAN_MAX_W-1] == m_b_reg[MAN_MAX_W-1])?
                 ((prod_mant[MAN_MAX_W-3:0]!=0)? 1'b1: 1'b0):
                 ((prod_mant[MAN_MAX_W-4:0]!=0)? 1'b1: 1'b0); // Rounding Mode = 1
 assign temp_exp = (m_a_reg[MAN_MAX_W-1] == m_b_reg[MAN_MAX_W-1])? temp_exp_add+1'b1:temp_exp_add;
         
// Pipeline Stage 2
   generate
      if (EXTRA==0) begin
         always @(posedge clk) begin
            if (rst) begin
               mant_reg <= {MAN_MAX_W+EXTRA{1'b0}};
               temp_exp_reg <= {EXP_MAX_W+1{1'b0}};
     
               done_reg2 <= 1'b0;

            end else begin
               if(m_a_reg[MAN_MAX_W-1] == m_b_reg[MAN_MAX_W-1]) begin
                  mant_reg <= prod_mant[2*MAN_MAX_W-1 -: MAN_MAX_W];
                  temp_exp_reg <= temp_exp_add+1'b1;
               end else begin
                  mant_reg <=  prod_mant[2*MAN_MAX_W-2 -: MAN_MAX_W];
                  temp_exp_reg <= temp_exp_add;
               end
               done_reg2 <= done_reg1;
            end
         end
      end else begin
         always @(posedge clk) begin
            if (rst) begin
               mant_reg <= {MAN_MAX_W+EXTRA{1'b0}};
               temp_exp_reg <= {EXP_MAX_W+1{1'b0}};
     
               done_reg2 <= 1'b0;
            end else begin
               if(m_a_reg[MAN_MAX_W-1] == m_b_reg[MAN_MAX_W-1]) begin
                  mant_reg <= {prod_mant[2*MAN_MAX_W-1 -: MAN_MAX_W+2], sticky};
                  temp_exp_reg <= temp_exp_add+1'b1;
               end else begin
                  mant_reg <= {prod_mant[2*MAN_MAX_W-2 -: MAN_MAX_W+2], sticky};
                  temp_exp_reg <= temp_exp_add;
               end
            end
            done_reg2 <= done_reg1;
         end
      end
   endgenerate
 
// 1st Normalization   
  unum4_clz #(.MAN_MAX_W(MAN_MAX_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA)) count (
	  .data_in(mant_reg),
	  .data_out(leadings)
  );

  assign e_temp = temp_exp - leadings;
  
  unum4_bs #(.MAN_MAX_W(MAN_MAX_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA)) shifter_0 (
	  .data_in(mant_reg),
	  .data_out(shifted_mant_0),
	  .left_nright(1'b1),
	  .shift(leadings)
  );
   
// Pipeline Stage 3
 always @(posedge clk) begin
   if (rst) begin
     e_temp_reg <= {EXP_MAX_W+1{1'b0}};
     r_shift_reg <= {EXP_MAX_W+2{1'b0}};
     shifted_mant_0_reg <= {MAN_MAX_W+EXTRA{1'b0}};
     
     done_reg3 <= 1'b0;
   end else begin
     e_temp_reg <= e_temp;
     r_shift_reg <= $signed({2'b11,{EXP_MAX_W-3{1'b0}},2'b10})-e_temp_reg;
     shifted_mant_0_reg <= shifted_mant_0;
     
     done_reg3 <= done_reg2;
   end
 end
// 2nd Normalization
  unum4_bs #(.MAN_MAX_W(MAN_MAX_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA)) shifter_1 (
	  .data_in(shifted_mant_0_reg),
	  .data_out(shifted_mant_1),
	  .left_nright(1'b0),
	  .shift(r_shift_reg[EXP_MAX_W-1:0])
  );

// Pipeline Stage 4
  always @(posedge clk) begin
    if (rst) begin
      under <= 1'b0;
      over <= 1'b0;
      m_o <= 0;
      e_o <= 0;
      done <= 1'b0;
    end else if (m_a_reg==0 || m_b_reg==0) begin
      e_o<=0;
      m_o<=0;
      
      done <= done_reg3;
    end else if(e_temp_reg >= $signed({2'b01,{EXP_MAX_W-1{1'b0}}})) begin
      over <= 1'b1;
      e_o <= 0;
      m_o <= 0;
      
      done <= done_reg3;
    end else if( r_shift_reg > (EXP_MAX_W+2)'(MAN_MAX_W)) begin
      under <= 1'b1;
      e_o <= 0;
      m_o <= 0;
      
      done <= done_reg3;
    end else if(e_temp_reg > $signed({2'b11,{EXP_MAX_W-3{1'b0}},2'b10})) begin
      e_o <= e_temp_reg[EXP_MAX_W-1:0];
      m_o <= shifted_mant_0_reg;
      
      done <= done_reg3;
    end else if(e_temp_reg+r_shift_reg == $signed({3'b111,{EXP_MAX_W-3{1'b0}},2'b10}) && e_temp_reg <=  $signed({2'b11,{EXP_MAX_W-3{1'b0}},2'b10})) begin
      e_o <=  $signed({1'b1,{EXP_MAX_W-3{1'b0}},2'b10});
      m_o <= shifted_mant_1;
      
      done <= done_reg3;
    end else if (temp_exp_reg ==  $signed({2'b11,{EXP_MAX_W-3{1'b0}},2'b10})) begin
      e_o <= temp_exp_reg[EXP_MAX_W-1:0];
      m_o <= mant_reg;
      
      done <= done_reg3;
    end
  end
  
endmodule
