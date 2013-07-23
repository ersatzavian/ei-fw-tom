/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/* 
 * Tom Buttner
 * tom@electricimp.com
 */

/* Globals and Constants ----------------------------------------------------*/
// button polling interval
const BTNINTERVAL 			= 0.15;
// temp measurement interval;
const TMPINTERVAL 			= 60.0;
// IR Record buffer size & recording parameters
const BUFFERSIZE  			= 4096;
const SAMPLERATE			= 16000;

// IR Code transmit times in microseconds
const START_TIME_HIGH 		= 4500;
const START_TIME_LOW		= 4500;
const PULSE_TIME 			= 600;
const TIME_LOW_1			= 1700;
const TIME_LOW_0			= 600;
const THRESH_0				= 1000;
const THRESH_1				= 2000;

// IR Receive Timeouts
const IR_RX_DONE			= 6000; // us
const IR_RX_TIMEOUT 		= 1000; // ms

// Time between decodes in seconds
const IR_RX_DISABLE			= 0.2500;
// Vishay IR RX part is active-low
const IR_IDLE_STATE			= 1;

/* Class and Function Definitions -------------------------------------------*/

/*
 * simple NTC thermistor
 *
 * Assumes thermistor is the high side of a resistive divider.
 * Low-side resistor is of the same nominal resistance as the thermistor
 */
class thermistor {

	// thermistor constants are shown on your thermistor datasheet
	// beta value (for the temp range your device will operate in)
	b_therm 		= null;
	t0_therm 		= null;
	// nominal resistance of the thermistor at room temperature
	r0_therm		= null;

	// analog input pin
	p_therm 		= null;
	points_per_read = null;

	constructor(pin, b, t0, r, points = 10) {
		this.p_therm = pin;
		this.p_therm.configure(ANALOG_IN);

		// force all of these values to floats in case they come in as integers
		this.b_therm = b * 1.0;
		this.t0_therm = t0 * 1.0;
		this.r0_therm = r * 1.0;
		this.points_per_read = points * 1.0;
	}

	// read thermistor in Kelvin
	function read() {
		local vdda_raw = 0;
		local vtherm_raw = 0;
		for (local i = 0; i < points_per_read; i++) {
			vdda_raw += hardware.voltage();
			vtherm_raw += p_therm.read();
		}
		local vdda = (vdda_raw / points_per_read);
		local v_therm = (vtherm_raw / points_per_read) * (vdda / 65535.0);
		local r_therm = r0_therm / ( (vdda / v_therm) - 1 );
		local ln_therm = math.log(r0_therm / r_therm);
		local t_therm = (t0_therm * b_therm) / (b_therm - t0_therm * ln_therm);
		return t_therm;
	}

	// read thermistor in Celsius
	function read_c() {
		return this.read() - 273.15;
	}

	// read thermistor in Fahrenheit
	function read_f() {
		local temp = this.read() - 273.15;
		return (temp * 9.0 / 5.0 + 32.0);
	}
}

/*
 * TMP112 Digital Temperature Sensor
 * 
 * Communicates via I2C
 * http://www.ti.com/lit/ds/symlink/tmp112.pdf
 *
 */
class tmp112 {
	// static values (address offsets)
	static TEMP_REG 		= 0x00;
	static CONF_REG 		= 0x01;
	static T_LOW_REG		= 0x02;
	static T_HIGH_REG		= 0x03;
	// Send this value on general-call address (0x00) to reset device
	static RESET_VAL 		= 0x06;
	// ADC resolution in degrees C
	static DEG_PER_COUNT 	= 0.0625;

	// i2c address
	addr 	= null;
	// i2c bus (passed into constructor)
	i2c		= null;
	// interrupt pin (configurable)
	int_pin = null;
	// configuration register value
	conf 	= null;

	// Default temp thresholds
	T_LOW 	= 75; // Celsius
	T_HIGH 	= 80; 

	// Default mode
	EXTENDEDMODE 	= false;
	SHUTDOWN 		= false;

	// conversion ready flag
	CONV_READY 		= false;

	// interrupt state - some pins require us to poll the interrupt pin
	LAST_INT_STATE 	= null;
	POLL_INTERVAL 	= null;
	INT_CALLBACK 	= null;

