// This file has been auto-generated

#ifndef INCLUDED_VERSAT_ACCELERATOR_HEADER
#define INCLUDED_VERSAT_ACCELERATOR_HEADER

struct AcceleratorConfig{
int TOP_input_0_constant;
int TOP_input_1_constant;
};

struct AcceleratorState{
int TOP_output_0_currentValue;
int TOP_output_0_currentDelay;
};

static const int memMappedStart = 0x20;

static unsigned int delayBuffer[] = {
   0x1
   };

static unsigned int staticBuffer[] = {
   };

void versat_init(int base);
void RunAccelerator(int times);

// Needed by PC-EMUL to correctly simulate the design, embedded compiler should remove these symbols from firmware because not used by them 
static const char* acceleratorTypeName = "unum4_fpu";
static bool isSimpleAccelerator = true;

static const int staticStart = 0x1c;
static const int delayStart = 0x1c;
static const int configStart = 0x14;
static const int stateStart = 0x14;

extern volatile AcceleratorConfig* accelConfig;
extern volatile AcceleratorState* accelState;

#define TOP_input_0_constant accelConfig->TOP_input_0_constant
#define TOP_input_1_constant accelConfig->TOP_input_1_constant
#define TOP_output_0_currentValue accelState->TOP_output_0_currentValue
#define TOP_output_0_currentDelay accelState->TOP_output_0_currentDelay
#endif // INCLUDED_VERSAT_ACCELERATOR_HEADER
