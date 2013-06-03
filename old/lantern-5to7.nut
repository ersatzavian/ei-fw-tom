/*
Copyright (C) 2012, 2013 electric imp, inc.

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

// Turn on Lantern from 5 to 7 PM
// 11/26/12

hardware.pin2.configure(DIGITAL_OUT);
imp.setpowersave(true);

server.log("Hardware Configured");

imp.configure("Lantern", [], []);


// light lantern at 5 PM
// Note that the imp takes the current time in GMT
local wakeAtHour = 1;
local wakeAtMinute = 0;
// turn lantern off at 7 PM
local sleepAtHour = 3;
local sleepAtMinute = 0;

local wakeAt = (60 * wakeAtHour) + wakeAtMinute;
local sleepAt = (60 * sleepAtHour) + sleepAtMinute

local currentTime = date(time(),'l');
server.log(format("Currently %d:%02d", currentTime.hour currentTime.min));
local currentMin = (currentTime.hour * 60) + currentTime.min;

if ((currentMin >= wakeAt) && (currentMin < sleepAt)) {
    // we're in the "on" time
    hardware.pin2.write(1);
    server.log(format("Lantern On at %d:%02d", currentTime.hour,currentTime.min));
    
    // now figure out how long to shallow sleep for before waking up to turn off the light
    local lightOnHours = (sleepAtHour - currentTime.hour - 1);
    if (lightOnHours < 0) {
        lightOnHours = 0;
    }
    local lightOnMinutes = ((sleepAtMinute - currentTime.min) + (60 * lightOnHours));
    server.log(format("Shallow sleeping for %d minutes", lightOnMinutes));
    imp.sleep(60.0 * lightOnMinutes);
} 

currentTime = date(time(),'l');
hardware.pin2.write(0);
server.log(format("Lantern Off at %d:%02d", currentTime.hour, currentTime.min));

// deep sleep until it's time to turn on the lantern
server.sleepuntil(wakeAtHour, wakeAtMinute);