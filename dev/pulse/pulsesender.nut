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

imp.configure("Pulse Sender",[],[]);

// width of full double-pulse in ms
const DURATION = 50;

pin <- hardware.pin2;
pin.configure(DIGITAL_OUT);
pin.write(0);

// take in a pulse length in ms and fire the pulse
function sendPulse(len) {
    server.log("Device: sending "+len+" ms pulse");
    local delay = len/1000.0;
    pin.write(1);
    imp.sleep(len/1000.0);
    pin.write(0);
}

// takes in the length of the first pulse and the gap between pulses.
// Total duration is always set to DURATION
function sendDoublePulse(pulse1, gap) {
    server.log("Device: sending double pulse, "+gap+" ms gap at "+pulse1+" ms.");
    local pulse1 = pulse1/1000.0;
    local gap = gap/1000.0;
    local pulse2 = (DURATION/1000.0) - pulse1 - gap;
    pin.write(1);
    imp.sleep(pulse1);
    pin.write(0);
    imp.sleep(gap);
    pin.write(1);
    imp.sleep(pulse2);
    pin.write(0);
    server.log("Done.");
}

agent.on("pulse", function(len) {
    sendPulse(len);
});

agent.on("doublepulse", function(params) {
    sendDoublePulse(params.len,params.gap);
});

// test loop
// loop through gap sizes from 50 to 0 ms long, 1 ms step
for (local i = 50; i > 0; i--) {
    // loop through first-pulse widths from 0 to 50 ms, 1 ms step
    for (local j = 50; j > 0; j--) {
        sendDoublePulse(j,i);
    }
}

sendDoublePulse(10,10);