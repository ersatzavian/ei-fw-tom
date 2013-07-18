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

// April with potentiometer and brightness-controlled LED
 
/* Pin Assignments
 * Pin 9 = LED sink (configure for PWM)
 * Pin 8 = potentiometer wiper
 *
 * output port sends float from 0 to 1 showing potentiometer position
 * input port drives LED brightness
 *
 */
 
// Configure hardware

// pin 9 sinks current from the LED. When we set this pin low the LED will turn on.
// We can control apparent brightness by varying the duty cycle of a square wave sent to this pin (pulse-width modulation)
// Configure for PWM on pin 9. First parameter = pin mode
// Second parameter = period of PWM signal in seconds. Period = 1/frequency. 
// Third parameter = duty cycle. Floating-point number between 0.0 and 1.0, where 1.0 is on 100% duty cycle
// Note that we start with the LED off
hardware.pin9.configure(PWM_OUT, 1.0/500.0, 1.0);

// pin 8 is an analog input (we read the voltage on the pin with an ADC)
// analog inputs read a value between 0 (for 0 V) and 65,535 (16-bit ADC) for the imp's supply voltage, which should be 3.3V
hardware.pin8.configure(ANALOG_IN);
// you can read the imp's input voltage at any time with:
local voltage = hardware.voltage();
server.log(format("Running at %.2f V", voltage));
// we don't need to measure this because we've hooked the potentiometer up to the imp supply voltage

// We use this variable to create a "dead band" around the current value on the potentiometer
// this can be used to decrease the rate at which we push data to planner by discarding values that
// are the same as the last one
local lastRawValue = 0;

server.log("Hardware Configured");

// create an output port to output the signal from our pushbutton switch
local out_pot = OutputPort("potentiometer");

function checkPot() {
    local rawValue = hardware.pin8.read();
    if (math.abs(rawValue - lastRawValue) > 150) {
        local potValue = rawValue / 65535.0;
        lastRawValue = rawValue;
        // note that we divide by 65535.0 to get a value between 0.0 and 1.0
        // show the value on the planner
        server.show(potValue);
        // write the value to the logs
        server.log(potValue);
        // set the output port equal to the new value
        out_pot.set(potValue);
    }
    
    // schedule us to wake up and run this function again.
    // first parameter: time in seconds til next wakeup. Use a floating-point number (i.e. "1.0")
    // second parameter: name of the function to run when we wake back up
    imp.wakeup(0.1, checkPot);
}

class ledBrightness extends InputPort
{
    name = "LED Brightness"
    type = "number"
    
    function set(value) {
        server.log("Got new value: "+value);
        // since pin 9 is configured for PWM, we can set the duty cycle with pin.write()
        // write a floating point number between 0.0 and 1.0, where 1.0 = 100% duty cycle
        hardware.pin9.write(1.0-value);
    }

}

server.log("April Remote Brightness Controller Started");
// imp.configure registers us with the Imp Service
// The first parameter Sets the text shown on the top line of the node in the planner - i.e., what this node is
// The second parameter is a list of input ports in square brackets
// The third parameter is a list of output ports in square brackets
imp.configure("April Brightness Controller", [ ledBrightness() ], [out_pot]);

// call our checkPot function from above
// note that at the end of checkPot, we use imp.wakeup to schedule the next run of the checkSwitch function
// this is a common structure in imp software - set up a function to periodically take care of business, and have it schedule its own next run
checkPot();
