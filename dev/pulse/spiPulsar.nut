// Device firmware to test wake pulses for the imp
// Uses SPI to send double-pulses
// Full double-pulse event has fixed duration
// The initial pulse width and gap between pulses are varied
// Each Test verifies that the partner imp actually woke and went back to sleep before trying the next combination. 

// length of blob used to send pulses (bytes)
// at 937 kHz, 6000 bytes ~ 50ms
const LENGTH = 6000;

// timeout waiting for partner to go to sleep before sending the next wake pulse (ms)
const SLEEPTIMEOUT = 500;
// timeout waiting for partner to wake up after sending wake pulse (s)
// this is from wake pulse to up-and-running-code, including wifi join
const WAKETIMEOUT = 30;

// flag for whether the partner imp woke after sending last pulse 
woke <- false;

// one-byte blob full of zeros used to make sure MOSI is low between pulses
clearBlob <- blob(1);
clearBlob.writen(0x00, 'b');

imp.configure("SPI Pulsar",[],[]);

spi <- hardware.spi257;
SPISPEED <- spi.configure(0, 1000);
BYTETIME <- 8.0/(SPISPEED*1000.0);

// byte offset to start of gap between pulses
// start with a gap of length 1 preventing the second pulse
pulseBlob <- blob(LENGTH);
bytesPerMs <- format("%d",0.001/BYTETIME).tointeger();
startGap <- LENGTH - bytesPerMs/20;
endGap <- LENGTH;

server.log("SPI Running at "+SPISPEED+" kHz");
server.log("Byte time = "+BYTETIME+" s");
server.log(bytesPerMs+" bytes per ms");

// partner imp toggles this pin when it wakes up
hardware.pin9.configure(DIGITAL_IN);

// ensure MOSI is low at end of a sequence
function clear() {
    spi.write(clearBlob);
}

// called when the partner imp wakes and toggles the indicator line
function wakeCallback() {
    if (hardware.pin9.read()) {
    	woke = true;
		server.log(format("PASS: %.4f ms first pulse, %.4f ms gap",startGap*BYTETIME*1000.0,(endGap - startGap)*BYTETIME*1000.0));

		// clear the state change callback
		hardware.pin9.configure(DIGITAL_IN);

		// update the start and end points for the gap for the next sequence
		if (endGap - startGap >= LENGTH) {
			server.log("TEST COMPLETE, PASSED ALL SEQUENCES");
			return;
		} else if (startGap <= bytesPerMs) {
			startGap = LENGTH - (endGap + bytesPerMs/20);
			endGap = LENGTH;
		} else {
			startGap -= bytesPerMs/20;
			endGap -= bytesPerMs/20;
		}
		
		// send the next wakeup pulse
		sendNextPulse();
	}
}

// callback to verify that the partner imp woke up 
function checkForWake() {
	if (!woke) {
		server.error("Partner failed to wake in "+WAKETIMEOUT+" s");
		server.error(format("Failure after %.2f ms first pulse, %.2f ms gap",startGap*BYTETIME*1000,(endGap - startGap)*BYTETIME*1000));
		return;
	} 
}

// send the next pulse in the test sequence
function sendNextPulse() {
    //server.log("Sending.");
	local start = hardware.millis();
	while (hardware.pin9.read()) {
        if ((hardware.millis() - start) > SLEEPTIMEOUT) {
            server.error("Partner failed to sleep in "+SLEEPTIMEOUT+" ms");
            server.error(format("Failure after %d ms first pulse, %d ms gap",startGap*BYTETIME,(endGap - startGap)*BYTETIME));
            return;
        }
    }
    pulseBlob.seek(0,'b');
	while (!pulseBlob.eos()) {
		if ((pulseBlob.tell() >= startGap) && (pulseBlob.tell() <= endGap)) {
			pulseBlob.writen(0x00, 'b');
		} else {
			pulseBlob.writen(0xFF, 'b');
		}
	}
	woke = false;
	hardware.pin9.configure(DIGITAL_IN, wakeCallback);
	//imp.wakeup(WAKETIMEOUT, checkForWake);
    spi.write(pulseBlob);
    clear();
    //server.log("Sent.")
}

sendNextPulse();
