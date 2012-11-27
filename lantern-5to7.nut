// Turn on Lantern from 5 to 7 PM
// 11/26/12

hardware.pin2.configure(DIGITAL_OUT);
imp.setpowersave(true);

server.log("Hardware Configured");

// light lantern at 5 PM
// Note that the imp takes the current time in GMT
local wakeAtHour = 1;
local wakeAtMinute = 0;
// turn lantern off at 7 PM
local sleepAtHour = 3;
local sleepAtMinute = 0;

local wakeAt = (60 * wakeAtHour) + wakeAtMinute;
local sleepAt = (60 * sleepAtHour) + sleepAtMinute

local currentTime = date(time(),'l');
server.log(format("Currently %d:%02d", currentTime.hour currentTime.min));
local currentMin = (currentTime.hour * 60) + currentTime.min;

if ((currentMin >= wakeAt) && (currentMin < sleepAt)) {
    // we're in the "on" time
    hardware.pin2.write(1);
    server.log(format("Lantern On at %d:%02d", currentTime.hour,currentTime.min));
    
    // now figure out how long to shallow sleep for before waking up to turn off the light
    local lightOnHours = (sleepAtHour - currentTime.hour - 1);
    if (lightOnHours < 0) {
        lightOnHours = 0;
    }
    local lightOnMinutes = ((sleepAtMinute - currentTime.min) + (60 * lightOnHours));
    server.log(format("Shallow sleeping for %d minutes", lightOnMinutes));
    imp.sleep(60.0 * lightOnMinutes);
} 

currentTime = date(time(),'l');
hardware.pin2.write(0);
server.log(format("Lantern Off at %d:%02d", currentTime.hour, currentTime.min));

// deep sleep until it's time to turn on the lantern
server.sleepuntil(wakeAtHour, wakeAtMinute);

imp.configure("Lantern", [], []);
