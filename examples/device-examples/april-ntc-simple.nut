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

// April with a 10k, 1% from 3V3 to pin9 and 10k B57861S0103F040 NTC Thermistor from pin9 to ground
// pin9 ANALOG NTC value

// Configure Pins
// pin 9 is the middle of the voltage divider formed by the NTC - read the analog voltage to determine temperature
hardware.pin9.configure(ANALOG_IN);

// all calculations are done in Kelvin
// these are constants for this particular thermistor; if using a different one,
// check your datasheet
const b_therm = 4250;
const t0_therm = 298.15;

// Output structure for sending temperature to server
local tempOut    = OutputPort("Temperature (F)", "number");
local tempOutStr = OutputPort("Temperature (F)", "string");

function getTemp() {
    // scale the ADC reading to a voltage by dividing by the full-scale value and multiplying by the supply voltage
    local v_therm = 3.3 * hardware.pin9.read() / 65535.0;
    // calculate the resistance of the thermistor at the current temperature
    local r_therm = 10000.0 / ( (3.3 / v_therm) - 1);
    local ln_therm = math.log(10000.0 / r_therm);
    
    local t_therm = (t0_therm * b_therm) / (b_therm - t0_therm * ln_therm) - 273.15;
    
    // convert to fahrenheit for the less-scientific among us
    local f = (t_therm) * 9.0 / 5.0 + 32.0;
    // format into a string for the string output port
    local f_str = format("%.01f", f)
    server.log("Current temp is "+f_str+" F");
    
    // emit values to our output ports
    tempOut.set(f);
    tempOutStr.set(f_str);
    
    imp.wakeup(600, getTemp);
}

// Configure on planner and register with imp server
imp.configure("Simple NTC Thermometer", [], [tempOut, tempOutStr]);
getTemp();