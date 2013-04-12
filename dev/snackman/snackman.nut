// Snack Dispenser
// Pin5 Motor Driver
// Pin7 Switch = Large
// Pin8 Switch = Medium
// Pin9 Switch = Small
imp.setpowersave(true);

motor  <- hardware.pin2;
large  <- hardware.pin7;
medium <- hardware.pin8;
small  <- hardware.pin9;

agent.on("dispense", function(seconds) {
    motor.write(1);
    imp.wakeup(seconds, function(){ motor.write(0);});
});

//Configure
imp.configure("Twitter M&Ms", [], []);

//Configure Pins
motor.configure(DIGITAL_OUT);
motor.write(0);
large.configure(DIGITAL_IN_PULLDOWN);
medium.configure(DIGITAL_IN_PULLDOWN);
small.configure(DIGITAL_IN_PULLDOWN);
