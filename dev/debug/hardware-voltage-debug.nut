/* 
 * This code makes the imp fall over after about two logs.
 * 
 * Appears to be specific to hardware.voltage and depend on the number of times
 * that hardware.voltage is called in a loop.
 *
 */
const INTERVAL = 1.0;

/* Works only for counts less than ~20 */
const COUNTS = 20;

function poll_stuff() {
	imp.wakeup(INTERVAL, poll_stuff);

	local vdda_raw = 0;
	for (local i = 0; i < COUNTS; i++) {
//		vdda_raw = hardware.millis(); // Good
		vdda_raw = hardware.voltage(); // Bad
	}

	server.log("Still here");
}

imp.configure("Test",[],[]);
poll_stuff();
