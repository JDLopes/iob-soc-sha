#pragma once

#include <stdint.h>

typedef struct {
  int32_t exp;
  int32_t man;
  int32_t ew;
  } Unum4Unpacked;

typedef int32_t unum4;

#define unum4_add(a, b, overflow) ({\
  ACCEL_TOP_input_0_constant = a;\
  ACCEL_TOP_input_1_constant = b;\
  ACCEL_TOP_simple_op = 0;\
\
   RunAccelerator(1);\
\
  *overflow = ACCEL_TOP_simple_overflow;\
  ACCEL_TOP_output_0_currentValue;\
})

#define unum4_sub(a, b, overflow) ({\
  ACCEL_TOP_input_0_constant = a;\
  ACCEL_TOP_input_1_constant = b;\
  ACCEL_TOP_simple_op = 1;\
\
   RunAccelerator(1);\
\
  *overflow = ACCEL_TOP_simple_overflow;\
  ACCEL_TOP_output_0_currentValue;\
})

#define unum4_mul(a, b, overflow, underflow) ({\
  ACCEL_TOP_input_0_constant = a;\
  ACCEL_TOP_input_1_constant = b;\
  ACCEL_TOP_simple_op = 3;\
\
   RunAccelerator(1);\
\
  *overflow = ACCEL_TOP_simple_overflow;\
  *underflow = ACCEL_TOP_simple_underflow;\
  ACCEL_TOP_output_0_currentValue;\
})

#define unum4_div(a, b, overflow, underflow, div_by_zero) ({\
  ACCEL_TOP_input_0_constant = a;\
  ACCEL_TOP_input_1_constant = b;\
  ACCEL_TOP_simple_op = 2;\
\
   RunAccelerator(1);\
\
  *overflow = ACCEL_TOP_simple_overflow;\
  *underflow = ACCEL_TOP_simple_underflow;\
  *div_by_zero = ACCEL_TOP_simple_div_by_zero;\
  ACCEL_TOP_output_0_currentValue;\
})

unum4 double2unum4(double input, uint8_t *failed);
unum4 float2unum4(float input, uint8_t *failed);
double unum42double(unum4 input);
#define unum42float(input) (float)unum42double(input)

int8_t unum4_compare(Unum4Unpacked a, Unum4Unpacked b);
#define unum4_lt(a, b) ((unum4_compare(unum4_unpack(a), unum4_unpack(b)) < 0)? 1: 0)
#define unum4_le(a, b) ((unum4_compare(unum4_unpack(a), unum4_unpack(b)) <= 0)? 1: 0)
#define unum4_gt(a, b) ((unum4_compare(unum4_unpack(a), unum4_unpack(b)) > 0)? 1: 0)
#define unum4_ge(a, b) ((unum4_compare(unum4_unpack(a), unum4_unpack(b)) >= 0)? 1: 0)
#define unum4_eq(a, b) ((unum4_compare(unum4_unpack(a), unum4_unpack(b)) == 0)? 1: 0)
