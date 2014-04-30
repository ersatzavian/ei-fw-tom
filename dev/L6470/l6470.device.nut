// L6470 "dSPIN" stepper motor driver IC
// http://www.st.com/st-web-ui/static/active/en/resource/technical/document/datasheet/CD00255075.pdf

// Consts and Globals ---------------------------------------------------------
const SPICLK = 4000; // kHz
const STEPS_PER_REV = 48; // using sparkfun's small stepper motor

const CONFIG_PWMDIV_1      = 0x0000;
const CONFIG_PWMDIV_2      = 0x2000;
const CONFIG_PWMDIV_3      = 0x4000;
const CONFIG_PWMDIV_4      = 0x5000;
const CONFIG_PWMDIV_5      = 0x8000;
const CONFIG_PWMDIV_6      = 0xA000;
const CONFIG_PWMDIV_7      = 0xC000;
const CONFIG_PWMMULT_0_625 = 0x0000;
const CONFIG_PWMMULT_0_750 = 0x0400;
const CONFIG_PWMMULT_0_875 = 0x0800;
const CONFIG_PWMMULT_1_000 = 0x0C00;
const CONFIG_PWMMULT_1_250 = 0x1000;
const CONFIG_PWMMULT_1_500 = 0x1400;
const CONFIG_PWMMULT_1_750 = 0x1800;
const CONFIG_PWMMULT_2_000 = 0x1C00;
const CONFIG_SR_320        = 0x0000;
const CONFIG_SR_75         = 0x0100;
const CONFIG_SR_110        = 0x0200;
const CONFIG_SR_260        = 0x0300;
const CONFIG_INT_OSC       = 0x0000;
const CONFIG_OC_SD         = 0x0080;
const CONFIG_VSCOMP        = 0x0020;
const CONFIG_SW_USER       = 0x0010;
const CONFIG_EXT_CLK       = 0x0008;

const STEP_MODE_SYNC    = 0x80;
const STEP_SEL_FULL     = 0x00;
const STEP_SEL_HALF     = 0x01;
const STEP_SEL_1_4      = 0x02;
const STEP_SEL_1_8      = 0x03;
const STEP_SEL_1_16     = 0x04;
const STEP_SEL_1_32     = 0x05;
const STEP_SEL_1_64     = 0x06;
const STEP_SEL_1_128    = 0x06;

const CMD_NOP		 	= 0x00;
const CMD_GOHOME		= 0x70;
const CMD_GOMARK		= 0x78;
const CMD_RESET_POS	    = 0xD8;
const CMD_RESET		    = 0xC0;
const CMD_RUN           = 0x50;
const CMD_SOFT_STOP	    = 0xB0;
const CMD_HARD_STOP	    = 0xB8;
const CMD_SOFT_HIZ		= 0xA0;
const CMD_HARD_HIZ		= 0xA8;
const CMD_GETSTATUS	    = 0xD0;	 
const CMD_GETPARAM      = 0x20;
const CMD_SETPARAM      = 0x00;

const REG_ABS_POS 		= 0x01;
const REG_EL_POS 		= 0x02;
const REG_MARK			= 0x03;
const REG_SPEED		    = 0x04;
const REG_ACC			= 0x05;
const REG_DEC			= 0x06;
const REG_MAX_SPD 		= 0x07;
const REG_MIN_SPD 		= 0x08;
const REG_KVAL_HOLD 	= 0x09;
const REG_KVAL_RUN 	    = 0x0A;
const REG_KVAL_ACC 	    = 0x0B;
const REG_KVAL_DEC 	    = 0x0C;
const REG_INT_SPD		= 0x0D;
const REG_ST_SLP		= 0x0E;
const REG_FN_SLP_ACC	= 0x0F;
const REG_FN_SLP_DEC	= 0x10;
const REG_K_THERM		= 0x11;
const REG_ADC_OUT		= 0x12;
const REG_OCD_TH		= 0x13;
const REG_STALL_TH		= 0x13;
const REG_STEP_MODE	    = 0x14;
const REG_FS_SPD		= 0x15;
const REG_STEP_MODE 	= 0x16;
const REG_ALARM_EN		= 0x17;
const REG_CONFIG 		= 0x18;
const REG_STATUS 		= 0x19;

