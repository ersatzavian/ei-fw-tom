// Imp with a peristaltic pump to water my tomatoes
// Pump is driven with a FET on pin 1

imp.configure("Imp Irrigator",[],[]);
imp.enableblinkup(true);

pump <- hardware.pin1;
pump.configure(DIGITAL_OUT);

agent.on("pump", function(value) {
    if (value) {
        server.log("Turning Pump On");
        pump.write(1);
    } else {
        server.log("Turning Pump Off");
        pump.write(0);
    }
});
