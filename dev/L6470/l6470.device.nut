/* L6470 Stepper Motor Driver Breakout Firmware 
  https://www.sparkfun.com/products/10859
  
  Test Pinout:
  1 - CK (SPI SCLK)
  2 - CS_L
  5 - RST_L
  7 - FLAGN
  8 - SDI (SPI MOSI)
  9 - SDO (SPI MISO)
*/

/* GLOBALS AND CONSTS --------------------------------------------------------*/
// constant definitions for overcurrent thresholds. Write these values to 
//  register dSPIN_OCD_TH to set the level at which an overcurrent even occurs.
const dSPIN_OCD_TH_375mA  = 0x00;
const dSPIN_OCD_TH_750mA  = 0x01;
const dSPIN_OCD_TH_1125mA = 0x02;
const dSPIN_OCD_TH_1500mA = 0x03;
const dSPIN_OCD_TH_1875mA = 0x04;
const dSPIN_OCD_TH_2250mA = 0x05;
const dSPIN_OCD_TH_2625mA = 0x06;
const dSPIN_OCD_TH_3000mA = 0x07;
const dSPIN_OCD_TH_3375mA = 0x08;
const dSPIN_OCD_TH_3750mA = 0x09;
const dSPIN_OCD_TH_4125mA = 0x0A;
const dSPIN_OCD_TH_4500mA = 0x0B;
const dSPIN_OCD_TH_4875mA = 0x0C;
const dSPIN_OCD_TH_5250mA = 0x0D;
const dSPIN_OCD_TH_5625mA = 0x0E;
const dSPIN_OCD_TH_6000mA = 0x0F;

// STEP_MODE option values.
// First comes the "microsteps per step" options...
const dSPIN_STEP_MODE_STEP_SEL = 0x07  // Mask for these bits only.
const dSPIN_STEP_SEL_1     = 0x00;
const dSPIN_STEP_SEL_1_2   = 0x01;
const dSPIN_STEP_SEL_1_4   = 0x02;
const dSPIN_STEP_SEL_1_8   = 0x03;
const dSPIN_STEP_SEL_1_16  = 0x04;
const dSPIN_STEP_SEL_1_32  = 0x05;
const dSPIN_STEP_SEL_1_64  = 0x06;
const dSPIN_STEP_SEL_1_128 = 0x07;

// ...next, define the SYNC_EN bit. When set, the BUSYN pin will instead
//  output a clock related to the full-step frequency as defined by the
//  SYNC_SEL bits below.
const dSPIN_STEP_MODE_SYNC_EN = 0x80  // Mask for this bit
const dSPIN_SYNC_EN = 0x80

// ...last, define the SYNC_SEL modes. The clock output is defined by
//  the full-step frequency and the value in these bits- see the datasheet
//  for a matrix describing that relationship (page 46).
const dSPIN_STEP_MODE_SYNC_SEL = 0x70;
const dSPIN_SYNC_SEL_1_2 = 0x00;
const dSPIN_SYNC_SEL_1  = 0x10;
const dSPIN_SYNC_SEL_2  = 0x20;
const dSPIN_SYNC_SEL_4  = 0x30;
const dSPIN_SYNC_SEL_8  = 0x40;
const dSPIN_SYNC_SEL_16 = 0x50;
const dSPIN_SYNC_SEL_32 = 0x60;
const dSPIN_SYNC_SEL_64 = 0x70;

// Bit names for the ALARM_EN register.
//  Each of these bits defines one potential alarm condition.
//  When one of these conditions occurs and the respective bit in ALARM_EN is set,
//  the FLAG pin will go low. The register must be queried to determine which event
//  caused the alarm.
const dSPIN_ALARM_EN_OVERCURRENT       = 0x01;
const dSPIN_ALARM_EN_THERMAL_SHUTDOWN  = 0x02;
const dSPIN_ALARM_EN_THERMAL_WARNING   = 0x04;
const dSPIN_ALARM_EN_UNDER_VOLTAGE     = 0x08;
const dSPIN_ALARM_EN_STALL_DET_A       = 0x10;
const dSPIN_ALARM_EN_STALL_DET_B       = 0x20;
const dSPIN_ALARM_EN_SW_TURN_ON        = 0x40;
const dSPIN_ALARM_EN_WRONG_NPERF_CMD   = 0x80;

// CONFIG register renames.

