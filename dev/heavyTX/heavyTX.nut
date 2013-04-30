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