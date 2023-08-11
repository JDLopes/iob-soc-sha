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

#include "unum4_hw.h"

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

uint8_t failed, overflow, underflow, div_by_zero;

void test_operations(void) {

  // Addition
  printf("\nAddition\n\n");

  unum4 op1 = double2unum4(1.0, &failed);
  unum4 op2 = double2unum4(2.0, &failed);

  unum4 res = unum4_add(op1, op2, &overflow);

  printf("Op1: %.16f (0x%08x) \n", op1, unum42double(op1));
  printf("Op2: %.16f (0x%08x) \n", op2, unum42double(op2));
  printf("Result: %.16f (0x%08x) \n", res, unum42double(res));
  printf("Overflow: %d\n", overflow);

  // Subtraction
  printf("\nSubtraction\n\n");

  op1 = double2unum4(1.0, &failed);
  op2 = double2unum4(2.0, &failed);

  res = unum4_sub(op1, op2, &overflow);

  printf("Op1: %.16f (0x%08x) \n", op1, unum42double(op1));
  printf("Op2: %.16f (0x%08x) \n", op2, unum42double(op2));
  printf("Result: %.16f (0x%08x) \n", res, unum42double(res));
  printf("Overflow: %d\n", overflow);

  // Multiplication
  printf("\nMultiplication\n\n");

  op1 = double2unum4(1.0, &failed);
  op2 = double2unum4(2.0, &failed);

  res = unum4_mul(op1, op2, &overflow, &underflow);

  printf("Op1: %.16f (0x%08x) \n", op1, unum42double(op1));
  printf("Op2: %.16f (0x%08x) \n", op2, unum42double(op2));
  printf("Result: %.16f (0x%08x) \n", res, unum42double(res));
  printf("Overflow: %d\n", overflow);
  printf("Underflow: %d\n", underflow);

  // Division
  printf("\nDivision\n\n");

  op1 = double2unum4(1.0, &failed);
  op2 = double2unum4(2.0, &failed);

  res = unum4_div(op1, op2, &overflow, &underflow, &div_by_zero);

  printf("Op1: %.16f (0x%08x) \n", op1, unum42double(op1));
  printf("Op2: %.16f (0x%08x) \n", op2, unum42double(op2));
  printf("Result: %.16f (0x%08x) \n", res, unum42double(res));
  printf("Overflow: %d\n", overflow);
  printf("Underflow: %d\n", underflow);
  printf("Div by zero: %d\n", div_by_zero);

  return;
}

int main(int argc,char* argv[]){
  uart_init(UART_BASE,FREQ/BAUD);
  timer_init(TIMER_BASE);
  ila_init(ILA_BASE);

  printf("Init base modules\n");

  versat_init(VERSAT_BASE);

  test_operations();

  uart_finish();

  return 0;
}