	// generic temp interrupt
	function tmp112_int(state) {
		server.log("Device: TMP112 Interrupt Occurred. State = "+state);
	}

	/*
	 * Class Constructor. Takes 3 to 5 arguments:
	 * 		_i2c: 					Pre-configured I2C Bus
	 *		_addr:  				I2C Slave Address for device. 8-bit address.
	 * 		_int_pin: 				Pin to which ALERT line is connected
	 * 		_alert_poll_interval: 	Interval (in seconds) at which to poll the ALERT pin (optional)
	 *		_alert_callback: 		Callback to call on ALERT pin state changes (optional)
	 */
	constructor(_i2c, _addr, _int_pin, _alert_poll_interval = 1, _alert_callback = null) {
		this.addr = _addr;
		this.i2c = _i2c;
		this.int_pin = _int_pin;

		/* 
		 * Top-level program should pass in Pre-configured I2C bus.
		 * This is done to allow multiple devices to be constructed on the bus
		 * without reconfiguring the bus with each instantiation and causing conflict.
		 */
		//this.i2c.configure(CLOCK_SPEED_100_KHZ);
		this.int_pin.configure(DIGITAL_IN);
		LAST_INT_STATE = this.int_pin.read();
		POLL_INTERVAL = _alert_poll_interval;
		if (_alert_callback) {
			INT_CALLBACK = _alert_callback;
		} else {
			INT_CALLBACK = this.tmp112_int;
		}
		read_conf();
	}

	/* 
	 * Check for state changes on the ALERT pin.
	 *
	 * Not all imp pins allow state-change callbacks, so ALERT pin interrupts are implemented with polling
	 *
	 */ 
	function poll_interrupt() {
		imp.wakeup(POLL_INTERVAL, poll_interrupt);
		local int_state = int_pin.read();
		if (int_state != LAST_INT_STATE) {
			LAST_INT_STATE = int_state;
			INT_CALLBACK(state);
		}
	}

	/* 
	 * Take the 2's complement of a value
	 * 
	 * Required for Temp Registers
	 *
	 * Input:
	 * 		value: number to take the 2's complement of 
	 * 		mask:  mask to select which bits should be complemented
	 *
	 * Return:
	 * 		The 2's complement of the original value masked with the mask
	 */
	function twos_comp(value, mask) {
		value = ~(value & mask) + 1;
		return value & mask;
	}

	/* 
	 * General-call Reset.
	 * Note that this may reset other devices on an i2c bus. 
	 *
	 * Logging is included to prevent this from silently affecting other devices
	 */
	function reset() {
		server.log("TMP112 Class issuing General-Call Reset on I2C Bus.");
		i2c.write(0x00,format("%c",RESET_VAL));
		// update the configuration register
		read_conf();
		// reset the thresholds
		T_LOW = 75;
		T_HIGH = 80;
	}

	/* 
	 * Read the TMP112 Configuration Register
	 * This updates several class variables:
	 *  - EXTENDEDMODE (determines if the device is in 13-bit extended mode)
	 *  - SHUTDOWN 	   (determines if the device is in low power shutdown mode / one-shot mode)
	 * 	- CONV_READY   (determines if the device is done with last conversion, if in one-shot mode)
	 */
	function read_conf() {
		conf = i2c.read(addr,format("%c",CONF_REG), 2);
		// Extended Mode
		if (conf[1] & 0x10) {
			EXTENDEDMODE = true;
		} else {
			EXTENDEDMODE = false;
		}
		if (conf[0] & 0x01) {
			SHUTDOWN = true;
		} else {
			SHUTDOWN = false;	
		}
		if (conf[1] & 0x10) {
			CONV_READY = true;
		} else {
			CONV_READY = false;
		}
	}