// Oscillator options.
// The dSPIN needs to know what the clock frequency is because it uses that for some
//  calculations during operation.
const dSPIN_CONFIG_OSC_SEL                 = 0x000F; // Mask for this bit field.
const dSPIN_CONFIG_INT_16MHZ               = 0x0000; // Internal 16MHz, no output 
const dSPIN_CONFIG_INT_16MHZ_OSCOUT_2MHZ   = 0x0008; // Default; internal 16MHz, 2MHz output
const dSPIN_CONFIG_INT_16MHZ_OSCOUT_4MHZ   = 0x0009; // Internal 16MHz, 4MHz output
const dSPIN_CONFIG_INT_16MHZ_OSCOUT_8MHZ   = 0x000A; // Internal 16MHz, 8MHz output
const dSPIN_CONFIG_INT_16MHZ_OSCOUT_16MHZ  = 0x000B; // Internal 16MHz, 16MHz output
const dSPIN_CONFIG_EXT_8MHZ_XTAL_DRIVE     = 0x0004; // External 8MHz crystal
const dSPIN_CONFIG_EXT_16MHZ_XTAL_DRIVE    = 0x0005; // External 16MHz crystal
const dSPIN_CONFIG_EXT_24MHZ_XTAL_DRIVE    = 0x0006; // External 24MHz crystal
const dSPIN_CONFIG_EXT_32MHZ_XTAL_DRIVE    = 0x0007; // External 32MHz crystal
const dSPIN_CONFIG_EXT_8MHZ_OSCOUT_INVERT  = 0x000C; // External 8MHz crystal, output inverted
const dSPIN_CONFIG_EXT_16MHZ_OSCOUT_INVERT = 0x000D; // External 16MHz crystal, output inverted
const dSPIN_CONFIG_EXT_24MHZ_OSCOUT_INVERT = 0x000E; // External 24MHz crystal, output inverted
const dSPIN_CONFIG_EXT_32MHZ_OSCOUT_INVERT = 0x000F; // External 32MHz crystal, output inverted

// Configure the functionality of the external switch input
const dSPIN_CONFIG_SW_MODE              =  0x0010; // Mask for this bit.
const dSPIN_CONFIG_SW_HARD_STOP         =  0x0000; // Default; hard stop motor on switch.
const dSPIN_CONFIG_SW_USER              =  0x0010; // Tie to the GoUntil and ReleaseSW
                                                    //  commands to provide jog function.
                                                    //  See page 25 of datasheet.

// Configure the motor voltage compensation mode (see page 34 of datasheet)
const dSPIN_CONFIG_EN_VSCOMP              = 0x0020;  // Mask for this bit.
const dSPIN_CONFIG_VS_COMP_DISABLE        = 0x0000;  // Disable motor voltage compensation.
const dSPIN_CONFIG_VS_COMP_ENABLE         = 0x0020; // Enable motor voltage compensation.

// Configure overcurrent detection event handling
const dSPIN_CONFIG_OC_SD                  = 0x0080;  // Mask for this bit.
const dSPIN_CONFIG_OC_SD_DISABLE          = 0x0000;  // Bridges do NOT shutdown on OC detect
const dSPIN_CONFIG_OC_SD_ENABLE           = 0x0080;  // Bridges shutdown on OC detect

// Configure the slew rate of the power bridge output
const dSPIN_CONFIG_POW_SR                 = 0x0300;  // Mask for this bit field.
const dSPIN_CONFIG_SR_180V_us             = 0x0000;  // 180V/us
const dSPIN_CONFIG_SR_290V_us             = 0x0200;  // 290V/us
const dSPIN_CONFIG_SR_530V_us             = 0x0300;  // 530V/us

// Integer divisors for PWM sinewave generation
//  See page 32 of the datasheet for more information on this.
/*
const dSPIN_CONFIG_F_PWM_DEC              = 0x1C00;      // mask for this bit field
const dSPIN_CONFIG_PWM_MUL_0_625          = 0x00;
const dSPIN_CONFIG_PWM_MUL_0_75           = 10;
const dSPIN_CONFIG_PWM_MUL_0_875          = 0x020000000000;
const dSPIN_CONFIG_PWM_MUL_1              = 0x030000000000;
const dSPIN_CONFIG_PWM_MUL_1_25           = 0x040000000000;
const dSPIN_CONFIG_PWM_MUL_1_5            = 0x050000000000;
const dSPIN_CONFIG_PWM_MUL_1_75           = 0x060000000000;
const dSPIN_CONFIG_PWM_MUL_2              = 0x070000000000;

// Multiplier for the PWM sinewave frequency
const dSPIN_CONFIG_F_PWM_INT              = 0xE000;     // mask for this bit field.
const dSPIN_CONFIG_PWM_DIV_1              = 0x00;
const dSPIN_CONFIG_PWM_DIV_2              = 0x010000000000000;
const dSPIN_CONFIG_PWM_DIV_3              = 0x020000000000000;
const dSPIN_CONFIG_PWM_DIV_4              = 0x030000000000000;
const dSPIN_CONFIG_PWM_DIV_5              = 0x040000000000000;
const dSPIN_CONFIG_PWM_DIV_6              = 0x050000000000000;
const dSPIN_CONFIG_PWM_DIV_7              = 0x060000000000000;
*/
// Status register bit renames- read-only bits conferring information about the
//  device to the user.
const dSPIN_STATUS_HIZ                    = 0x0001; // high when bridges are in HiZ mode
const dSPIN_STATUS_BUSY                   = 0x0002; // mirrors BUSY pin
const dSPIN_STATUS_SW_F                   = 0x0004; // low when switch open, high when closed
const dSPIN_STATUS_SW_EVN                 = 0x0008; // active high, set on switch falling edge,
                                                    //  cleared by reading STATUS
