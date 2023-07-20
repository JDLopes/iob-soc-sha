`timescale 1ns/1ps

`include "defs.vh"

module fpu #(	
        parameter DATA_W=32,
        parameter EXP_SZ_W=4,
        parameter ROUNDING=0, // 0- Without Extra Bits ; 1-Round to the nearest, ties even.
        parameter AXI_ADDR_W=32 // Required by versat for now, even if not using it. Later I'll change this into being optional
        )
   (
    //Inputs
    input                       clk,
    input                       rst,

    // Certain inputs need to follow naming conventions. These are: running,run,in0,in1,done and out0.

    input                       running,

    input                       run,
    input [DATA_W-1:0]          in0,
    input [DATA_W-1:0]          in1,

    input [`OPCODE_W-1:0]       op,
    //Outputs
    (* versat_latency = 40 *) output [DATA_W-1:0]      out0, // Versat latency is needed, but for testing it can be larger than the real value. As long as the output does not change if inputs remain stable

    output                      overflow,
    output                      underflow,
    output                      div_by_zero,
    output                      done
   );
   
   localparam			  	 EXP_MAX_W =  2**EXP_SZ_W; //-1
   localparam			  	 MAN_MAX_W = DATA_W-EXP_SZ_W+1;
   localparam				 EXTRA = 3*ROUNDING; //Extra Rounding Bits (Guard,Round,Sticky)
   
   wire                                ADD = !op[1] & !op[0];// & run;
   wire                                SUB = !op[1] & op[0];// & run;
   wire                                DIV = op[1] & !op[0];// & run;
   wire                                MUL = op[1] & op[0];// & run;
   wire                                under_add, under_mult, over_add, over_mult, under_div, over_div,
over_round, div_flag;
   wire                                unpack_a_start, unpack_b_start, add_start, div_start, mul_start, pack_start;
   wire                                unpack_a_done, unpack_b_done, add_done, div_done, mul_done, pack_done;
   wire [EXP_MAX_W-1:0]                e_a, e_b, e_add, e_mult, e_div;
   wire [MAN_MAX_W-1:0]                m_a, m_b;
   wire [MAN_MAX_W-1+EXTRA:0]          m_add, m_mult, m_div;
   wire [EXP_MAX_W-1:0]                e_o;
   wire [MAN_MAX_W-1+EXTRA:0]          m_o;
   wire  [DATA_W-1:0]                  out;
   reg                                 ready;
   wire                                op_done;
   
   always @ (posedge clk) begin
     if (rst) 
       ready <= 1'b0;
     else
       ready <= run;
   end
  
  assign unpack_a_start = ready;
  assign unpack_b_start = ready; 
       
   
   unum4_unpack #(.DATA_W(DATA_W),.MAN_MAX_W(MAN_MAX_W),.EXP_SZ_W(EXP_SZ_W),.EXP_MAX_W(EXP_MAX_W))  unpack_a (
               .clk(clk),
               .rst(rst),
               .start(unpack_a_start),
               .done(unpack_a_done),
               .x(in0),
               .e(e_a),
               .m(m_a)
           );


   unum4_unpack #(.DATA_W(DATA_W),.MAN_MAX_W(MAN_MAX_W),.EXP_SZ_W(EXP_SZ_W),.EXP_MAX_W(EXP_MAX_W))    unpack_b (
               .clk(clk),
               .rst(rst),
               .start(unpack_b_start),
               .done(unpack_b_done),
               .x(in1),
               .e(e_b),
               .m(m_b)
           );
           
  assign add_start = unpack_a_done & unpack_b_done & (ADD | SUB) & ~op_done;
  assign div_start = unpack_a_done & unpack_b_done & DIV & ~op_done;
  assign mul_start = unpack_a_done & unpack_b_done & MUL & ~op_done;
     
   unum4_adder #(.DATA_W(DATA_W),.MAN_MAX_W(MAN_MAX_W),.EXP_SZ_W(EXP_SZ_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA))   add (
              .clk(clk),
              .rst(rst),
              .start(add_start),
              .done(add_done),
              .op(op[0]),
              .m_a(m_a),
              .m_b(m_b),
              .e_a(e_a),
              .e_b(e_b),
              .m_o(m_add),
              .e_o(e_add),
              .over(over_add),
	      .under(under_add)
           );

   unum4_mult #(.DATA_W(DATA_W),.MAN_MAX_W(MAN_MAX_W),.EXP_SZ_W(EXP_SZ_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA))  mul (
             .clk(clk),
             .rst(rst),
             .start(mul_start),
             .done(mul_done),
             .m_a(m_a),
             .m_b(m_b),
             .e_a(e_a),
             .e_b(e_b),
             .m_o(m_mult),
             .e_o(e_mult),
             .over(over_mult),
             .under(under_mult)
           );

   unum4_divide #(.DATA_W(DATA_W),.MAN_MAX_W(MAN_MAX_W),.EXP_SZ_W(EXP_SZ_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA)) div (
              .clk(clk),
              .rst(rst),
              .start(div_start),
              .done(div_done), 
              .m_a(m_a),
              .m_b(m_b),
              .e_a(e_a),
              .e_b(e_b),
              .m_o(m_div),
              .e_o(e_div),
              .over(over_div),
              .under(under_div),
              .div_by_zero(div_flag)
           );

  assign pack_start = op_done; 
  generate
    if(ROUNDING==1) begin
      unum4_pack #(.DATA_W(DATA_W),.MAN_MAX_W(MAN_MAX_W),.EXP_SZ_W(EXP_SZ_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA)) pack_o (
                .clk(clk),
                .rst(rst),
                .start(pack_start),
                .done(pack_done),
                .exp(e_o),
                .mant(m_o),
                .o(out),
     	        .over(over_round)
            );            
    end
    else begin 
      unum4_pack0 #(.DATA_W(DATA_W),.MAN_MAX_W(MAN_MAX_W),.EXP_SZ_W(EXP_SZ_W),.EXP_MAX_W(EXP_MAX_W),.EXTRA(EXTRA)) pack_a (
                .clk(clk),
                .rst(rst),
                .start(pack_start),
                .done(pack_done),
                .exp(e_o),
                .mant(m_o),
                .o(out)
	       );
    end
  endgenerate 
  
  assign       overflow = over_add | over_round | over_mult | over_div;
  assign       underflow = under_add | under_mult | under_div;
  assign       div_by_zero = div_flag;

  assign e_o = DIV? e_div:
               MUL? e_mult:
                    e_add;

  assign m_o = DIV? m_div:
               MUL? m_mult:
                    m_add;

  assign op_done = add_done | mul_done | div_done;

  assign done = pack_done;
  assign out0 = out;

endmodule