	/*
	 * Read, parse and log the current state of each field in the configuration register
	 *
	 */
	function print_conf() {
		conf = i2c.read(addr,format("%c",CONF_REG), 2);
		server.log(format("TMP112 Conf Reg at 0x%02x: %02x%02x",addr,conf[0],conf[1]));
		
		// Extended Mode
		if (conf[1] & 0x10) {
			server.log("TMP112 Extended Mode Enabled.");
		} else {
			server.log("TMP112 Extended Mode Disabled.");
		}

		// Shutdown Mode
		if (conf[0] & 0x01) {
			server.log("TMP112 Shutdown Enabled.");
		} 
		else {
			server.log("TMP112 Shutdown Disabled.");
		}

		// One-shot Bit (Only care in shutdown mode)
		if (conf[0] & 0x80) {
			server.log("TMP112 One-shot Bit Set.");
		} else {
			server.log("TMP112 One-shot Bit Not Set.");
		}

		// Thermostat or Comparator Mode
		if (conf[0] & 0x02) {
			server.log("TMP112 in Interrupt Mode.");
		} else {
			server.log("TMP112 in Comparator Mode.");
		}

		// Alert Polarity
		if (conf[0] & 0x04) {
			server.log("TMP112 Alert Pin Polarity Active-High.");
		} else {
			server.log("TMP112 Alert Pin Polarity Active-Low.");
		}

		// Alert Pin
		if (int_pin.read()) {
			if (conf[0] & 0x04) {
				server.log("TMP112 Alert Pin Asserted.");
			} else {
				server.log("TMP112 Alert Pin Not Asserted.");
			}
		} else {
			if (conf[0] & 0x04) {
				server.log("TMP112 Alert Pin Not Asserted.");
			} else {
				server.log("TMP112 Alert Pin Asserted.");
			}
		}

		// Alert Bit
		if (conf[1] & 0x20) {
			server.log("TMP112 Alert Bit  1");
		} else {
			server.log("TMP112 Alert Bit: 0");
		}

		// Conversion Rate
		local cr = (conf[1] & 0xC0) >> 6;
		switch (cr) {
			case 0:
				server.log("TMP112 Conversion Rate Set to 0.25 Hz.");
				break;
			case 1:
				server.log("TMP112 Conversion Rate Set to 1 Hz.");
				break;
			case 2:
				server.log("TMP112 Conversion Rate Set to 4 Hz.");
				break;
			case 3:
				server.log("TMP112 Conversion Rate Set to 8 Hz.");
				break;
			default:
				server.error("TMP112 Conversion Rate Invalid: "+format("0x%02x",cr));
		}

		// Fault Queue
		local fq = (conf[0] & 0x18) >> 3;
		server.log(format("TMP112 Fault Queue shows %d Consecutive Fault(s).", fq));
	}

	/* 
	 * Enter or exit low-power shutdown mode
	 * In shutdown mode, device does one-shot conversions
	 * 
	 * Device comes up with shutdown disabled by default (in continuous-conversion/thermostat mode)
	 * 
	 * Input: 
	 * 		State (bool): true to enable shutdown/one-shot mode.
	 */
	function shutdown(state) {
		read_conf();
		local new_conf = 0;
		if (state) {
			new_conf = ((conf[0] | 0x01) << 8) + conf[1];
		} else {
			new_conf = ((conf[0] & 0xFE) << 8) + conf[1];
		}
		i2c.write(addr, format("%c%c%c",CONF_REG,(new_conf & 0xFF00) >> 8,(new_conf & 0xFF)));
		// read_conf() updates the variables for shutdown and extended modes
		read_conf();
	}

	/* 
	 * Enter or exit 13-bit extended mode
	 *
	 * Input:
	 * 		State (bool): true to enable 13-bit extended mode
	 */
	function set_extendedmode(state) {
		read_conf();
		local new_conf = 0;
		if (state) {
			new_conf = ((conf[0] << 8) + (conf[1] | 0x10));
		} else {
			new_conf = ((conf[0] << 8) + (conf[1] & 0xEF));
		}
		i2c.write(addr, format("%c%c%c",CONF_REG,(new_conf & 0xFF00) >> 8,(new_conf & 0xFF)));
		read_conf();
	}

	/*
	 * Set the T_low threshold register
	 * This value is used to determine the state of the ALERT pin when the device is in thermostat mode
	 * 
	 * Input: 
	 * 		t_low: new threshold register value in degrees Celsius
	 *
	 */
	function set_t_low(t_low) {
		t_low = (t_low / DEG_PER_COUNT).tointeger();
		local mask = 0x0FFF;
		if (EXTENDEDMODE) {
			mask = 0x1FFF;
			if (t_low < 0) {
				twos_comp(t_low, mask);
			}
			t_low = (t_low & mask) << 3;
		} else {
			if (t_low < 0) {
				twos_comp(t_low, mask);
			}
			t_low = (t_low & mask) << 4;
		}
		server.log(format("set_t_low setting register to 0x%04x (%d)",t_low,t_low));
		i2c.write(addr, format("%c%c%c",T_LOW_REG,(t_low & 0xFF00) >> 8, (t_low & 0xFF)));
		T_LOW = t_low;
	}