const dSPIN_STATUS_DIR                    = 0x0010; // Indicates current motor direction.
                                                    //  High is FWD, Low is REV.
const dSPIN_STATUS_NOTPERF_CMD            = 0x0080; // Last command not performed.
const dSPIN_STATUS_WRONG_CMD              = 0x0100; // Last command not valid.
const dSPIN_STATUS_UVLO                   = 0x0200; // Undervoltage lockout is active
const dSPIN_STATUS_TH_WRN                 = 0x0400; // Thermal warning
const dSPIN_STATUS_TH_SD                  = 0x0800; // Thermal shutdown
const dSPIN_STATUS_OCD                    = 0x1000; // Overcurrent detected
const dSPIN_STATUS_STEP_LOSS_A            = 0x2000; // Stall detected on A bridge
const dSPIN_STATUS_STEP_LOSS_B            = 0x4000; // Stall detected on B bridge
const dSPIN_STATUS_SCK_MOD                = 0x8000; // Step clock mode is active

// Status register motor status field
const dSPIN_STATUS_MOT_STATUS              =   0x0060;      // field mask
const dSPIN_STATUS_MOT_STATUS_STOPPED      =   0x0000; // Motor stopped
/*
const dSPIN_STATUS_MOT_STATUS_ACCELERATION =  0x00010000000000000; // Motor accelerating
const dSPIN_STATUS_MOT_STATUS_DECELERATION =  0x00020000000000000; // Motor decelerating
const dSPIN_STATUS_MOT_STATUS_CONST_SPD    =  0x00030000000000000; // Motor at constant speed
*/

// Register address redefines.
// See the dSPIN_Param_Handler() function for more info about these.
const dSPIN_ABS_POS         =     0x01;
const dSPIN_EL_POS          =     0x02;
const dSPIN_MARK            =     0x03;
const dSPIN_SPEED           =     0x04;
const dSPIN_ACC             =     0x05;
const dSPIN_DEC             =     0x06;
const dSPIN_MAX_SPEED       =     0x07;
const dSPIN_MIN_SPEED       =     0x08;
const dSPIN_FS_SPD          =     0x15;
const dSPIN_KVAL_HOLD       =     0x09;
const dSPIN_KVAL_RUN        =     0x0A;
const dSPIN_KVAL_ACC        =     0x0B;
const dSPIN_KVAL_DEC        =     0x0C;
const dSPIN_INT_SPD         =     0x0D;
const dSPIN_ST_SLP          =     0x0E;
const dSPIN_FN_SLP_ACC      =     0x0F;
const dSPIN_FN_SLP_DEC      =     0x10;
const dSPIN_K_THERM         =     0x11;
const dSPIN_ADC_OUT         =     0x12;
const dSPIN_OCD_TH          =     0x13;
const dSPIN_STALL_TH        =     0x14;
const dSPIN_STEP_MODE       =     0x16;
const dSPIN_ALARM_EN        =     0x17;
const dSPIN_CONFIG          =     0x18;
const dSPIN_STATUS          =     0x19;

//dSPIN commands
const dSPIN_NOP             =     0x00;
const dSPIN_SET_PARAM       =     0x00;
const dSPIN_GET_PARAM       =     0x20;
const dSPIN_RUN             =     0x50;
const dSPIN_STEP_CLOCK      =     0x58;
const dSPIN_MOVE            =     0x40;
const dSPIN_GOTO            =     0x60;
const dSPIN_GOTO_DIR        =     0x68;
const dSPIN_GO_UNTIL        =     0x82;
const dSPIN_RELEASE_SW      =     0x92;
const dSPIN_GO_HOME         =     0x70;
const dSPIN_GO_MARK         =     0x78;
const dSPIN_RESET_POS       =     0xD8;
const dSPIN_RESET_DEVICE    =     0xC0;
const dSPIN_SOFT_STOP       =     0xB0;
const dSPIN_HARD_STOP       =     0xB8;
const dSPIN_SOFT_HIZ        =     0xA0;
const dSPIN_HARD_HIZ        =     0xA8;
const dSPIN_GET_STATUS      =     0xD0;

