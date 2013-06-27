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
	Long-battery-life tempbug
	
	Electric imp battery-powered thermometer.

	Wakes and gathers data every 10 minutes, but remains offline. Powers up wifi and logs
	readings every hour on the hour. 

	Hardware: April with a 10k, 1% from 3V3 to pin9 and 10k B57861S0103F040 NTC Thermistor from pin9 to pin8
	pin8 TEMP_READ_EN_L - drive low to enable temp reading
	pin9 ANALOG NTC value
*/

// all calculations are done in Kelvin
// these are constants for this particular thermistor; if using a different one,
// check your datasheet
const b_therm = 3988;
const t0_therm = 298.15;

// interval between temperature readings
const READINGPERIOD = 5.0;

// number of readings to collect before sending up
const MAXREADINGS = 2;

// timeout for wifi operations
const WIFITIMEOUT = 30.0

en_l <- hardware.pin8;
input <- hardware.pin9;

// Configure Pins
function configure() {
	// pin 8 is driven high to turn off temp monitor (saves power) or low to read
	en_l.configure(DIGITAL_OUT);
	en_l.write(1); 
	// pin 9 is the middle of the voltage divider formed by the NTC - read the analog voltage to determine temperature
	input.configure(ANALOG_IN);

	if (!("nv" in getroottable())) {
		nv <- {count = 0, data = []};
	} else {
		if (!("count" in nv)) {
			nv.count <- 0;
		}
		if (!("data" in nv)) {
			nv.data <- [];
		}
	}
}

// read the temperature from the NTC
function getTemp() {
	// turn on the thermistor network
	hardware.pin8.write(0);

	// to read the battery voltage and thermistor voltage reliably, we take 10 readings and average them
	local v_high  = 0;
	local val = 0;
	for(local i = 0; i < 10; i++){
    	v_high += hardware.voltage();
    	val += hardware.pin9.read();
	}
	v_high = v_high / 10.0;
	val = val / 10.0;

	// turn the thermistor network back off
	hardware.pin8.write(1);


	// scale the ADC reading to a voltage by dividing by the full-scale value and multiplying by the supply voltage
	local v_therm = v_high * val / 65535.0;
	// calculate the resistance of the thermistor at the current temperature
	local r_therm = 10000.0 / ( (v_high / v_therm) - 1);
	local ln_therm = math.log(10000.0 / r_therm);
	local t_therm = (t0_therm * b_therm) / (b_therm - t0_therm * ln_therm) - 273.15;

	return t_therm;
}

// clear the entries in the NVRAM table
function clearNV() {
	nv.count = 0;
	nv.data = [];
}

/* 
 * 	Wait for the imp to idle and then go to deep sleep for the specified time
 *	Note that Squirrel code is completely reloaded on each wake from deep sleep ("warm boot")
 *  
 *  Therefore, this firmware must handle the case that the imp has just warm booted at 
 *  the beginning of every run.
 */	
function goToSleepFor(sleeptime) {
	imp.onidle( function() {
		if (server.isconnected()) {
			server.expectonlinein(sleeptime);
		}
		imp.deepsleepfor(sleeptime)
	});
}

/*
 * 	Upload temperature reading data to the server
 * 
 * 	This function is used as an on-connected callback; server.connect calls it when a connection is established
 *
 * 	This function disconnects and sends the imp to deep sleep when the upload is complete
 */
function sendData(connectionStatus) {
    if (connectionStatus != SERVER_CONNECTED) {
        goToSleepFor(READINGPERIOD);
    }
	// since we've just connected, priority 1 is to register with the imp server
	imp.configure("TempBug Offline",[],[]);

	// now upload data to agent
	agent.send("data", nv.data);
	server.log("Device: sent data to agent");

	// having sent the data, it's time to clear the NV table
	clearNV();

	// disconnect and go to sleep until the next reading time
	// server.expectonlinein() incloudes an implicit server.disconnect
	// see http://devwiki.electricimp.com/doku.php?id=electricimpapi:server:expectonlinein
	server.expectonlinein(READINGPERIOD);
	goToSleepFor(READINGNPERIOD);
}

/*
 *	Send generic log messages
 *	
 *	This wrapper function for server.log exists to make sure that imp.configure is called first
 * 	Whenever wifi is forced up
 */
function log(message) {
	if (!server.isconnected()) {
		// block until connected 
		server.setsendtimeoutpolicy(SUSPEND_ON_ERROR, WAIT_TIL_SENT, WIFITIMEOUT);
	}
	imp.configure("TempBug Offline",[],[]);

	server.log(message);
}

/* RUNTIME BEGINS HERE ------------------------------------------------------*/

// Set the send timeout policy, which also configures the connection behavior
// Setting timeout to RETURN_ON_ERROR configures wifi to connect manually
// See full documentation: http://devwiki.electricimp.com/doku.php?id=electricimpapi:server:setsendtimeoutpolicy

// Note also that WAIT_TIL_SENT is the more commonly used wait behavior; using WAIT_FOR_ACK is
// 	recommended only when required.

wakereason <- hardware.wakereason();
switch(wakereason) {
	case WAKEREASON_POWER_ON: 
		// calling to server.log here will force up wifi. Since this case only happens on cold boot,
		// it's reasonable for this application to check in and say so to the server.
		// This also gives us the opportunity to call server.expectonlinein() on cold boot, so the imp is
		// marked as "asleep" instead of "offline"
		log("Imp Cold Booted");
		break;
	case WAKEREASON_SW_RESET:
		log("Imp SW Reset.");
		break;
	case WAKEREASON_TIMER:
		// this is what will happen most of the time; the imp takes a reading, sets a timer, goes to sleep,
		// and wakes up here. Do nothing!
		break;
	case WAKEREASON_PIN1:
		// this won't happen in this model
		break;
	case WAKEREASON_NEW_SQUIRREL:
		// we've just reloaded this model (or loaded it for the first time), and should take the same action
		// as on cold boot.
		//log("Imp got new squirrel.");
		break;
}

server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, WIFITIMEOUT);

configure();

// take a reading and push it into the nv table
nv.data.append([time(),getTemp()]);
nv.count++;

// if we've reached our desired number of readings, upload and clear the NV table
if (nv.count >= MAXREADINGS) {
	server.connect(sendData, WIFITIMEOUT);
} else {
	// go back to sleep until it's time for next reading
	goToSleepFor(READINGPERIOD);
}