	/*
	 * Set the T_high threshold register
	 * This value is used to determine the state of the ALERT pin when the device is in thermostat mode
	 * 
	 * Input:
	 *		t_high: new threshold register value in degrees Celsius
	 *
	 */
	function set_t_high(t_high) {
		t_high = (t_high / DEG_PER_COUNT).tointeger();
		local mask = 0x0FFF;
		if (EXTENDEDMODE) {
			mask = 0x1FFF;
			if (t_high < 0) {
				twos_comp(t_high, mask);
			}
			t_high = (t_high & mask) << 3;
		} else {
			if (t_high < 0) {
				twos_comp(t_high, mask);
			}
			t_high = (t_high & mask) << 4;
		}
		server.log(format("set_t_high setting register to 0x%04x (%d)",t_high,t_high));
		i2c.write(addr, format("%c%c%c",T_HIGH_REG,(t_high & 0xFF00) >> 8, (t_high & 0xFF)));
		T_HIGH = t_high;
	}

	/* 
	 * Read the current value of the T_low threshold register
	 *
	 * Return: value of register in degrees Celsius
	 */
	function get_t_low() {
		local result = i2c.read(addr, format("%c",T_LOW_REG), 2);
		local t_low = (result[0] << 8) + result[1];
		//server.log(format("get_t_low got: 0x%04x (%d)",t_low,t_low));
		local mask = 0x0FFF;
		local sign_mask = 0x0800;
		local offset = 4;
		if (EXTENDEDMODE) {
			//server.log("get_t_low: TMP112 in extended mode.")
			sign_mask = 0x1000;
			mask = 0x1FFF;
			offset = 3;
		}
		t_low = (t_low >> offset) & mask;
		if (t_low & sign_mask) {
			//server.log("get_t_low: Tlow is negative.");
			t_low = -1.0 * (twos_comp(t_low,mask));
		}
		//server.log(format("get_t_low: raw value is 0x%04x (%d)",t_low,t_low));
		T_LOW = (t_low.tofloat() * DEG_PER_COUNT);
		return T_LOW;
	}

	/*
	 * Read the current value of the T_high threshold register
	 *
	 * Return: value of register in degrees Celsius
	 */
	function get_t_high() {
		local result = i2c.read(addr, format("%c",T_HIGH_REG), 2);
		local t_high = (result[0] << 8) + result[1];
		local mask = 0x0FFF;
		local sign_mask = 0x0800;
		local offset = 4;
		if (EXTENDEDMODE) {
			sign_mask = 0x1000;
			mask = 0x1FFF;
			offset = 3;
		}
		t_high = (t_high >> offset) & mask;
		if (t_high & sign_mask) {
			t_high = -1.0 * (twos_comp(t_high,mask));
		}
		T_HIGH = (t_high.tofloat() * DEG_PER_COUNT);
		return T_HIGH;
	}

	/* 
	 * If the TMP112 is in shutdown mode, write the one-shot bit in the configuration register
	 * This starts a conversion. 
	 * Conversions are done in 26 ms (typ.)
	 *
	 */
	function start_conversion() {
		read_conf();
		local new_conf = 0;
		new_conf = ((conf[0] | 0x80) << 8) + conf[1];
		i2c.write(addr, format("%c%c%c",CONF_REG,(new_conf & 0xFF00) >> 8,(new_conf & 0xFF)));
	}

	/*
	 * Read the temperature from the TMP112 Sensor
	 * 
	 * Returns: current temperature in degrees Celsius
	 */
	function read_c() {
		if (SHUTDOWN) {
			start_conversion();
			CONV_READY = false;
			local timeout = 30; // timeout in milliseconds
			local start = hardware.millis();
			while (!CONF_READY) {
				if ((hardware.millis() - start) > timeout) {
					server.error("Device: TMP112 Timed Out waiting for conversion.");
					return 0;
				}
			}
		}
		local result = i2c.read(addr, format("%c", TEMP_REG), 2);
		local temp = (result[0] << 8) + result[1];

		local mask = 0x0FFF;
		local sign_mask = 0x0800;
		local offset = 4;
		if (EXTENDEDMODE) {
			mask = 0x1FFF;
			sign_mask = 0x1000;
			offset = 3;
		}

		temp = (temp >> offset) & mask;
		if (temp & sign_mask) {
			temp = -1.0 * (twos_comp(temp, mask));
		}

		return temp * DEG_PER_COUNT;
	}