/* dSPIN direction options */
const FWD = 0x01;
const REV = 0x00;

/* dSPIN action options */
const ACTION_RESET = 0x00;
const ACTION_COPY  = 0x01;

/* CLASS AND FUNCTION DEFINITIONS --------------------------------------------*/

/* Class to drive the L6470 "dSPIN" stepper motor driver
 * https://www.sparkfun.com/products/10859
 * http://dlnmh9ip6v2uc.cloudfront.net/datasheets/Robotics/dSPIN.pdf
 * 
 * Constructor Takes three arguments:
 *    1. Unconfigured SPI object
 *    2. pin object for Chip select (active low), 
 *    3. pin object for Flag interrupts (active low)
 */
class L6470 {
  /* Member variables */
  spi = null;       // spi bus
  alert_l = null;   // alert pin
  cs_l = null;      // chip select
  rst_l = null;     // reset line
  
  /* Internal Methods (used to implement high-level methods) -----------------*/
  
  /* Calculate the value in the ACC register
   * Actual value is [(steps/s/s)*(tick^2)]/(2^-40), where tick is 250ns - 0x08A on boot
   * Multiply desired steps/s/s by 0.137438 to get approx value for register
   * Register value is 12 bits, so ensure value is at or below 0x0FFF
   */
  function AccCalc(stepsPerSecPerSec) {
    local tmp = stepsPerSecPerSec * 0.137438;
    if (tmp > 0x0FFF) return 0x0FFF;
    else return tmp;
  }
  
  /* Calculate the value in the DEC register
   * Method is identical to the ACC register
   */
  function DecCalc(stepsPerSecPerSec) {
    local tmp = stepsPerSecPerSec * 0.137438;
    if (tmp > 0x0FFF) return 0x0FFF;
    else return tmp;
  }
  
  /* The value in the MAX_SPD register is [(steps/s)*(tick)]/(2^-18), where tick 
   * is 250ns - 0x041 on boot
   * Multiply desired steps/s by 0.065535 to get value for the register
   * Value is 10 bits, so ceiling at 0x03FF
   */
  function MaxSpdCalc(stepsPerSec) {
    local tmp = stepsPerSec * 0.065535;
    if (tmp > 0x03FF) return 0x03FF;
    else return tmp;
  }
  
  /* The value in the MIN_SPD register is [(steps/s)*(tick)]/(2^-24), where tick
   * is 250ns - 0x000 on boot
   * Multiply desired steps/s by 4.1943 to get value for register
   * Value is 12 bits, so ceiling at 0x0FFF
   */
  function MinSpdCalc(stepsPerSec) {
    local tmp = stepsPerSec * 4.1934;
    if (tmp > 0x0FFF) return 0x0FFF;
    else return tmp;
  }
  
  /* The value in the FS_SPD register is ([(steps/s)*(tick)]/(2^-18))-0.5, where
   * tick is 250ns - 0x027 on boot.
   * Multiply desired steps/s by 0.065535 and subtract 0.5 to get register value.
   * Value is 10 bits, so ceiling at 0x03FF
   */
  function FSCalc(stepsPerSec) {
    local tmp = (stepsPerSec * 0.065536) - 0.5;
    if (tmp > 0x03FF) return 0x03FF;
    else return tmp;
  }
  
  /* The value in the INT_SPD register is [(steps/s)*(tick)]/(2^-24), where tick
   * is 250ns - 0x408 on boot.
   * Multiply desired steps/s by 4.1943 to get register value.
   * Value is 14 bits.
   */
  function IntSpdCalc(stepsPerSec) {
    local tmp = stepsPerSec * 4.1943;
    if (tmp > 0x3FFF) return 0x3FFF;
    else return tmp;
  }
  
  /* When sending the RUN command, the 20-bit speed is [(steps/s)*(tick)]/(2^-28),
   * where tick is 250ns.
   * Multiply desired steps/s by 67.106 to get the register value.
   * Value is 14 bits
   */
  function SpdCalc(stepsPerSec) {
    local tmp = stepsPerSec * 67.106;
    if (tmp > 0x000FFFFF) return 0x000FFFFF;
    else return tmp;
  }
  
