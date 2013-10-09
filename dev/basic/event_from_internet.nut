/* AGENT CODE ---------------------------------------------------------------*/

/* Define a handler for incoming HTTP requests */
http.onrequest(function(request, res) {
	
	server.log("Got new HTTP request");

	// read the body of the HTTP request into a local variable
	local data = request.body;

	// take action based on the contents of the request
	if (data) {
		// device.send takes two parameters: an event name and a value
		// the event name must be registered with a callback in the device firmware
		device.send("switch",1);
	} else {
		device.send("switch",0);
	}
	
	// send a response to the requester
	res.send(200, "OK");
});

/* DEVICE CODE --------------------------------------------------------------*/

// register with the imp service
imp.configure("Demo",[],[]);

// configure a pin as a digital output
hardware.pin1.configure(DIGITAL_OUT);
hardware.pin1.write(0); // initialize pin low

// register callback for events from the agent.
agent.on("switch", function(value) {
	if (value) {
		hardware.pin1.write(1);
	} else {
		hardware.pin1.write(0);
	}
});

server.log("Device ready.");