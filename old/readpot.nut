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

// April with potentiometer 
 
// Configure hardware

// pin 8 is an analog input (we read the voltage on the pin with an ADC)
// analog inputs read a value between 0 (for 0 V) and 65,535 (16-bit ADC) for the imp's supply voltage, which should be 3.3V
hardware.pin8.configure(ANALOG_IN);

// you can read the imp's input voltage at any time with:
local voltage = hardware.voltage();
server.log(format("Running at %.2f V", voltage));

// We use this variable to create a "dead band" around the current value on the potentiometer
// this can be used to decrease the rate at which we push data to planner by discarding values that
// are the same as the last one
local lastRawValue = 0;

server.log("Hardware Configured");

function checkPot() {
    local rawValue = hardware.pin8.read();
    if (math.abs(rawValue - lastRawValue) > 150) {
        local potValue = rawValue / 65535.0;
        lastRawValue = rawValue;
        // note that we divide by 65535.0 to get a value between 0.0 and 1.0
        server.show(potValue);
        out_pot.set(potValue);
    }
    
    imp.wakeup(0.01, checkPot);
}

server.log("Potentiometer Started");
imp.configure("Potentiometer", [], []);
checkPot();

//EOF