  /* Handle interrupts from the FLAG pin */
  function handleFlag() {
    server.log("L6470 threw a flag.");
  }
  
  /* A somewhat-frivolous wrapper for spi.readwrite().
   * Handles toggling cs_l, which the L6470 requires on every byte transferred,
   * so at least it's SILLY + SILLY = SLIGHTLY_LESS_SILLY
   */
  function dspinXfer(data) {
    server.log(format("dspinXfer sending: 0x%02x",data));
    cs_l.write(0);
    //local resultStr = spi.writeread(format("%c",(data & 0xFF)));
    //TODO: Change this to use SPI blob read/write, as it involves less messing around.
    local resultStr = spi.writeread("\x38");
    cs_l.write(1);
    local result = resultStr[0];
    return result;
  }
  
  /* Another somewhat-frivolous wrapper for spi.readwrite(). 
   * This allows the end user to do the equivalent to a multi-byte spi.readwrite()
   * without worrying about parameter length, as the L6470 requires the CS_L pin 
   * to toggle low on each byte boundary. 
   */
  function dspinParam(value, bit_len = 8) {
    // return the read value to allow this function to work in the general case
    local ret_val = 0;
    local byte_len = bit_len / 8;
    //server.log(format("dspinParam reading back %d bits (in %d bytes)", bit_len, byte_len));
    if ((bit_len % 8) > 0) {
      byte_len += 1;
    }
    //server.log("Fetching "+byte_len+" bytes");
    // make sure value does not have spurious bits set, and ceiling the value
    local mask = 0xffffffff >> (32-bit_len);
    //server.log(format("Value: 0x%08x, Mask: 0x%08x", value, mask));
    if (value > mask) value = mask;
    
    // All transfers are no less than 1 but no more than 3 bytes long.
    if (byte_len == 3) {
      //server.log("Fetching Byte 3");
      ret_val = (ret_val | dspinXfer((value >> 16) & 0xFF) << 16);
    }
    if (byte_len >= 2) {
      //server.log("Fetching Byte 2");
      ret_val = (ret_val | dspinXfer((value >> 8) & 0xFF) << 8);
    }
    if (byte_len >= 1) {
      //server.log("Fetching Byte 1");
      ret_val = (ret_val | dspinXfer(value & 0xFF));
    }
    
    return (ret_val & mask);
  }
  
  /* HIGHER-LEVEL METHODS ----------------------------------------------------*/
  
  /* Constructor
   * Takes in a SPI object, a pin object for Chip select, 
   * and a pin object for Flag interrupts 
   */
  constructor(_spi, _cs_l, _alert_l, _rst_l) {
    this.spi = _spi;
    this.cs_l = _cs_l;
    this.alert_l = _alert_l;
    this.rst_l = _rst_l;
    
    spi.configure(LSB_FIRST, 4000);
    cs_l.configure(DIGITAL_OUT);
    cs_l.write(1);
    alert_l.configure(DIGITAL_IN_PULLUP,handleFlag);
    rst_l.configure(DIGITAL_OUT);
    
    // send reset pulse
    rst_l.write(0);
    imp.sleep(0.00001); // 100 us pulse
    rst_l.write(1);
    
    server.log("L6470 Stepper Motor Driver Initialized.");
  }
  
