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

/* Heavy TX Firmware
 * Sends large dummy blobs to the agent, which does nothing with them.
 * Also encourages user to move device so RSSI is below -80 dBm;
 	This forces thte device into 802.11b mode, with lower datarate and higher TX power
*/

// size of blobs to send to agent
const BLOBSIZE = 16384;
// interval between sends in seconds
const WAIT = 2.0;

imp.configure("Imp TX Tester",[],[]);

function sendBlob() {
	local myBlob = blob(BLOBSIZE);
	agent.send("data",myBlob);
}

function chkRssi() {
	local rssi = imp.rssi();
	if (rssi > -80) {
		server.log(format("RSSI TOO HIGH (%d dBm); MOVE AWAY FROM AP",rssi));
	} else {
		server.log(format("RSSI = %d dBm",rssi));
	}
}

function ping() {
	imp.wakeup(WAIT, ping);
	sendBlob();
	chkRssi();
}

ping();