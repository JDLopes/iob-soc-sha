// Pack unit
`timescale 1ns/1ps
`include "defs.vh"

module unum4_pack #(	
                        parameter DATA_W = 32,
                        parameter MAN_MAX_W = 29,
                        parameter EXP_SZ_W = 4,
                        parameter EXP_MAX_W = 16,
                        parameter EXTRA = 3
                        )
   (
    input                       clk,
    input                       rst,
    input                       start,
    output reg                  done,
    input [EXP_MAX_W-1:0]       exp,
    input [MAN_MAX_W-1+EXTRA:0] mant,
    output reg [DATA_W-1:0]     o,
    output reg                  over
    );
   // Wires
   wire                         guard_bit, sticky_bit, round_bit, round, m_lsb, rounding_overflow;
   wire [EXP_SZ_W-1:0]          exp_size, final_exp_sz;
   wire [MAN_MAX_W-1:0]         m_o, mantissa, extra;
   wire [EXP_MAX_W-1:0]         e_o, stcomp_exp, lz, final_lz;
   // Integers
   integer signed               i,k,n,z,y;
   // Registers
   reg                          done_reg1, done_reg2;
   reg [DATA_W-1:0]             data_out;
   reg [EXP_MAX_W-1:0]          exp_reg;
   reg [MAN_MAX_W-1+EXTRA:0]    mant_reg;
   reg [EXP_MAX_W-1:0]          stcomp_exp_reg, e_o_reg;
   reg [MAN_MAX_W-1:0]          m_o_reg;

   // Pipeline Stage 1
   always @(posedge clk) begin
      if(rst) begin
         exp_reg <= {EXP_MAX_W{1'b0}};
         mant_reg <= {MAN_MAX_W+EXTRA{1'b0}};

         done_reg1 <= 1'b0;
      end else begin
         exp_reg <= exp;
         mant_reg <= mant;

         done_reg1 <= start;
      end
   end

   // Exponent Conversion (1's Complement)
   assign stcomp_exp = (exp[EXP_MAX_W-1]==1'b1)? (mant[MAN_MAX_W-1]==mant[MAN_MAX_W-2])? exp-EXP_MAX_W'(2): exp-1'b1:
                                                 exp;
   // Pipeline Stage 2
   always @(posedge clk) begin
      if(rst) begin
         stcomp_exp_reg <= {EXP_MAX_W{1'b0}};
      end else begin
         stcomp_exp_reg <= stcomp_exp;
      end
   end

   // Exponent Size calculation
   unum4_clz
     #(
       .MAN_MAX_W(EXP_MAX_W),
       .EXP_MAX_W(EXP_MAX_W),
       .EXTRA(0)
       )
   exp_lz
     (
      .data_in(stcomp_exp_reg),
      .data_out(lz)
      );

   assign exp_size = (mant_reg[MAN_MAX_W-1] == mant_reg[MAN_MAX_W-2])? (stcomp_exp_reg == {EXP_MAX_W{1'b0}})? {EXP_SZ_W{1'b0}} :{EXP_SZ_W{1'b1}}:
                                                                       {EXP_MAX_W'(EXP_MAX_W-1)-lz}[EXP_SZ_W-1:0];

   generate
      if (EXTRA != 0) begin
         // Rounding Bits
         assign m_lsb = mant_reg[3+exp_size];
         assign guard_bit = mant_reg[2+exp_size];
         assign round_bit = mant_reg[1+exp_size];
         assign sticky_bit = mant_reg[exp_size+1-1];

         // Round
         assign round = guard_bit & (round_bit | sticky_bit | m_lsb);
         assign extra = ({{MAN_MAX_W-1{1'b0}},1'b1} << exp_size);
         assign mantissa = (round)? mant_reg[MAN_MAX_W-1+EXTRA:3] + extra: mant_reg[MAN_MAX_W-1+EXTRA:3];

         // Normalization
         assign m_o =         (~mant_reg[MAN_MAX_W-1+EXTRA] & mantissa[MAN_MAX_W-1])? {2'b01,{MAN_MAX_W-2{1'b0}}}:
(mant_reg[MAN_MAX_W-1+EXTRA] & ~mant_reg[MAN_MAX_W-2+EXTRA] & mantissa[MAN_MAX_W-2])? mantissa << 1'b1:
                                                                                      mantissa;
         assign e_o =         (~mant_reg[MAN_MAX_W-1+EXTRA] & mantissa[MAN_MAX_W-1])? stcomp_exp_reg + 1'b1:
(mant_reg[MAN_MAX_W-1+EXTRA] & ~mant_reg[MAN_MAX_W-2+EXTRA] & mantissa[MAN_MAX_W-2])? stcomp_exp_reg - 1'b1:
                                                                                                             stcomp_exp_reg;

         assign rounding_overflow = (e_o[EXP_MAX_W-1] & stcomp_exp_reg == {1'b0,{EXP_MAX_W-1{1'b1}}})? 1'b1: 1'b0;

         // Pipeline Stage 3
         always @(posedge clk) begin
            if(rst) begin
               m_o_reg <= {MAN_MAX_W{1'b0}};
               e_o_reg <= {EXP_MAX_W{1'b0}};

               done_reg2 <= 1'b0;
            end else begin
               m_o_reg <= m_o;
               e_o_reg <= e_o;

               done_reg2 <= done_reg1;
            end
         end

         // Exponent Size Ajust
         unum4_clz
           #(
             .MAN_MAX_W(EXP_MAX_W),
             .EXP_MAX_W(EXP_MAX_W),
             .EXTRA(0)
             )
         exp_lz2
           (
            .data_in(e_o_reg),
            .data_out(final_lz)
            );

         assign final_exp_sz = (m_o_reg[MAN_MAX_W-1] == m_o_reg[MAN_MAX_W-2])? (e_o_reg == {EXP_MAX_W{1'b0}})? {EXP_SZ_W{1'b0}} :{EXP_SZ_W{1'b1}} :
                                                                               {EXP_MAX_W'(EXP_MAX_W-1)-final_lz}[EXP_SZ_W-1:0];
      end else begin
         always @* begin
            m_o_reg = mant_reg;
            e_o_reg = exp_reg;

            done_reg2 = done_reg1;
         end

         assign final_exp_sz = exp_size;
      end
   endgenerate

   // Pack
   always @* begin
      z=0;
      y = {{DATA_W-EXP_SZ_W{1'b0}}, final_exp_sz};
      data_out=0;
      if(final_exp_sz ==0)
        data_out = {m_o_reg[MAN_MAX_W-2:0], final_exp_sz};
      else begin
         for(i=0;i<EXP_SZ_W;i=i+1) begin
            data_out[i] = final_exp_sz[i];
         end
         for(k=EXP_SZ_W;k<DATA_W;k=k+1) begin
            if(k<DATA_W-{{DATA_W-EXP_SZ_W{1'b0}}, final_exp_sz}) begin
	           data_out[k] = m_o_reg[y];
	           y=y+1'b1;
	        end
         end
         for(n=0; n<DATA_W; n=n+1) begin
            if(n>=DATA_W-{{DATA_W-EXP_SZ_W{1'b0}}, final_exp_sz}) begin
               data_out[n] = e_o_reg[z];
               z=z+1'b1;
            end
         end
      end
   end

   // Pipeline Stage 4
   always @(posedge clk) begin
      if (rst) begin
         o <= 0;

         done <= 1'b0;
      end else begin
         o <= data_out;

         done <= done_reg2;
      end
   end

   generate
      if (EXTRA != 0) begin
         always @(posedge clk) begin
            if (rst) begin
               over <= 1'b0;
            end else begin
               over <= rounding_overflow;
            end
         end
      end else begin
         always @* begin
            over = 1'b0;
         end
      end
   endgenerate

endmodule