class L6470 {

	spi 	= null;
	cs_l 	= null;
	rst_l 	= null;
	flag_l	= null;
	
	fs_speed = null;

	function handleFlag() {
		if (!flag_l.read()) { server.log("L6470 set flag"); }
		else { server.log("L6470 unset flag"); }
        server.log(format("Status Register: 0x%04x", getStatus()));
	}

	constructor(_spi, _cs_l, _rst_l, _flag_l) {
		this.spi 	= _spi;
		this.cs_l 	= _cs_l;
		this.rst_l 	= _rst_l;
		this.flag_l = _flag_l;

		cs_l.write(1);
		rst_l.write(1);
		flag_l.configure(DIGITAL_IN, handleFlag.bindenv(this));
	
		reset();
	}

	function reset() {
		rst_l.write(0);
		imp.sleep(0.001);
		rst_l.write(1);
	}
	
	function read(num_bytes) {
	    local result = 0;
	    for (local i = 0; i < num_bytes; i++) {
	        cs_l.write(0);
	        result += ((spi.writeread(format("%c",CMD_NOP))[0].tointeger() & 0xff) << (8 * (num_bytes - 1 - i)));
	        cs_l.write(1);
	    }
	    return result;
	}
	
	function write(data) {
	    local num_bytes = data.len();
	    local result = 0;
	    for (local i = 0; i < num_bytes; i++) {
	        cs_l.write(0);
	        result += ((spi.writeread(format("%c",data[i]))[0].tointeger() & 0xff) << (8 * (num_bytes - 1 - i)));
	        cs_l.write(1);
	    }
	    return result;
	}
	
	function getStatus() {
		write(format("%c",CMD_GETSTATUS));
		return read(2);
	}
	