  /* Much of get/set parameter functionality is identical between get/set.
   * This function combines this core functionality for simplicity and code size.
   */
  function paramHandler(param, value) {
    local ret_val = 0;
    /* Not all registers are the same length, bit- or byte-wise. Mask out any 
     * spurious bits and conduct correct number of byte transfers. Most operations
     * are done via dspinParam(), but some call dspinXfer() directly.
     */
    switch (param) {
      /* ABS_POS is the current absolute offset from home. This is a 22-bit number
       * expressed in 2's complement. At power-up, this value is 0. It cannot be 
       * written when the motor is running. Any other time, it can be updated to
       * change the interpreted position of the motor
       */
      case dSPIN_ABS_POS:
        ret_val = dspinParam(value, 22);
        break;
      /* EL_POS is the current electrical position of the step generation cycle.
       * It can be set when the motor is not in motion. Value is 0 on power-up.
       */
      case dSPIN_EL_POS:
        ret_val = dspinParam(value, 9);
        break;
      /* MARK is a second postion other than 0, which the motor can be told to go to.
       * As with ABS_POS, it is 22-bit 2's complement. Value is 0 on power-up.
       */
      case dSPIN_MARK:
        ret_val = dspinParam(value, 22);
        break;
      /* SPEED contains information about the current motor speed. SPEED is 
       * read-only. This register does not provide direction information.
       */
      case dSPIN_SPEED:
        ret_val = dspinParam(value, 20);
        break;
      /* ACC and DEC set the acceleration and deceleration rates. Set ACC to 
       * 0x0FFF to get infinite acceleration/deceleration. There is no way to 
       * get infinite deceleration w/o infinite acceleration (except the HARD_STOP
       * command). Cannot be written while motor is running. Both default to 0x08A
       * on power-up. AccCalc() and DecCalc() functions exist to convert steps/s/s 
       * values into 12-bit values for these two registers
       */
      case dSPIN_ACC:
        ret_val = dspinParam(value, 12);
        break;
      case dSPIN_DEC:
        ret_val = dspinParam(value, 12);
        break;
      /* MAX_SPEED is the the hard limit of the speed of the motor. Any command
       * which attempts to set the motor to a speed greater than MAX_SPEED will 
       * simply cause the motor to turn at MAX_SPEED. Value is 0x041 on power-up.
       * MaxSpdCalc() function exists to convert steps/s value into 10-bit value
       * for this register.
       */
      case dSPIN_MAX_SPEED:
        ret_val = dspinParam(value, 10);
        break;
      /* MIN_SPEED controls two things: the activation of the low-speed optimization
       * feature, and the lowest speed the motor will be allowed to turn. LSPD_OPT
       * is the 13th bit. When set, the minimum allowed speed is automatically set 
       * to 0. This value is 0 on startup.
       * MinSpdCalc() exists to convert steps/s value into a 12-bit value for this
       * register. SetLSPDOpt() function exists to enable/disablw the optimization
       * feature.
       */
      case dSPIN_MIN_SPEED:
        ret_val = dspinParam(value, 12);
        break;
      /* FS_SPD register contains a threshold value above which microstepping is 
       * disabled and the dSPIN operates in full-step mode. Defaults to 0x027 on
       * power-up. FSCalc() function exists to convert steps/s value into a 10-bit
       * integer for this register. 
       */
      case dSPIN_FS_SPD:
        ret_val = dspinParam(value, 10);
        break;
      /* KVAL is the maximum voltage of the PWM outputs. These 8-bit values are 
       * ratiometric representations: 255 for the full output voltage, 128 for half,
       * etc. Default is 0x29.
       */
      case dSPIN_KVAL_HOLD:
        ret_val = dspinXfer(value);
        break;
      case dSPIN_KVAL_RUN:
        ret_val = dspinXfer(value);
        break;
      case dSPIN_KVAL_ACC:
        ret_val = dspinXfer(value);
        break;
      case dSPIN_KVAL_DEC:
        ret_val = dspinXfer(value);
        break;
      /* INT_SPD, ST_SLP, FN_SLP_ACC, and FN_SLP_DEC are all related to the
       * back-EMF compensation functionality. Please see datasheet. Default values
       * should be sufficiently effective for most users.
       */
      case dSPIN_INT_SPD:
        ret_val = dspinParam(value, 14);
        break;
      case dSPIN_ST_SLP:
        ret_val = dspinXfer(value);
        break;
      case dSPIN_FN_SLP_ACC:
        ret_val = dspinXfer(value);
        break;
      case dSPIN_FN_SLP_DEC:
        ret_val = dspinXfer(value);
        break;
      /* K_THERM is motor winding thermal drift compensation. Please see datasheet.
       * Default should be fine for just about everyone. 
       */
      case dSPIN_K_THERM:
        ret_val = dspinXfer(value & 0x0F);
        break;
      /* ADC_OUT is a read-only register containing the result of the ADC measurements.
       * This is less useful than it sounds; see the datasheet for more information.
       */
      case dSPIN_ADC_OUT:
        ret_val = dspinXfer(0);
        break;
      /* Set the overcurrent threshold. Ranges from 375mA to 6A in steps of 375mA.
       * A set of defined constants is provided for the user's convenience. Default
       * value is 3.375A- 0x08. This is a 4-bit value.
       */
      case dSPIN_OCD_TH: 
        ret_val = dspinXfer(value & 0x0F);
        break;
      /* Stall current threshold. Defaults to 0x40, or 2.03A. Value is from 31.25mA to
       * 4A in 31.25mA steps. This is a 7-bit value.
       */
      case dSPIN_STALL_TH: 
        ret_val = dspinXfer(value & 0x7F);
        break;
      /* STEP_MODE controls the microstepping settings, as well as the generation of an
       *  output signal from the dSPIN. Bits 2:0 control the number of microsteps per
       *  step the part will generate. Bit 7 controls whether the BUSY/SYNC pin outputs
       *  a BUSY signal or a step synchronization signal. Bits 6:4 control the frequency
       *  of the output signal relative to the full-step frequency; see datasheet for
       *  that relationship as it is too complex to reproduce here.
       * Most likely, only the microsteps per step value will be needed; there is a set
       *  of constants provided for ease of use of these values.
       */
      case dSPIN_STEP_MODE:
        ret_val = dspinXfer(value);
        break;
      /* ALARM_EN controls which alarms will cause the FLAG pin to fall. A set of constants
       * is provided to make this easy to interpret. By default, ALL alarms will trigger the
       * FLAG pin.
       */
      case dSPIN_ALARM_EN: 
        ret_val = dspinXfer(value);
        break;
      /* CONFIG contains some assorted configuration bits and fields. A fairly comprehensive
       * set of reasonably self-explanatory constants is provided, but users should refer
       * to the datasheet before modifying the contents of this register to be certain they
       * understand the implications of their modifications. Value on boot is 0x2E88; this
       * can be a useful way to verify proper start up and operation of the dSPIN chip.
       */
      case dSPIN_CONFIG: 
        ret_val = dspinParam(value, 16);
        break;
      /* STATUS contains read-only information about the current condition of the chip. A
       * comprehensive set of constants for masking and testing this register is provided, but
       * users should refer to the datasheet to ensure that they fully understand each one of
       * the bits in the register.
       */
      case dSPIN_STATUS:  // STATUS is a read-only register
        ret_val = dspinParam(0, 16);
        break;
      default:
        ret_val = dspinXfer(value);
        break;
    }
    return ret_val;
  }
  
