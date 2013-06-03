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

// April with brightness-controlled LED

hardware.pin9.configure(PWM_OUT, 1.0/500.0, 1.0);

class ledBrightness extends InputPort
{
    name = "LED Brightness"
    type = "number"
    
    function set(value) {
        // since pin 9 is configured for PWM, we can set the duty cycle with pin.write()
        // write a floating point number between 0.0 and 1.0, where 1.0 = 100% duty cycle
        server.log(value);
        hardware.pin9.write(1.0-value);
    }

}

server.log("Brightness Controller Started");
imp.configure("April Brightness Controller", [ ledBrightness() ], []);