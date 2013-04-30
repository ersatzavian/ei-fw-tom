// Heavy TX Agent
// Primarily a dummy agent so that the device is not sending data without a callback
// Also tracks total data sent

sentBytes <- 0;

server.log("Heavy TX Agent Started");

device.on("data", function(value) {
	sentBytes += value.len();
	server.log(format("Agent: RX Count = %d bytes",sentBytes));
});