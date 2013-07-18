/* Root table access test */

const WAIT = 1;

imp.configure("Root table Access Test",[],[]);

server.log("MAC: "+imp.getmacaddress());
server.log("SW: "+imp.getsoftwareversion());

dummy <- "entry";

if ("dummy" in getroottable()) {
	server.log("Found dummy entry in root table before callback");
} else {
	server.log("Did not find dummy entry before callback");
}

function checkForDummy(val) {
	if ("dummy" in getroottable()) {
		server.log("found dummy entry in global table");
	} else {
		server.error("failed to find dummy entry in root table");
	}
}

agent.on("pong", checkForDummy);
// This also does not work
//agent.on("pong",checkForDummy.bindenv(this));

imp.sleep(WAIT);
agent.send("ping", 1);
