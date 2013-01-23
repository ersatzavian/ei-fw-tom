// UART Read Example

// configure a pin pair for UART TX/RX
hardware.uart12.configure(38400, 8, PARITY_NONE, 1, NO_CTSRTS);

function readSerial() {
    hardware.uart12.write(0x43);
    imp.sleep(0.1);
    local result = hardware.uart12.read();
    if (result == -1) {
    	server.show("No data returned.");
    } else {
    	server.show(result);
	}

	imp.wakeup(300, readSerial);
}

imp.configure("Serial RX", [], []);
readSerial();