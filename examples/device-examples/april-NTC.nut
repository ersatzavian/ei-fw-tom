// April with a 10k, 1% from 3V3 to pin9 and 10k B57861S0103F040 NTC Thermistor from pin9 to pin8
// pin8 TEMP_READ_EN_L - drive low to enable temp reading (great for batteries!)
// pin9 ANALOG NTC value

// benchmarking runtime: first tick with hardware.micros
local tick = hardware.micros();

// turn on WiFi power save to reduce power consumption when awake
imp.setpowersave(true);

// Output structure for sending temperature to server
local tempOut    = OutputPort("Temperature (F)", "number");
local tempOutStr = OutputPort("Temperature (F)", "string");
local battOut    = OutputPort("Battery Voltage", "number");

// Configure on planner and register with imp server
imp.configure("April NTC Thermometer", [], [tempOut, tempOutStr, battOut]);

// Configure Pins
// pin 8 is driven high to turn off temp monitor (saves power) or low to read
hardware.pin8.configure(DIGITAL_OUT);
hardware.pin8.write(1); 
// pin 9 is the middle of the voltage divider formed by the NTC - read the analog voltage to determine temperature
hardware.pin9.configure(ANALOG_IN);

// all calculations are done in Kelvin
// these are constants for this particular thermistor; if using a different one,
// check your datasheet
const b_therm = 3988;
const t0_therm = 298.15;

// to read the battery voltage reliably, we take 10 readings and average them
local v_high  = 0;
for(local i = 0; i < 10; i++){
    imp.sleep(0.01);
    v_high += hardware.voltage();
}
v_high = v_high / 10.0;

// benchmarking: see how long thermistor is "on"
local ton = hardware.micros();
// turn on the thermistor network
hardware.pin8.write(0);
// gather several ADC readings and average them (just takes out some noise)
local val = 0;
for (local i = 0; i < 10; i++) {
    imp.sleep(0.01);
    val += hardware.pin9.read();
}
val = val/10;
// turn the thermistor network back off
hardware.pin8.write(1);
local toff = hardware.micros();
server.log(format("Thermistor Network on for %d us", (toff-ton)));

// scale the ADC reading to a voltage by dividing by the full-scale value and multiplying by the supply voltage
local v_therm = v_high * val / 65535.0;
// calculate the resistance of the thermistor at the current temperature
local r_therm = 10000.0 / ( (v_high / v_therm) - 1);
local ln_therm = math.log(10000.0 / r_therm);

local t_therm = (t0_therm * b_therm) / (b_therm - t0_therm * ln_therm) - 273.15;

// convert to fahrenheit for the less-scientific among us
local f = (t_therm) * 9.0 / 5.0 + 32.0;
// format into a string for the string output port
local f_str = format("%.01f", f)
server.log("Current temp is "+f_str);

// emit values to our output ports
tempOut.set(f_str);
tempOutStr.set(f_str+" F");

// update the current battery voltage with a nicely-formatted string of the most recently-calculated value
local batt_str = format("%.02f V",v_high)
battOut.set(batt_str);
server.log("Battery Voltage is "+batt_str);
 
// benchmarking runtime
local tock = hardware.micros();
server.log(format("Read cycle took %d us", (tock-tick)));
 
//Sleep for 15 minutes and 1 second, minus the time past the 0:15
//so we wake up near each 15 minute mark (prevents drifting on slow DHCP)
imp.onidle( function() { 
    server.sleepfor(1 + 15*60 - (time() % (15*60))); 
});

// full firmware is reloaded and run from the top on each wake cycle, so no need to construct a loop