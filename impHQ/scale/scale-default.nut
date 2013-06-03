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

// Weighmax Kitchen Scale Firmware
// T. Buttner
// 12/14/12

// default raw tare value
local tareValue = 23825;
// number of samples to take per reading. Averaged.
local windowSize = 1500;
// number of ADC bins per ounce (measured)
local scaleFactorOz = 50.0;

local weight_out = OutputPort("Weight");

function readCell() {
    // Take a pile of readings and average them
    local sum = 0;
    local result = 0;
    
    for (local i = 0; i < windowSize; i++) {
        sum += hardware.pin2.read();
    }
    result = sum / windowSize;
    
    return result;
}

function readWeight() {
    local weight = (readCell() - tareValue) * (1.0 / scaleFactorOz);
    weight_out.set(format("%0.1f",weight));
    server.show(format("%0.1f oz",weight));
    
    imp.wakeup(1.0, readWeight);
}

function tare() {
    server.log("Setting Tare Value");
    tareValue = readCell();
}

function checkForSleep() {
    if (hardware.pin1.read() == 0) {
        server.log("Going to sleep");
        // sleep on idle - server.sleepuntil puts the imp to sleep *immediately*, so this is better
        imp.onidle(goToSleep());
    }
}

function goToSleep() {
    // wake once a day just to check in. Not vital. Wake-up pin will override and wake imp.
    server.sleepuntil(0.0,0.0);
}

// Ports 
local outWeight = OutputPort("Weight");

// Configuring pins
hardware.pin1.configure(DIGITAL_IN_WAKEUP, checkForSleep);
hardware.pin5.configure(DIGITAL_IN, tare);
hardware.pin2.configure(ANALOG_IN);

// WiFi Powersave
imp.setpowersave(true);

server.log("Hardware Configured");

imp.configure("Impee Scale", [], [weight_out]);

tare();
readWeight();