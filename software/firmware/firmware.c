#include "versat_accel.h"

#ifdef __cplusplus
extern "C" {
#endif

#include "system.h"
#include "periphs.h"
#include "iob-uart.h"
#include "string.h"

#include "iob-timer.h"
#include "iob-ila.h"

#ifdef __cplusplus
}
#endif

#ifdef PC
#define uart_init(...) ((void)0)
#define uart_finish(...) ((void)0)
#include "stdio.h"
#else

int printf_(const char* format, ...);
#define printf printf_
#endif

typedef union{
   iptr i;
   float f;
} Conv;

static iptr PackInt(float f){
   Conv c = {};
   c.f = f;
   return c.i;
}

static float UnpackInt(iptr i){
   Conv c = {};
   c.i = i;
   return c.f;
}

int main(int argc,char* argv[]){
   uart_init(UART_BASE,FREQ/BAUD);
   timer_init(TIMER_BASE);
   ila_init(ILA_BASE);

   printf("Init base modules\n");

   versat_init(VERSAT_BASE);

   // Configuration (only write to these)
   ACCEL_TOP_input_0_constant = 0x1;
   ACCEL_TOP_input_1_constant = 0x2;
   ACCEL_TOP_simple_op = 0;

   RunAccelerator(1);

   printf("Result: %x\n",ACCEL_TOP_output_0_currentValue);
   printf("Overflow: %d\n",ACCEL_TOP_simple_overflow);
   printf("Underflow: %d\n",ACCEL_TOP_simple_underflow);
   printf("Div by zero: %d\n",ACCEL_TOP_simple_div_by_zero);

   uart_finish();

   return 0;
}









