/* Root table access test agent */

server.log("Test Agent Running");

device.on("ping", function(val) {
	server.log("Agent got ping from device");
	device.send("pong", 1);
});
