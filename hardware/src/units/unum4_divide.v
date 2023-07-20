// Division Unit

`timescale 1ns/1ps
`include "defs.vh"

module unum4_divide #(	
        parameter DATA_W = 32,
        parameter MAN_MAX_W = 29,
        parameter EXP_SZ_W = 4,
        parameter EXP_MAX_W = 16,
        parameter EXTRA = 0        
   )
   (
   
       input             				clk,
       input             				rst,
       input             				start,
       output reg           				done,
       input[MAN_MAX_W-1:0]          			m_a,
       input[MAN_MAX_W-1:0]          			m_b,
       input[EXP_MAX_W-1:0]          			e_a,
       input[EXP_MAX_W-1:0]          			e_b,
       output reg[MAN_MAX_W-1+EXTRA:0]  		m_o,
       output reg[EXP_MAX_W-1:0]     			e_o,
       output reg                     		over,
       output reg                     		under,
       output reg                     		div_by_zero
   );
  
 
  wire [2*MAN_MAX_W-1:0] 	       shifted_m; 
  wire [MAN_MAX_W-1:0]                in1, in2;
  wire                                div_sign, sub_over, underflow;
  wire [EXP_MAX_W:0]                  temp_exp;
  wire signed[MAN_MAX_W-1+EXTRA:0]    mant, shifted_mant_0, shifted_mant_1;
  wire signed[EXP_MAX_W:0]            exp_sub, e_temp;
  wire signed[EXP_MAX_W-1:0]          leadings, leading, shift_m, lz;
  wire signed[EXP_MAX_W+1:0]          r_shift;
  wire [2*MAN_MAX_W-1:0]              quotient;
  wire                                div_done;
  
  
  reg [EXP_MAX_W-1:0]                 e_a_reg;
  reg signed [MAN_MAX_W-1:0]          m_a_reg;
  reg [EXP_MAX_W-1:0]                 e_b_reg;
  reg signed [MAN_MAX_W-1:0]          m_b_reg;
  reg signed[MAN_MAX_W-1+EXTRA:0]     mant_reg, shifted_mant_0_reg;
  reg [2*MAN_MAX_W-1:0]               quotient_reg;
  reg signed[EXP_MAX_W:0]             exp_sub_reg, e_temp_reg;
  reg signed[EXP_MAX_W+1:0]           r_shift_reg;
  reg [EXP_MAX_W:0]                   temp_exp_reg;
  reg signed[EXP_MAX_W-1:0]           lz_reg;
  reg                                 done_reg1, done_reg2, done_reg3, done_reg4;
  
  
