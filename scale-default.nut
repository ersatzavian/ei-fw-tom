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
    weight_out.set(format("%0.2f",weight));
    server.show(format("%0.2f oz",weight));
    
    imp.wakeup(1.0, readWeight);
}

function tare() {
    tareValue = readCell();
}

// Ports 

local outWeight = OutputPort("Weight");

// Configuring pins

hardware.pin1.configure(DIGITAL_IN, tare);
hardware.pin2.configure(ANALOG_IN);

server.log("Hardware Configured");

imp.configure("Impee Scale", [], [weight_out]);

tare();
readWeight();