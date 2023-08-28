#include <stdint.h>
#include <float.h>
#include <math.h>

#include "unum4_hw.h"

//
// Defines
//

#define MSB(w) ((int64_t)1 << ((w) - 1))

// Unum-IV
#define DATA_W 32
#define EW_W   4

#define EW_MAX  ((1 << EW_W) - 1)
#define F_W(ew) (DATA_W - (ew) - EW_W)
#define F_MAX_W F_W(0)
#define F_MIN_W F_W(EW_MAX)

#define EXP_W(ew) ((ew)? ((ew) + 1): 0)
#define EXP_MAX_W (EW_MAX + 1)
#define MAN_W(ew) (F_W(ew) + 1)
#define MAN_MAX_W (F_MAX_W + 1)
#define MAN_MIN_W (F_MIN_W + 1)

#define EXP_MAX ((1 << EW_MAX) - 1)
#define EXP_MIN (-EXP_MAX+1)
#define MAN_MAX ((1 << F_MIN_W) - 1)
#define MAN_MIN (1 << F_MIN_W)

#define RES_MAX_W (MAN_MAX_W+3)

#define UNUM4_W 32

// IEEE-754
#define FP_DP_DATA_W 64
#define FP_DP_EXP_W  11
#define FP_DP_BIAS   1023
#define FP_DP_F_W    52
#define FP_DP_MAN_W  (FP_DP_F_W + 1)

#define FP_SP_DATA_W 32
#define FP_SP_EXP_W  8
#define FP_SP_BIAS   127
#define FP_SP_F_W    23
#define FP_SP_MAN_W  (FP_SP_F_W + 1)

#define cleadings(num, width) ({\
  int32_t num_ = num;\
  int32_t leadings = 0;\
\
  if (num_ <= 0) num_ = ~num_;\
\
  int32_t i;\
  for (i = 0; i < width; i++) {\
    if ((num_ << i) & MSB(width-1)) break;\
    leadings++;\
  }\
\
  leadings;\
})

#define cew(exp) ({\
  int32_t ew = 0;\
\
  if (exp) {\
    int32_t leadings = cleadings(exp, UNUM4_W);\
    ew = UNUM4_W - leadings - 1;\
  }\
\
  ew;\
})

Unum4Unpacked unum4_unpack(unum4 input) {
  Unum4Unpacked upk;
  int32_t ew = EW_MAX & input;
  int32_t e = (input << (UNUM4_W - DATA_W)) >> (DATA_W - ew + (UNUM4_W - DATA_W));
  int32_t f = (input << (ew + (UNUM4_W - DATA_W))) >> (ew + EW_W + (UNUM4_W - DATA_W));

  upk.exp = e ^ ((int32_t)MSB(UNUM4_W) >> (UNUM4_W - EXP_W(ew)));
  if (upk.exp < 0) upk.exp++;
  if (!ew) {
    upk.exp = 0;
  } else if (ew == EW_MAX && !e) {
    upk.exp++;
  }

  upk.man = f;
  if (!(ew == EW_MAX && !e)) {
    upk.man ^= (int32_t)MSB(UNUM4_W) >> (UNUM4_W - MAN_W(ew));
  }

  upk.ew = ew;

  return upk;
}

unum4 unum4_pack(Unum4Unpacked o, uint8_t *overflow) {
  int32_t packed;

  int32_t exp = o.exp;
  if (exp < 0) {
    exp--;
  }

  int32_t ew = cew(exp);

  int32_t shift = ew + 3;
  int32_t man = o.man >> shift;

  int32_t man_lsb    = (o.man & (1 << shift))? 1: 0;
  int32_t guard_bit  = (o.man & (1 << (shift - 1)))? 1: 0;
  int32_t round_bit  = (o.man & (1 << (shift - 2)))? 1: 0;
  int32_t sticky_bit = (o.man & ((1 << (shift - 2)) - 1))? 1: 0;

  int32_t round = guard_bit & (man_lsb | round_bit | sticky_bit);
  if (round) {
    man += round;

    if (man) {
      int32_t leadings = cleadings(man, MAN_W(ew));
      exp -= leadings;
      man <<= leadings;

      ew = cew(exp);
    }
  }

  if (exp == EXP_MIN-1) {
    exp = 0;
  }

  exp &= (1 << ew) - 1;
  man &= (1 << F_W(ew)) - 1;

  packed = ew;
  packed |= man << EW_W;
  if (ew) {
    packed |= exp << (F_W(ew) + EW_W);
  }

  return packed;
}

