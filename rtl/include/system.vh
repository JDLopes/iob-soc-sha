//data width
`define DATA_W 32
//address width
`define ADDR_W 32
// number of slaves (log2)
`define N_SLAVES_W $clog2(`N_SLAVES)

//when not booting init sram/ddr with firmware
`ifndef USE_BOOT
 `ifdef USE_DDR
  `ifdef RUN_DDR
   `define DDR_INIT
  `else
   `define SRAM_INIT
  `endif
 `else //ddr not used
  `define SRAM_INIT
 `endif
`endif

// run modes
`ifdef USE_DDR
 `ifdef RUN_DDR
  `define RUN_DDR_USE_SRAM
 `else
  `define RUN_SRAM_USE_DDR
 `endif
`endif
 
// data bus select bits
`define V_BIT (`REQ_W - 1) //valid bit
`define E_BIT (`REQ_W - (`ADDR_W-`E+1)) //extra mem bit
`define P_BIT (`REQ_W - (`ADDR_W-`P+1)) //peripherals bit
`define B_BIT (`REQ_W - (`ADDR_W-`B+1)) //boot controller bit