	/* 
	 * Read the temperature from the TMP112 Sensor and convert
	 * 
	 * Returns: current temperature in degrees Fahrenheit
	 */
	function read_f() {
		return (read_c() * 9.0 / 5.0 + 32.0);
	}
}

/* 
 * Send an IR Code over the IR LED 
 * 
 * Input: 
 * 		IR Code (string). Each bit is represented by a literal character in the string.
 *			Example: "111000001110000001000000101111111"
 * 			Both states are represented by a fixed-width pulse, followed by a low time which varies to 
 * 			indicate the state. 
 *
 * Return:
 * 		None
 */
function send_IR_code (code) {
	server.log("Sending Code, len = "+code.len());
	// make sure pwm carrier is disabled
	pwm.write(0.0);
	local clkrate = 1000.0 * spi.configure(0,234);
	local bytetime = 8 * (1.0/clkrate);
	server.log(format("Clock Rate %d, Byte Time %.6f",clkrate, bytetime));

	// calculate the number of bytes we need to send each signal
	local start_bytes_high = (START_TIME_HIGH / bytetime).tointeger();
	local start_bytes_low =  (START_TIME_LOW / bytetime).tointeger();
	local pulse_bytes = (PULSE_TIME / bytetime).tointeger();
	local bytes_1 = (TIME_LOW_1 / bytetime).tointeger();
	local bytes_0 = (TIME_LOW_0 / bytetime).tointeger();
	server.log(format("%d pulse bytes, %d ON bytes, %d OFF bytes",pulse_bytes, bytes_1, bytes_0));

	local code_blob = blob(pulse_bytes); // blob will grow as it is written

	// Write the start sequence into the blob
	for (local i = 0; i < start_bytes_high; i++) {
		code_blob.writen(0xFF, 'b');
	}
	for (local i = 0; i < start_bytes_low; i++) {
		code_blob.writen(0x00, 'b');
	}

	// now encode each bit in the code
	foreach (bit in code) {
		//server.log(bit);
		// this will be set when we figure out if this bit in the code is high or low
		local low_bytes = 0;
		// first, encode the pulse (same for both states)aa
		for (local j = 0; j < pulse_bytes; j++) {
			code_blob.writen(0xFF,'b');
		}

		// now, figure out if the bit is high or low
		// ascii code for "1" is 49 ("0" is 48)
		if (bit == 49) {
			//server.log("Encoding 1");
			low_bytes = bytes_1;
		} else {
			//server.log("Encoding 0");
			low_bytes = bytes_0;
		}

		// write the correct number of low bytes to the blob, then check the next bit
		for (local k = 0; k < low_bytes; k++) {
			code_blob.writen(0x00,'b');
		}
	}
		
	// the code is now written into the blob. Time to send it. 

	// enable PWM carrier
	pwm.write(0.5);

	// send code four times
	for (local i = 0; i < 4; i++) {
		spi.write(code_blob);
		spi.write("\x00");
		imp.sleep(0.046);
	}
	
	// disable pwm carrier
	pwm.write(0.0);
	server.log("Sent Codes to TV.");
	// clear the SPI lines
	spi.write("\x00");
}

function samplesReady(buffer,length) {
	if (length > 0) {
		agent.send("irdata",buffer); 
	} else {
		server.log("Device: Buffer Overrun.");
	}
}

function stopSampler() {
	server.log("Device: Stopping IR Recording.");
	hardware.sampler.stop();

	// reconfigure sampler to reclaim buffer memory
	hardware.sampler.configure(hardware.pin2, SAMPLERATE,
		[blob(2)], samplesReady);

	agent.send("irdatadone",0);
}

