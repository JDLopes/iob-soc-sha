//Adder and Subtractor
`timescale 1ns / 1ps
`include "defs.vh"

module unum4_adder #(
        parameter DATA_W = 32,
        parameter MAN_MAX_W = 29,
        parameter EXP_SZ_W = 4,
        parameter EXP_MAX_W = 16,
        parameter EXTRA = 0    
   )
   (
	input                                 clk,
	input                                 rst,
	input                                 start,
	output reg                            done,
	input                                 op, //1 for subtraction, 0 for addition
	input[MAN_MAX_W-1:0]                  m_a, 
	input[MAN_MAX_W-1:0]                  m_b,
	input signed[EXP_MAX_W-1:0]           e_a,
	input signed[EXP_MAX_W-1:0]           e_b,
	output reg[MAN_MAX_W-1+EXTRA:0]       m_o,
	output reg[EXP_MAX_W-1:0]             e_o,
	output reg                            over, //overflow flag
	output reg                            under
   );
  
  wire                                     m_overflow, diffsign, e_overflow, underflow, overflow;	
  wire signed[EXP_MAX_W-1:0]               exp_larger, temp_exp, leading, norm,leadings;
  wire signed[MAN_MAX_W-1+EXTRA:0]         in1, in2, temp_m, shifted_m, temp_mant, temp_m_out;
  wire signed[MAN_MAX_W+EXTRA:0]           temp_result;
  wire signed[EXP_MAX_W:0]                 diff_norm,diff;
  
  reg signed [EXP_MAX_W-1:0]               e_a_reg, e_b_reg;
  reg [MAN_MAX_W-1+EXTRA:0]                m_a_reg, m_b_reg;
  reg signed[MAN_MAX_W+EXTRA:0]            temp_result_reg;
  reg signed[MAN_MAX_W-1+EXTRA:0]          temp_m_reg, temp_mant_reg;
  reg signed[EXP_MAX_W-1:0]                temp_exp_reg;
  reg                                      overflow_reg, e_overflow_reg, done_reg1, done_reg2, done_reg3, done_reg4, done_reg5;  
  reg signed[MAN_MAX_W-1+EXTRA:0]         in1_reg, in2_reg, shifted_m_reg;
  reg signed[EXP_MAX_W:0]                 diff_reg;
  reg signed[EXP_MAX_W-1:0]               exp_larger_reg,leadings_reg;
  
  
