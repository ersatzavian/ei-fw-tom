// L6470 "dSPIN" stepper motor driver IC
// http://www.st.com/st-web-ui/static/active/en/resource/technical/document/datasheet/CD00255075.pdf

// Consts and Globals ---------------------------------------------------------
const SPICLK = 4000; // kHz

class L6470 {

	static CMD_NOP		 	= 0x00;
	static CMD_GOHOME		= 0x70;
	static CMD_GOMARK		= 0x78;
	static CMD_RESET_POS	= 0xD8;
	static CMD_RESET		= 0xC0;
	static CMD_RUN          = 0x50;
	static CMD_SOFT_STOP	= 0xB0;
	static CMD_HARD_STOP	= 0xB8;
	static CMD_SOFT_HIZ		= 0xA0;
	static CMD_HARD_HIZ		= 0xA8;
	static CMD_GETSTATUS	= 0xD0;	 
	static CMD_GETPARAM     = 0x20;
	static CMD_SETPARAM     = 0x00;

	static REG_ABS_POS 		= 0x01;
	static REG_EL_POS 		= 0x02;
	static REG_MARK			= 0x03;
	static REG_SPEED		= 0x04;
	static REG_ACC			= 0x05;
	static REG_DEC			= 0x06;
	static REG_MAX_SPD 		= 0x07;
	static REG_MIN_SPD 		= 0x08;
	static REG_KVAL_HOLD 	= 0x09;
	static REG_KVAL_RUN 	= 0x0A;
	static REG_KVAL_ACC 	= 0x0B;
	static REG_KVAL_DEC 	= 0x0C;
	static REG_INT_SPD		= 0x0D;
	static REG_ST_SLP		= 0x0E;
	static REG_FN_SLP_ACC	= 0x0F;
	static REG_FN_SLP_DEC	= 0x10;
	static REG_K_THERM		= 0x11;
	static REG_ADC_OUT		= 0x12;
	static REG_OC_TH		= 0x13;
	static REG_STALL_TH		= 0x13;
	static REG_STEP_MODE	= 0x14;
	static REG_FS_SPD		= 0x15;
	static REG_STEP_MODE 	= 0x16;
	static REG_ALARM_EN		= 0x17;
	static REG_CONFIG 		= 0x18;
	static REG_STATUS 		= 0x19;

	spi 	= null;
	cs_l 	= null;
	rst_l 	= null;
	flag_l	= null;
	
	fs_speed = null;

	function handleFlag() {
		if (!flag_l.read()) { server.log("L6470 set flag"); }
		server.log("L6470 unset flag");
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
	
	function getConfig() {
	    write(format("%c",CMD_GETPARAM | REG_CONFIG));
		return read(2);
	}
	
	function setConfig(val) {
	    write(format("%c", CMD_SETPARAM | REG_CONFIG));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	function setStepMode(val) {
	    write(format("%c", CMD_SETPARAM | REG_STEP_MODE));
	    write(format("%c", (val & 0xff)));
	}
	
	function setMaxSpd(stepsPerSec) {
	    local val = math.ceil(stepsPerSec * 0.065536).tointeger();
	    if (val > 0x03FF) { val = 0x03FF; }
	    write(format("%c", CMD_SETPARAM | REG_MAX_SPD));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	function setFSSpd(stepsPerSec) {
	    local val = math.ceil((stepsPerSec * 0x065536) - 0.5).tointeger();
	    if (val > 0x03FF) { val = 0x03FF; }
	    fs_speed = val;
	    write(format("%c", CMD_SETPARAM | REG_FS_SPD));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	function setAcc(stepsPerSecPerSec) {
	    local val = math.ceil(stepsPerSecPerSec * 0.137438).tointeger();
        if (val > 0x0FFF) { val = 0x0FFF; }
	    write(format("%c", CMD_SETPARAM | REG_ACC));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	function setOcTh(val) {
	    write(format("%c", CMD_SETPARAM | REG_OC_TH));
	    write(format("%c", (val & 0xff)));
	}
	
	function setRunKval(val) {
	    write(format("%c", CMD_SETPARAM | REG_KVAL_RUN));
	    write(format("%c", (val & 0xff)));
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
server.log(format("Status Register: 0x%04x", motor.getStatus()));
server.log(format("Config Register: 0x%04x", motor.getConfig()));

motor.setStepMode(0x04); // sync disabled, pwm divisor 1, pwm multiplier 2
motor.setMaxSpd(400); // steps per sec
motor.setFSSpd(50); // steps per sec
motor.setAcc(0x0fff); // max
motor.setOcTh(0x0f); // 6A
motor.setConfig(0x1c00);
motor.setRunKval(0xff);

server.log(format("Config Register: 0x%04x", motor.getConfig()));

motor.run();
server.log("motor running.");
server.log(format("Status Register: 0x%04x", motor.getStatus()));
imp.wakeup(3, function() {
    motor.stop();
    server.log(format("Status Register: 0x%04x", motor.getStatus()));
    server.log("motor stopped.");
});
