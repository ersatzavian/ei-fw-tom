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

// Snack Dispenser
// Pin5 Motor Driver
// Pin7 Switch = Large
// Pin8 Switch = Medium
// Pin9 Switch = Small
imp.setpowersave(true);

motor  <- hardware.pin2;
large  <- hardware.pin7;
medium <- hardware.pin8;
small  <- hardware.pin9;

agent.on("dispense", function(seconds) {
    motor.write(1);
    imp.wakeup(seconds, function(){ motor.write(0);});
});

//Configure
imp.configure("Twitter M&Ms", [], []);

//Configure Pins
motor.configure(DIGITAL_OUT);
motor.write(0);
large.configure(DIGITAL_IN_PULLDOWN);
medium.configure(DIGITAL_IN_PULLDOWN);
small.configure(DIGITAL_IN_PULLDOWN);
