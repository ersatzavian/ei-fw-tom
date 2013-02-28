// Red-Yellow-Green Google Maps Traffic Light
// With capacitive touch sensor

// pin 1 is send pin
local sendPin = hardware.pin1;
// pin 2 is sense pin
local sensePin = hardware.pin2;
// the two flip-flop over the course of one cycle

local ledFreq = 1000.0;
// red
local redVal = 0.0;
hardware.pin8.configure(PWM_OUT, 1.0/ledFreq, redVal);
// green 
local greenVal = 0.0;
hardware.pin9.configure(PWM_OUT, 1.0/ledFreq, greenVal);
// yellow is 0.7 red, 0.2 green

// number of samples to run in the capacitive sensor
local numSamples = 1;

// light state (1 for on)
local lightState = 1;
// bool to keep us from re-toggling on a long press
local alreadyToggled = false;

// steps to fade in or fade out
local fadesteps = 1000.0;

function keepAlive() {
    local now = time();
    server.log(format("Client Ping at %d",now));
    imp.wakeup(900, keepAlive);
}

class capSensor {
    // arbitrary "capacitance" count
    total = 0
    // timeout in microseconds (1s)
    timeout = 50000
    
    function senseOneCycle() {
        // completely discharge sense pin
        sensePin.configure(DIGITAL_OUT_OD);
        sensePin.write(0);
        
        // reassign sense pin as input
        sensePin.configure(DIGITAL_IN);
        
        // set send pin high
        sendPin.configure(DIGITAL_OUT);
        sendPin.write(1);
        
        local start = hardware.micros();
        // wait for sense pin to trigger
        while ((!sensePin.read()) && (hardware.micros()-start) < this.timeout) {
            this.total++;
        }
        
        return this.total;
    }
    
    function senseRaw(samples) {
        for (local i = 0; i < samples; i++) {
            // catch timeouts inside of a one-cycle event
            if (this.senseOneCycle() < 0) {
                return this.total;
            }
        }
        return this.total;
    }
}


class lightInput extends InputPort {
    type = "bool"
    name = ""
    pin = null
    
    constructor(name, pin) {
        this.name = name;
        this.pin = pin;
    }
    
    function set(value) {
        if (value) {
            server.log("setting "+this.name+" to "+value);
            pin.write(1.0);
        } else {
            pin.write(0);
        }
    }
}

function fadeIn() {
    local red = 0.0;
    local green = 0.0;
    local redstep = redVal / fadesteps;
    local greenstep = greenVal / fadesteps;
    for (local i = 0; i < fadesteps; i++) {
        hardware.pin8.write(red);
        hardware.pin9.write(green);
        red += redstep;
        green += greenstep;
    }
    hardware.pin8.write(redVal);
    hardware.pin9.write(greenVal);
}

function fadeOut() {
    local red = redVal;
    local green = greenVal;
    local redstep = redVal / fadesteps;
    local greenstep = greenVal / fadesteps;
    for (local i = 0; i < fadesteps; i++) {
        hardware.pin8.write(red);
        hardware.pin9.write(green);
        red -= redstep;
        green -= greenstep;
    }
    hardware.pin8.write(0.0);
    hardware.pin9.write(0.0);
}

function toggleLight() {
    if (lightState) {
        lightState = 0;
        server.log("Turning Off");
        fadeOut();
    } else {
        server.log("Turning On");
        lightState = 1;
        fadeIn();
    }
}

function runSensor() {
    local sensor = capSensor();
    local tick = hardware.micros();
    local sensorVal = sensor.senseRaw(numSamples);
    local tock = hardware.micros();
    local runtime = tock - tick;
    //server.log(format("Sensor ran %d samples in %d, got %d",numSamples, runtime, sensorVal));
    if (sensorVal > 0 && !alreadyToggled) {
        // touch detected
        toggleLight();
        alreadyToggled = true;
    } else if (sensorVal == 0) {
        //server.log("Resetting alreadyToggled");
        alreadyToggled = false;
    }
    imp.wakeup(0.075, runSensor);
}

agent.on("trafficUpdate",function(color){
    if (color == "green") {
        greenVal = 1.0;
        redVal = 0.0;
    } else if (color == "red") {
        greenVal = 0.0;
        redVal = 1.0;
    } else {
        // yellow
        greenVal = 0.2;
        redVal = 0.7;
    }
    if (lightState) {
        hardware.pin9.write(greenVal);
        hardware.pin8.write(redVal);
    }
});

imp.configure("Traffic Light", [lightInput("red",hardware.pin8), lightInput("green",hardware.pin9)],[]);

runSensor();
keepAlive();