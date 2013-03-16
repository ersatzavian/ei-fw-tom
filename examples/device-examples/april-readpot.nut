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