  /* Generic "get parameter from register" function */
  function setParam(param, value) {
    dspinXfer(dSPIN_SET_PARAM | param);
    return paramHandler(param, 0);
  }
  
  /* Generic "get parameter from register" function */
  function getParam(param) {
    server.log(format("getParam: asking for 0x%04x",param));
    server.log(format("getParam: full cmd is 0x%04x",(dSPIN_GET_PARAM | param)));
    dspinXfer(dSPIN_GET_PARAM | param);
    return paramHandler(param, 0);
  }

  /* Enable or disable the low-speed optimization option. If enabling,
   *  the other 12 bits of the register will be automatically zero.
   *  When disabling, the value will have to be explicitly written by
   *  the user with a SetParam() call. See the datasheet for further
   *  information about low-speed optimization.
   */
  function SetLSPDOpt( enable) {
    dspinXfer(dSPIN_SET_PARAM | dSPIN_MIN_SPEED);
    if (enable) dspinParam(0x1000, 13);
    else dspinParam(0, 13);
  }
    
  /* RUN sets the motor spinning in a direction (defined by the constants
   *  FWD and REV). Maximum speed and minimum speed are defined
   *  by the MAX_SPEED and MIN_SPEED registers; exceeding the FS_SPD value
   *  will switch the device into full-step mode.
   *  The SpdCalc() function is provided to convert steps/s values into
   *  appropriate integer values for this function.
   */
  function run(dir, spd) {
    dspinXfer(dSPIN_RUN | dir);
    if (spd > 0xFFFFF) spd = 0xFFFFF;
    dspinXfer((spd >> 16) & 0xFF);
    dspinXfer((spd >> 8) & 0xFF);
    dspinXfer(spd & 0xFF);
  }
  
  /* STEP_CLOCK puts the device in external step clocking mode. When active,
   *  pin 25, STCK, becomes the step clock for the device, and steps it in
   *  the direction (set by the FWD and REV constants) imposed by the call
   *  of this function. Motion commands (RUN, MOVE, etc) will cause the device
   *  to exit step clocking mode.
   */
  function stepClock(dir) {
    dspinXfer(dSPIN_STEP_CLOCK | dir);
  }
  
  /* MOVE will send the motor n_step steps (size based on step mode) in the
   *  direction imposed by dir (FWD or REV constants may be used). The motor
   *  will accelerate according the acceleration and deceleration curves, and
   *  will run at MAX_SPEED. Stepping mode will adhere to FS_SPD value, as well.
   */
  function move(dir, n_step) {
    dspinXfer(dSPIN_MOVE | dir);
    if (n_step > 0x3FFFFF) n_step = 0x3FFFFF;
    dspinXfer((n_step >> 16) & 0xFF);
    dspinXfer((n_step >> 8) & 0xFF);
    dspinXfer(n_step & 0xFF);
  }
  
