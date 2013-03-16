// April with pushbutton switch and LED

/* output port sends boolean indicating pushbutton state
 * input port drives LED - send 1 to turn LED On
 *
 * T. Buttner 10/23/12
 */
 
/* Pin Assignments
 * Pin 9 = LED sink
 * Pin 7 = momentary pushbutton switch
 */
 
// Configure hardware

// pin 9 sinks current from the LED and should be off unless driven low,
// so we configure in open drain with an internal pull-up
hardware.pin9.configure(DIGITAL_OUT_OD_PULLUP);
// pulled up, but we drive it high anyway (LED Off)
hardware.pin9.write(1);

// pin 7 is a digital input (0 or 1) and we want it to be driven high unless we push the button to drive it low
// again, use an internal pull-up
hardware.pin7.configure(DIGITAL_IN_PULLUP);

server.log("Hardware Configured");

// create an output port to output the signal from our pushbutton switch
local out_button = OutputPort("button");

function checkButton() {
    local buttonState = hardware.pin7.read();
    // if buttonState is 0, the button is pushed, so set the output port to 1
    //server.log(format("buttonState = %d", buttonState));
    if (buttonState == 0) {
        server.log("Button Pressed, sending 1!");
        out_button.set(1);
    } else {
        out_button.set(0);
    }
    
    // schedule us to wake up and run this function again.
    // first parameter: time in seconds til next wakeup. Use a floating-point number (i.e. "1.0")
    // second parameter: name of the function to run when we wake back up
    imp.wakeup(0.25, checkButton);
}

class onOffLED extends InputPort
{
    name = "LED On/Off"
    type = "number"
    
    function set(value) {
        if (value != 0) {
            // LED On
            server.log("Received 1! Setting LED On!");
            hardware.pin9.write(0);
        } else {
            // LED Off
            hardware.pin9.write(1);
        }
    }

}

server.log("April 'Detonator' Started");
// imp.configure registers us with the Imp Service
// The first parameter Sets the text shown on the top line of the node in the planner - i.e., what this node is
// The second parameter is a list of input ports in square brackets
// The third parameter is a list of output ports in square brackets
imp.configure("April 'Detonator'", [ onOffLED() ], [out_button]);

// call our checkButton function from above
// note that at the end of checkButton, we use imp.wakeup to schedule the next run of the checkButton function
// this is a common structure in imp software - set up a function to periodically take care of business, and have it schedule its own next run
checkButton();

//EOF