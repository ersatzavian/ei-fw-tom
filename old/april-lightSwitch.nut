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

// April with toggle switch and LED

/* output port sends boolean indicating switch state
 * input port drives LED - send 1 to turn LED On
 *
 * T. Buttner 10/23/12
 */
 
/* Pin Assignments
 * Pin 9 = LED sink
 * Pin 5 = toggle switch
 */
 
// Configure hardware

// pin 9 sinks current from the LED and should be off unless driven low,
// so we configure in open drain with an internal pull-up
hardware.pin9.configure(DIGITAL_OUT_OD_PULLUP);
// pulled up, but we drive it high anyway (LED Off)
hardware.pin9.write(1);

// pin 5 is a digital input (0 or 1) and we want it to be driven high unless we switch the switch to drive it low
// again, use an internal pull-up
hardware.pin5.configure(DIGITAL_IN_PULLUP);

server.log("Hardware Configured");

// create an output port to output the signal from our pushbutton switch
local out_switch = OutputPort("switch");

function checkSwitch() {
    local switchState = hardware.pin5.read();
    // if buttonState is 0, the button is pushed, so set the output port to 1
    if (switchState == 0) {
        server.show("On");
        out_switch.set(1);
    } else {
        server.show("Off");
        out_switch.set(0);
    }
    
    // schedule us to wake up and run this function again.
    // first parameter: time in seconds til next wakeup. Use a floating-point number (i.e. "1.0")
    // second parameter: name of the function to run when we wake back up
    imp.wakeup(0.5, checkSwitch);
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

server.log("April Remote Light Switch Started");
// imp.configure registers us with the Imp Service
// The first parameter Sets the text shown on the top line of the node in the planner - i.e., what this node is
// The second parameter is a list of input ports in square brackets
// The third parameter is a list of output ports in square brackets
imp.configure("April Remote Light Switch", [ onOffLED() ], [out_switch]);

// call our checkButton function from above
// note that at the end of checkButton, we use imp.wakeup to schedule the next run of the checkSwitch function
// this is a common structure in imp software - set up a function to periodically take care of business, and have it schedule its own next run
checkSwitch();

//EOF