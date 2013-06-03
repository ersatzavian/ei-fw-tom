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

// April with potentiometer and switch

/* Pin Assignments
 * Pin 8 = potentiometer wiper
 * Pin 7 = switch input
 *
 * switch output port sends true/false
 * brightness output port sends float from 0 to 1 showing potentiometer position
 *
 */
 
// Configure hardware

hardware.pin8.configure(ANALOG_IN);
hardware.pin7.configure(DIGITAL_IN_PULLUP);

server.log("Hardware Configured");

// create an output port to output the signal from our pushbutton switch
local out_pot = OutputPort("potentiometer");
local out_switch = OutputPort("switch");

local lastRawValue = 0;
local lastSwitchState = 2;

function checkInput() {
    
    local rawValue = hardware.pin8.read();
    // only update with the server if the current reading is markedly different from the last
    // cuts down on traffic and refresh rate, improves response time because we can use smaller delay in imp.wakeup
    if (math.abs(rawValue - lastRawValue) > 130) {
        local potValue = (hardware.pin8.read()) / 65535.0;
        // note that we divide by 65535.0 to get a value between 0.0 and 1.0
        server.show(potValue);
        out_pot.set(potValue);
        lastRawValue = rawValue; 
    }
    
    local switchState = hardware.pin7.read();
    if (switchState != lastSwitchState) {
        lastSwitchState = switchState;
        if (switchState == 0) {
            out_switch.set(1);
        } else {
            server.show("Off");
            out_switch.set(0);
        }        
    }
    
    imp.wakeup(0.05, checkInput);
}

server.log("April Control Center Started");

imp.configure("April Control Center", [], [out_pot, out_switch]);

checkInput();

//EOF