  /* GOTO operates much like MOVE, except it produces absolute motion instead
   *  of relative motion. The motor will be moved to the indicated position
   *  in the shortest possible fashion.
   */
  function goTo(pos) {
    dspinXfer(dSPIN_GOTO);
    if (pos > 0x3FFFFF) pos = 0x3FFFFF;
    dspinXfer((pos >> 16) & 0xFF);
    dspinXfer((pos >> 8) & 0xFF);
    dspinXfer(pos & 0xFF);
  }
  
  // Same as GOTO, but with user constrained rotational direction.
  function goTo_dir(dir, pos) {
    dspinXfer(dSPIN_GOTO_DIR);
    if (pos > 0x3FFFFF) pos = 0x3FFFFF;
    dspinXfer((pos >> 16) & 0xFF);
    dspinXfer((pos >> 8) & 0xFF);
    dspinXfer(pos & 0xFF);
  }
  
  /* GoUntil will set the motor running with direction dir (REV or
   *  FWD) until a falling edge is detected on the SW pin. Depending
   *  on bit SW_MODE in CONFIG, either a hard stop or a soft stop is
   *  performed at the falling edge, and depending on the value of
   *  act (either RESET or COPY) the value in the ABS_POS register is
   *  either RESET to 0 or COPY-ed into the MARK register.
   */
  function goUntil(act, dir, spd) {
    dspinXfer(dSPIN_GO_UNTIL | act | dir);
    if (spd > 0x3FFFFF) spd = 0x3FFFFF;
    dspinXfer((spd >> 16) & 0xFF);
    dspinXfer((spd >> 8) & 0xFF);
    dspinXfer(spd & 0xFF);
  }
  
  /* Similar in nature to GoUntil, ReleaseSW produces motion at the
   *  higher of two speeds: the value in MIN_SPEED or 5 steps/s.
   *  The motor continues to run at this speed until a rising edge
   *  is detected on the switch input, then a hard stop is performed
   *  and the ABS_POS register is either COPY-ed into MARK or RESET to
   *  0, depending on whether RESET or COPY was passed to the function
   *  for act.
   */
  function releaseSW(act, dir) {
    dspinXfer(dSPIN_RELEASE_SW | act | dir);
  }
  
  /* GoHome is equivalent to GoTo(0), but requires less time to send.
   *  Note that no direction is provided; motion occurs through shortest
   *  path. If a direction is required, use GoTo_DIR().
   */
  function goHome() {
    dspinXfer(dSPIN_GO_HOME);
  }
  
  /* GoMark is equivalent to GoTo(MARK), but requires less time to send.
   *  Note that no direction is provided; motion occurs through shortest
   *  path. If a direction is required, use GoTo_DIR().
   */
  function goMark() {
    dspinXfer(dSPIN_GO_MARK);
  }
  
  /* Sets the ABS_POS register to 0, effectively declaring the current
   *  position to be "HOME".
   */
  function resetPos() {
    dspinXfer(dSPIN_RESET_POS);
  }
  
  /* Reset device to power up conditions. Equivalent to toggling the STBY
   *  pin or cycling power.
   */
  function reset() {
    dspinXfer(dSPIN_RESET_DEVICE);
  }
    
  // Bring the motor to a halt using the deceleration curve.
  function softStop() {
    dspinXfer(dSPIN_SOFT_STOP);
  }
  
  // Stop the motor with infinite deceleration.
  function hardStop() {
    dspinXfer(dSPIN_HARD_STOP);
  }
  
  // Decelerate the motor and put the bridges in Hi-Z state.
  function softHiZ() {
    dspinXfer(dSPIN_SOFT_HIZ);
  }
  
  // Put the bridges in Hi-Z state immediately with no deceleration.
  function hardHiZ() {
    dspinXfer(dSPIN_HARD_HIZ);
  }
  
  /* Fetch and return the 16-bit value in the STATUS register. Resets
   *  any warning flags and exits any error states. Using GetParam()
   *  to read STATUS does not clear these values.
   */
  function getStatus() {
    local tmp = 0;
    dspinXfer(dSPIN_GET_STATUS);
    tmp = dspinXfer(0) << 8;
    tmp = tmp | dspinXfer(0);
    return tmp;
  }
  
} 
  
/* RUNTIME BEGINS HERE -------------------------------------------------------*/
imp.configure("dspin driver",[],[]);
imp.enableblinkup(true);

motor <- L6470(hardware.spi189, hardware.pin2, hardware.pin7, hardware.pin5);

local config = motor.getParam(dSPIN_CONFIG);
server.log(format("Config Register: 0x%04x",config));