//Pipeline Stage 1  
  always @(posedge clk) begin
    if(rst) begin
      e_a_reg <= {EXP_MAX_W{1'b0}};
      e_b_reg <= {EXP_MAX_W{1'b0}};
      m_a_reg <= {MAN_MAX_W+EXTRA{1'b0}};
      m_b_reg <= {MAN_MAX_W+EXTRA{1'b0}};
      
      done_reg1 <=1'b0;
    end else begin
      e_a_reg <= e_a;
      e_b_reg <= e_b;
      m_a_reg <= m_a;
      m_b_reg <= m_b;
      if (m_b == {MAN_MAX_W+EXTRA{1'b0}})
        div_by_zero <= 1'b1;
      else
        div_by_zero <= 1'b0;  
      
      done_reg1 <= start;
    end
  end
 
// Exponent Subtraction

 unum4_addsub #(.MAN_MAX_W(EXP_MAX_W-EXTRA),.EXTRA(EXTRA)) e_sub (
	 .op(1'b1),
	 .in1(e_a_reg),
	 .in2(e_b_reg),
	 .out(temp_exp),
	 .overflow(sub_over)
 ); 
 
// Mantissa Division (Serial Division)
  assign in1 = (m_a_reg[MAN_MAX_W-1]) ? ~m_a_reg + {{MAN_MAX_W-1{1'b0}},1'b1} : m_a_reg;
  assign in2 = (m_b_reg[MAN_MAX_W-1]) ? ~m_b_reg + {{MAN_MAX_W-1{1'b0}},1'b1} : m_b_reg;
  assign div_sign = m_a_reg[MAN_MAX_W-1] ^ m_b_reg[MAN_MAX_W-1];
 
  unum4_div_subshift # (.DATA_W(2*MAN_MAX_W)) div_subshift (
          .clk(clk),
          .en(done_reg1),
          .sign(1'b0),
          .done(div_done),
          .dividend({in1, {MAN_MAX_W{1'b0}}}),
          .divisor({{MAN_MAX_W{1'b0}}, in2}),
          .quotient(quotient),
          .remainder()
 );
                 
 // Normalization                 
    unum4_clz  #(.MAN_MAX_W(MAN_MAX_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(3)) count_0 (
	 .data_in({3'b0,quotient[2*MAN_MAX_W-1:MAN_MAX_W]}),
	 .data_out(lz)
 );
                 
 //Pipeline Stage 2 
  always @(posedge clk) begin
    if (rst) begin
      quotient_reg <= {2*MAN_MAX_W{1'b0}};
      temp_exp_reg <= {EXP_MAX_W+1{1'b0}};
      lz_reg <={EXP_MAX_W{1'b0}};
      
      done_reg2 <= 1'b0; 
    end else begin
      quotient_reg <= quotient;
      temp_exp_reg <= temp_exp;
      lz_reg <= lz;
      
      done_reg2 <= div_done;
    end
  end

 // Exponent Adjust 
  assign shift_m = EXP_MAX_W'(MAN_MAX_W+3)-lz_reg;
  assign exp_sub = temp_exp_reg[EXP_MAX_W:0]+shift_m-1;
  assign shifted_m = quotient_reg >> shift_m;
  assign mant = (div_sign)?  {~shifted_m[MAN_MAX_W-1:0] + 1'b1,{EXTRA{1'b0}}}: {shifted_m[MAN_MAX_W-1:0],{EXTRA{1'b0}}};
  
//Pipeline Stage 3  
  always @(posedge clk) begin
    if (rst) begin
      mant_reg <= {MAN_MAX_W+EXTRA{1'b0}};
      exp_sub_reg <= {EXP_MAX_W+1{1'b0}};
      
      done_reg3 <= 1'b0;
    end else begin
      mant_reg <= mant;
      exp_sub_reg <= exp_sub;
      
      done_reg3 <= done_reg2;
    end
  end
// 2nd Normalization
  unum4_clz  #(.MAN_MAX_W(MAN_MAX_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA))  count_1 (
	 .data_in(mant_reg),
	 .data_out(leadings)
 );

//  assign leadings = (leading >= MAN_MAX_W)? MAN_MAX_W : leading;
// Mantissa Adjust
  unum4_bs #(.MAN_MAX_W(MAN_MAX_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA)) shifter_0 (
	 .data_in(mant_reg),
	 .data_out(shifted_mant_0),
	 .left_nright(1'b1),
	 .shift(leadings)
 );
// Exponent Adjust
  assign e_temp = exp_sub_reg - leadings; 
//  assign r_shift = $signed({2'b11,{EXP_MAX_W-3{1'b0}},2'b10})-e_temp;
  
//Pipeline Stage 4  
  always @(posedge clk) begin
    if (rst) begin
      e_temp_reg <= {EXP_MAX_W+1{1'b0}};
      r_shift_reg <= {EXP_MAX_W+2{1'b0}};
      shifted_mant_0_reg <= {MAN_MAX_W+EXTRA{1'b0}};
      
      done_reg4 <= 1'b0;
    end else begin
      e_temp_reg <= e_temp;
      r_shift_reg <= $signed({2'b11,{EXP_MAX_W-3{1'b0}},2'b10})-e_temp_reg;
      shifted_mant_0_reg <= shifted_mant_0;
      
      done_reg4 <= done_reg3;
    end
  end
// Mantissa Adjust
  unum4_bs #(.MAN_MAX_W(MAN_MAX_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA)) shifter_1 (
        .data_in(shifted_mant_0_reg),
        .data_out(shifted_mant_1),
        .left_nright(1'b0),
        .shift(r_shift_reg[EXP_MAX_W-1:0])
 );
 
//Pipeline Stage 5
  always @(posedge clk) begin
    if(rst) begin
      under <= 1'b0;
      over <= 1'b0;
      m_o <= 0;
      e_o <= 0;
      done <= 1'b0;
    end else if(m_a_reg==0) begin
      e_o <=0;
      m_o <=0;
      
      done <= done_reg4;
    end else if(div_by_zero) begin
      e_o <=0;
      m_o <=0;
      
      done <= done_reg4;
    end else if(e_temp_reg >= $signed({2'b01,{EXP_MAX_W-1{1'b0}}})) begin
      over <= 1'b1;
      e_o <= 0;
      m_o <= 0;
      
      done <= done_reg4;
    end else if(r_shift_reg > (EXP_MAX_W+2)'(MAN_MAX_W)) begin
      under <= 1'b1;
      e_o <= 0;
      m_o <= 0;
      
      done <= done_reg4;
    end else if(e_temp_reg > $signed({2'b11,{EXP_MAX_W-3{1'b0}},2'b10})) begin
      e_o <= e_temp_reg[EXP_MAX_W-1:0];
      m_o <= shifted_mant_0_reg;
      
      done <= done_reg4;
    end else if(e_temp_reg+r_shift_reg == $signed({3'b111,{EXP_MAX_W-3{1'b0}},2'b10})) begin
      e_o <= $signed({1'b1,{EXP_MAX_W-3{1'b0}},2'b10});
      m_o <= shifted_mant_1;
      
      done <= done_reg4;
    end else if (exp_sub_reg == $signed({2'b11,{EXP_MAX_W-3{1'b0}},2'b10})) begin
      e_o <= exp_sub_reg[EXP_MAX_W-1:0];
      m_o <= mant_reg;
      
      done <= done_reg4;
    end
  end

endmodule