	function setConfig(val) {
	    write(format("%c", CMD_SETPARAM | REG_CONFIG));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	function getConfig() {
	    write(format("%c",CMD_GETPARAM | REG_CONFIG));
		return read(2);
	}
	
	function setStepMode(val) {
	    write(format("%c", CMD_SETPARAM | REG_STEP_MODE));
	    write(format("%c", (val & 0xff)));
	}
	
	function getStepMode() {
	    write(format("%c",CMD_GETPARAM | REG_STEP_MODE));
		return read(1);
	}
	
	function setMinSpeed(stepsPerSec) {
	    local val = math.ceil(stepsPerSec * 0.065536).tointeger();
	    if (val > 0x03FF) { val = 0x03FF; }
	    write(format("%c", CMD_SETPARAM | REG_MIN_SPD));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	function getMaxSpeed() {
	    write(format("%c",CMD_GETPARAM | REG_MIN_SPD));
		return read(2);
	}
	
	function setMaxSpeed(stepsPerSec) {
	    local val = math.ceil(stepsPerSec * 0.065536).tointeger();
	    if (val > 0x03FF) { val = 0x03FF; }
	    write(format("%c", CMD_SETPARAM | REG_MAX_SPD));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	function getMaxSpeed() {
	    write(format("%c",CMD_GETPARAM | REG_MAX_SPD));
		return read(2);
	}
	
	function setFSSpeed(stepsPerSec) {
	    local val = math.ceil((stepsPerSec * 0.065536) - 0.5).tointeger();
	    if (val > 0x03FF) { val = 0x03FF; }
	    fs_speed = val;
	    write(format("%c", CMD_SETPARAM | REG_FS_SPD));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	function getFSSpeed() {
	    write(format("%c",CMD_GETPARAM | REG_FS_SPD));
		return read(2);
	}
	
	function setAcc(stepsPerSecPerSec) {
	    local val = math.ceil(stepsPerSecPerSec * 0.137438).tointeger();
        if (val > 0x0FFF) { val = 0x0FFF; }
	    write(format("%c", CMD_SETPARAM | REG_ACC));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	function setOcTh(threshold) {
	    local val = math.floor(threshold / 375).tointeger();
        if (val > 0x0f) { val = 0x0f; }
	    write(format("%c", CMD_SETPARAM | REG_OCD_TH));
	    write(format("%c", (val & 0xff)));
	}
	
	function setHoldKval(val) {
	    write(format("%c", CMD_SETPARAM | REG_KVAL_HOLD));
	    write(format("%c", (val & 0xff)));
	}
	
	function getHoldKval() {
	    write(format("%c", CMD_GETPARAM | REG_KVAL_HOLD));
	    write(format("%c", (val & 0xff)));
	}
	
	function setRunKval(val) {
	    write(format("%c", CMD_SETPARAM | REG_KVAL_RUN));
	    write(format("%c", (val & 0xff)));
	}
	
	function getRunKval() {
	    write(format("%c", CMD_GETPARAM | REG_KVAL_RUN));
	    write(format("%c", (val & 0xff)));
	}
	
	function setAccKval(val) {
	    write(format("%c", CMD_SETPARAM | REG_KVAL_ACC));
	    write(format("%c", (val & 0xff)));
	}
	
	function getAccKval() {
	    write(format("%c", CMD_GETPARAM | REG_KVAL_ACC));
	    write(format("%c", (val & 0xff)));
	}	
	
	function setDecKval(val) {
	    write(format("%c", CMD_SETPARAM | REG_KVAL_DEC));
	    write(format("%c", (val & 0xff)));
	}
	
	function getDecKval() {
	    write(format("%c", CMD_GETPARAM | REG_KVAL_DEC));
	    write(format("%c", (val & 0xff)));
	}
	
	function setAbsPos(pos) {
        write(format("%c%c", CMD_SETPARAM | REG_ABS_POS, pos & 0xff));
	}
	
	function getAbsPos() {
	    write(format("%c", CMD_GETPARAM | REG_ABS_POS));
	    return read(1);
	}
	
	function setElPos(pos) {
        write(format("%c%c", CMD_SETPARAM | REG_EL_POS, pos & 0xff));
	}
	
	function getElPos() {
	    write(format("%c", CMD_GETPARAM | REG_EL_POS));
	    return read(1);
	}
	
	function setMark(pos) {
        write(format("%c%c", CMD_SETPARAM | REG_MARK, pos & 0xff));
	}
	
	function getMark() {
	    write(format("%c", CMD_GETPARAM | REG_MARK));
	    return read(1);
	}
	
	function hardHiZ() {
	    write(format("%c", CMD_HARD_HIZ));
	}
	
	function softHiZ() {
	    write(format("%c", CMD_SOFT_HIZ));
	}
	
	function run(fwd = true, speed = 0) {
	    local cmd = CMD_RUN;
	    if (fwd) { cmd = CMD_RUN | 0x01; }
	    if (speed == 0) { speed = fs_speed; }
	    write(format("%c%c%c%c", cmd, speed & 0xff, (speed & 0xff00) >> 8, (speed & 0xff0000) >> 16));
	}
	
	function stop() {
	    write(format("%c", CMD_SOFT_STOP));
	}
}

// Runtime Begins -------------------------------------------------------------
imp.enableblinkup(true);

spi <- hardware.spi189;
cs_l <- hardware.pin2;
rst_l <- hardware.pin5;
flag_l <- hardware.pin7;

spi.configure(MSB_FIRST, SPICLK);
cs_l.configure(DIGITAL_OUT);
rst_l.configure(DIGITAL_OUT);
flag_l.configure(DIGITAL_IN);

motor <- L6470(spi, cs_l, rst_l, flag_l);

motor.setStepMode(STEP_SEL_1_64); // sync disabled, pwm divisor 1, pwm multiplier 2
motor.setMaxSpeed(STEPS_PER_REV); // steps per sec
motor.setFSSpeed(STEPS_PER_REV); // steps per sec
motor.setAcc(0x0fff); // max
motor.setOcTh(6000); // 6A
motor.setConfig(CONFIG_INT_OSC | CONFIG_PWMMULT_2_000);
motor.setRunKval(0xff); // set Vs divisor to 1

server.log(format("Status Register: 0x%04x", motor.getStatus()));
server.log(format("Config Register: 0x%04x", motor.getConfig()));

motor.run();
imp.wakeup(3, function() {
    motor.stop();
});