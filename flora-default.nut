// water level sensor
server.log("Flora booted");

local out1 = OutputPort("Water level");
imp.configure("Water level sensor", [], [out1]);

// moar battery life
//imp.setpowersave(true);

local enable = hardware.pin9;
local counter = hardware.pin1;

enable.configure(DIGITAL_OUT);
enable.write(1);

counter.configure(PULSE_COUNTER, 0.01);

local prev = -1.0;

function sample() {
    local count;
    local level;

    // turn on oscillator, sample, turn off
    enable.write(1);
    count = counter.read();
    enable.write(0);
    
    // work out level
    if (count > 5000) level=0;
    else {
        // see http://www.xuru.org/rt/PowR.asp#CopyPaste
        level = math.pow(count/3035.162425, -1.1815893306620);
        if (level<0.0) level=0.0;
    }

    // convert to a zero to one type thing
    level=level/10.0;
    if (level>1.0) level=1.0;
    
    //level = 4.0*level;

    if (math.fabs(level - prev) > 0.005) {
        server.show(format("%.2f",level)); 
        //server.log(format("%.2f",level));        
        out1.set(level);
        prev = level;
    }

    // changed this to every second
    imp.wakeup(0.05, sample); 
}

sample();