//Pipeline Stage 1  
  always @(posedge clk) begin
    if(rst) begin
      e_a_reg <= {EXP_MAX_W{1'b0}};
      e_b_reg <= {EXP_MAX_W{1'b0}};
      m_a_reg <= {MAN_MAX_W+EXTRA{1'b0}};
      m_b_reg <= {MAN_MAX_W+EXTRA{1'b0}};
      diff_reg <={EXP_MAX_W+1{1'b0}};
      exp_larger_reg <= {EXP_MAX_W{1'b0}};
      done_reg1 <=1'b0;
    end else begin
      e_a_reg <= e_a;
      e_b_reg <= e_b;
      m_a_reg <= m_a;
      m_b_reg <= m_b;
      diff_reg <= diff;
      exp_larger_reg <= exp_larger;
      done_reg1 <= start;
    end
  end

// Exponent Difference
  expdiff   #(.EXP_MAX_W(EXP_MAX_W)) e_diff(
           .e_a(e_a_reg),
           .e_b(e_b_reg),
           .diff_out(diff),
           .e_larger(exp_larger)
  );

// 
  assign temp_m = (exp_larger_reg==e_a_reg) ? {m_b_reg,{EXTRA{1'b0}}}: {m_a_reg,{EXTRA{1'b0}}};

//Pipeline Stage 2    
  always @(posedge clk) begin
   if (rst) begin
     temp_m_reg <= {MAN_MAX_W+EXTRA{1'b0}};
     shifted_m_reg <= {MAN_MAX_W+EXTRA{1'b0}};
     
     done_reg2 <= 1'b0;
   end else begin
     temp_m_reg <= temp_m;
     shifted_m_reg <= shifted_m;
     
      done_reg2 <= done_reg1;
   end
  end

// Align Significands
  unum4_bs   #(.MAN_MAX_W(MAN_MAX_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA)) shifter_0 (
          .data_in(temp_m_reg),
          .data_out(shifted_m),
          .left_nright(1'b0),
          .shift(diff_reg[EXP_MAX_W-1:0])
  );

  assign in1 = (exp_larger_reg==e_a_reg) ? {m_a_reg,{EXTRA{1'b0}}} : (diff_reg> (EXP_MAX_W+1)'(MAN_MAX_W-2))? {MAN_MAX_W+EXTRA{1'b0}}: shifted_m_reg; 
  assign in2 = (exp_larger_reg==e_b_reg) ?  {m_b_reg,{EXTRA{1'b0}}}: (diff_reg> (EXP_MAX_W+1)'(MAN_MAX_W-2))? {MAN_MAX_W+EXTRA{1'b0}}:shifted_m_reg;
  
//Pipeline Stage 3
  
    always @(posedge clk) begin
   if (rst) begin
     in1_reg <= {MAN_MAX_W+EXTRA{1'b0}};
     in2_reg <= {MAN_MAX_W+EXTRA{1'b0}};
     
     done_reg3 <= 1'b0;
   end else begin
     in1_reg <= in1;
     in2_reg <= in2;
     
     done_reg3 <= done_reg2;
   end
  end       
// Addition / Subtraction 	
  unum4_addsub   #(.MAN_MAX_W(MAN_MAX_W),.EXTRA(EXTRA)) addsub_m (
           .op(op),
           .in1(in1_reg),
           .in2(in2_reg),
           .out(temp_result),
           .overflow(overflow)
  );

//Pipeline Stage 4 
 always @ (posedge clk) begin 
   if (rst) begin
     temp_result_reg <={MAN_MAX_W+EXTRA+1{1'b0}};
     overflow_reg <= 1'b0;
     
     done_reg4 <= 1'b0;
   end else begin 
     temp_result_reg <= temp_result;
     overflow_reg <= overflow;
     
     done_reg4 <= done_reg3; 
   end
 end

//Exponent Aand Mantissa Ajust
 
  assign  temp_mant = (overflow_reg)? temp_result_reg[MAN_MAX_W+EXTRA:1]: temp_result_reg[MAN_MAX_W-1+EXTRA:0];
  assign  temp_exp = (overflow_reg) ? exp_larger_reg+1 : exp_larger_reg;
  assign  e_overflow =(temp_exp[EXP_MAX_W-1] ^ exp_larger_reg[EXP_MAX_W-1]) ? 1'b1:1'b0;
  
//Pipeline Stage 5
   always @ (posedge clk) begin 
   if (rst) begin
     temp_exp_reg <={EXP_MAX_W{1'b0}};
     temp_mant_reg <= {MAN_MAX_W+EXTRA{1'b0}};
     e_overflow_reg <= 1'b0;
     leadings_reg <=0;
     
     done_reg5 <= 1'b0;
   end else begin 
     temp_exp_reg <= temp_exp;
     temp_mant_reg <= temp_mant;
     e_overflow_reg <= e_overflow;
     leadings_reg <=leadings;
     
     done_reg5 <= done_reg4;
   end
 end
	
// Normalization	
  unum4_clz #(.MAN_MAX_W(MAN_MAX_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA)) count (
        .data_in(temp_mant_reg),
        .data_out(leadings)
  );
  
  assign diff_norm = $signed({2'b11,{EXP_MAX_W-3{1'b0}},2'b10})-({temp_exp_reg[EXP_MAX_W-1],temp_exp_reg}-{leadings_reg[EXP_MAX_W-1],leadings_reg});
  assign norm = ~diff_norm[EXP_MAX_W]? {leadings_reg-diff_norm}[EXP_MAX_W-1:0]: leadings_reg;
    
  unum4_bs  #(.MAN_MAX_W(MAN_MAX_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA)) norm_shifter (
      .data_in(temp_mant_reg),
      .data_out(temp_m_out),
      .left_nright(1'b1),
      .shift(norm)
  );
  
//Pipeline Stage 6
 
  always @(posedge clk) begin
   if (rst) begin 
    under <= 1'b0;
    over <= 1'b0;
    m_o <= 0;
    e_o <= 0;
    done <= 1'b0;
   end
   else if ( temp_exp_reg > $signed({1'b1,{EXP_MAX_W-3{1'b0}},2'b10})) begin // > Smaller Exponent      
      e_o <= temp_exp_reg-norm;
      m_o <= temp_m_out[MAN_MAX_W-1+EXTRA:0];
      over <= e_overflow_reg;
      
      done <= done_reg5;
    end
    else if (temp_exp_reg ==  $signed({1'b1,{EXP_MAX_W-3{1'b0}},2'b10})) begin // = Smaller Exponent
      e_o <= temp_exp_reg;
      m_o <= temp_mant_reg;
      over <= e_overflow_reg;
      
      done <= done_reg5;
    end
    else  if (e_overflow_reg) begin //overflow
      e_o <= 0;
      m_o <= 0;
      over <= 1'b1;
      over <=e_overflow_reg;
      
      done <= done_reg5;
    end
    else 
      done <=1'b0;
  end
    	
endmodule
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	

