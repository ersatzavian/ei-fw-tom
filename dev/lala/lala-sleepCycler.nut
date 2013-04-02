// Lala sleep cycler
// deep sleep, waking every (programmable) seconds
// log battery voltage and wake count to COSM

// A = Battery Check (ADC) (Enabled on Mic Enable)
// C = Mic Enable

// sleep time in seconds
// NOTE: server.sleepfor always adds 4 seconds to your sleep time
sleepTime <- 1;

// Battery measurement pin
hardware.pinA.configure(ANALOG_IN);

// mic enable / battery check enable
hardware.pinC.configure(DIGITAL_OUT);
hardware.pinC.write(0);

//Check Battery Usage Over a series of wakeups
if (!("nv" in getroottable()) || !("count" in nv)){nv <- {count = 0, vtot = 0, vcnt = 0};}
 
cnt <- OutputPort("Count", "number");
vin <- OutputPort("Vbatt", "number");
 
imp.configure("Sleep Cycler", [], [cnt,vin]);

function checkBattery() {
    // no need to schedule callback here because we'll deep sleep and therefore reload
    // enable the battery check
    hardware.pinC.write(1);
    // this turns on the LDO, too, so let that settle
    imp.sleep(0.05);
    // read the ADC
    local Vbatt = (hardware.pinA.read()/65535.0) * hardware.voltage() * (6.9/2.2);
    // turn the battery check back off
    hardware.pinC.write(0);
    // log the value
    server.log(format("Battery Voltage %.2f V",Vbatt));
    return Vbatt;
}
 
//Boot Count
nv.count += 1;

// Averaging Sum and Counter
nv.vtot += checkBattery();
nv.vcnt += 1;
 
//Only send every 10th sample so Cosm doesn't hate us.
if(nv.count == 1 || nv.vcnt == 10){
    server.log("Posting Values to COSM");
    vin.set(nv.vtot/nv.vcnt);
    cnt.set(nv.count);
    nv.vtot = 0;
    nv.vcnt = 0;
}
 
imp.onidle( function() {server.sleepfor(sleepTime);});