function recordIR() {
	hardware.sampler.configure(hardware.pin2,SAMPLERATE,
		[blob(BUFFERSIZE),blob(BUFFERSIZE),blob(BUFFERSIZE)],
		samplesReady);

	imp.wakeup(10.0, stopSampler);
	
	hardware.sampler.start();

	server.log("Device: IR Recording.");
}

function ir_rx() {
	//server.log("IR RX Callback Active.");
	local newcode = "";
	local last_state = hardware.pin2.read();
	local duration = 0;
	local durations = "durations:\n";

	local bit = 0;

	local start = hardware.millis();
	local last_change_time = hardware.micros();

	local state = 0;
	local now = start;

	while (1) {

		// waiting for pin to change state
		state = hardware.pin2.read();
		now = hardware.micros();

		if (state == last_state) {
			// last state change was over IR_RX_DONE ago; we're done with code; quit.
			if ((now - last_change_time) > IR_RX_DONE) {
				break;
			} else {
				continue;
			}
		}

		// check and see if the variable (low) portion of the pulse has just ended
		if (state != IR_IDLE_STATE) {
			// the low time just ended. Measure it and add to the code string
			duration = now - last_change_time;
			if (duration < THRESH_0) {
				// this is a 0
				newcode += "0";
			} else if (duration < THRESH_1) {
				// this is a 1;
				newcode += "1";
			} else {
				// this was the start pulse; ignore
			}
		}

		last_state = state;
		last_change_time = now;

		// if we're here, we're currently measuring the low time of a pulse
		// just wait for the next state change and we'll tally it up
	}

	// codes have to end with a 1, effectively, because of how they're sent
	newcode += "1";

	// codes are sent multiple times, so disable the receiver briefly before re-enabling
	disable_ir_rx();
	imp.wakeup(IR_RX_DISABLE, enable_ir_rx);

	server.log("Got new IR Code ("+newcode.len()+"): "+newcode);
	agent.send("newcode", newcode);
}

function enable_ir_rx() {
	// re-configure pin with state change callback
	hardware.pin2.configure(DIGITAL_IN, ir_rx);
}

function disable_ir_rx() {
	// re-configure pin without state change callback
	hardware.pin2.configure(DIGITAL_IN);
}

function poll_btn() {
	imp.wakeup(BTNINTERVAL, poll_btn);
	if (btn.read()) {
		// button released
	} else {
		server.log("Button Pressed");
		recordIR();
	}
}

function temp_alert(state) {
	server.log("Temp Alert Occurred, state = "+state);
}

function poll_temp() {
	imp.wakeup(TMPINTERVAL, poll_temp);

	server.log(format("Thermistor Temp: %.1f K (%.1f C, %.1f F)", t_analog.read(), t_analog.read_c(), t_analog.read_f()));
	server.log(format("TMP112 Temp: %.2f C (%.2f F)",t_digital.read_c(),t_digital.read_f()));
}

/* AGENT CALLBACKS ----------------------------------------------------------*/

agent.on("send_code", function(code) {
	send_IR_code(code);
});

/* RUNTIME STARTS HERE ------------------------------------------------------*/

imp.configure("Sana",[],[]);
imp.enableblinkup(true);

// initialize SPI bus to send codes
spi <- hardware.spi257;
// SPI257 minimum clock rate is 234 kHz
server.log("SPI Running at "+spi.configure(0, 234)+" kHz");

// pwm carrier signal
pwm <- hardware.pin1;
pwm.configure(PWM_OUT, 1.0/38000.0, 0.0);
spi.configure(0,234);
spi.write("\x00");

// instantiate sensor classes
t_analog <- thermistor(hardware.pinA, 4250, 298.15, 10000.0, 2);
hardware.i2c89.configure(CLOCK_SPEED_100_KHZ);
t_digital <- tmp112(hardware.i2c89, 0x92, hardware.pinB, 1.0, temp_alert);
t_digital.reset();

btn <- hardware.pin6;
btn.configure(DIGITAL_IN_PULLUP);

// initialize the IR recieve pin to learn codes
hardware.pin2.configure(DIGITAL_IN, ir_rx);
server.log("Pin 2 resting at "+hardware.pin2.read());

imp.wakeup(1.0, function() {
	// start the temp polling loop
	poll_temp();

	// pin 6 doesn't support state change callbacks, so we have to poll
	poll_btn();
});

