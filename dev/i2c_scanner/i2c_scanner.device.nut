// Copyright (C) 2014 electric imp, inc.
//
// This device firmware tries all possible I2C slave address
// and logs the ones that respond. 
// Useful for listing devices on a bus, or double-checking an address.

const TESTBYTE 		= "\x00"; // dummy byte sent to each possible address
// these start and stop addresses are 8-bit addresses.
const STARTADDR 	= 0x00;
const STOPADDR 		= 0xfe; // scan all addresses from STARTADDR to STOPADDR, inclusive

local devicesfound = 0;

function ping(addr) {
	// if write returns nonzero, an error occurred (nobody home)
	if (i2c.write(addr, TESTBYTE) == 0) {
		server.log(format("Device present at 0x%02x",addr));
		devicesfound++;
	} 
}

i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);

server.log("Starting Scan.");
for (local addr = STARTADDR; addr <= STOPADDR; addr += 2) {
	ping(addr);
}
server.log(format("Scan complete, found %d devices.",devicesfound));