unum4 double2unum4(double input, uint8_t *failed) {
  union {
    double  d;
    int64_t i;
  } conv = { .d = input };
  Unum4Unpacked upk;
  int32_t shift = 0;
  uint8_t overflow = 0;

  *failed = 0;

  // Fields extraction
  int32_t man_msb = conv.i >> (FP_DP_DATA_W - 1);
  int32_t exp = (uint64_t)(conv.i << 1) >> (FP_DP_DATA_W - FP_DP_EXP_W);
  int64_t man = (uint64_t)(conv.i << (1 + FP_DP_EXP_W)) >> (FP_DP_DATA_W - FP_DP_F_W);

  if (!exp) { // Denormalized or Zero
    exp -= FP_DP_BIAS;
    if (!man) {
      exp = EXP_MIN;
      man_msb = 0;
    }

    shift = FP_DP_MAN_W - RES_MAX_W;
  } else if (exp == ((1 << FP_DP_EXP_W) - 1)) { // Infinity or NAN
    *failed = 1;
  } else { // Normalized
    man |= MSB(FP_DP_MAN_W);
    exp -= FP_DP_BIAS - 1;

    shift = FP_DP_MAN_W - RES_MAX_W + 1;
  }

  if (man_msb) {
    man = -man;
  }

  if (exp < EXP_MIN) {
    exp = EXP_MIN;
    shift += EXP_MIN - exp;
    if (shift > FP_DP_F_W) {
      shift = FP_DP_F_W + 1;
    }
  }

  int32_t sticky = 0;
  if (shift < 0) {
    int32_t leadings = cleadings(man, RES_MAX_W);
    man <<= leadings;
  } else {
    sticky = (man & ((1 << (shift + 1)) - 1))? 1 : 0;
    man = (man >> shift) | sticky;
  }

  if (exp <= EXP_MAX && exp > EXP_MIN) {
    if (man) {
      int32_t leadings = cleadings(man, RES_MAX_W);
      upk.exp = exp - leadings;
      upk.man = (man << leadings) | sticky;
    } else {
      upk.exp = EXP_MIN;
      upk.man = 0;
    }
  } else {
    upk.exp = exp;
    upk.man = man;
  }

  if (*failed) {
    upk.man = 0;
    upk.exp = 0;
  }

  return unum4_pack(upk, &overflow);
}

unum4 float2unum4(float input, uint8_t *failed) {
  union {
    float   f;
    int32_t i;
  } conv = { .f = input };
  Unum4Unpacked upk;
  int32_t shift = 0;
  uint8_t overflow = 0;

  *failed = 0;

  // Fields extraction
  int32_t man_msb = conv.i >> (FP_SP_DATA_W - 1);
  int32_t exp = (uint32_t)(conv.i << 1) >> (FP_SP_DATA_W - FP_SP_EXP_W);
  int32_t man = (uint32_t)(conv.i << (1 + FP_SP_EXP_W)) >> (FP_SP_DATA_W - FP_SP_F_W);

  if (!exp) { // Denormalized or Zero
    exp -= FP_SP_BIAS;
    if (!man) {
      exp = EXP_MIN;
      man_msb = 0;
    }

    shift = FP_SP_MAN_W - RES_MAX_W;
  } else if (exp == ((1 << FP_SP_EXP_W) - 1)) { // Infinity or NAN
    *failed = 1;
  } else { // Normalized
    man |= MSB(FP_SP_MAN_W);
    exp -= FP_SP_BIAS - 1;

    shift = FP_SP_MAN_W - RES_MAX_W + 1;
  }

  if (man_msb) {
    man = -man;
  }

  if (exp < EXP_MIN) {
    exp = EXP_MIN;
    shift += EXP_MIN - exp;
    if (shift > FP_SP_F_W) {
      shift = FP_SP_F_W + 1;
    }
  }

  int32_t sticky = 0;
  if (shift < 0) {
    int32_t leadings = cleadings(man, RES_MAX_W);
    man <<= leadings;
  } else {
    sticky = (man & ((1 << (shift + 1)) - 1))? 1 : 0;
    man = (man >> shift) | sticky;
  }

  if (exp <= EXP_MAX && exp > EXP_MIN) {
    if (man) {
      int32_t leadings = cleadings(man, RES_MAX_W);
      upk.exp = exp - leadings;
      upk.man = (man << leadings) | sticky;
    } else {
      upk.exp = EXP_MIN;
      upk.man = 0;
    }
  } else {
    upk.exp = exp;
    upk.man = man;
  }

  if (*failed) {
    upk.man = 0;
    upk.exp = 0;
  }

  return unum4_pack(upk, &overflow);
}

double unum42double(unum4 input) {
  Unum4Unpacked upk = unum4_unpack(input);
  return (double)upk.man * pow(2, (upk.exp - DATA_W + EW_W + upk.ew));
}

int8_t unum4_compare(Unum4Unpacked a, Unum4Unpacked b) {
  int8_t res;

  a.man <<= a.ew;
  b.man <<= b.ew;

  if (a.exp > b.exp) {
    res = 1;
    if (a.man < 0) res = -1;
  } else if (a.exp < b.exp) {
    res = -1;
    if (b.man < 0) res = 1;
  } else {
    res = 0;
    if (a.man > b.man) res = 1;
    else if (a.man < b.man) res = -1;
  }

  return res;
}
