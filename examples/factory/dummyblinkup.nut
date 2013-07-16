
const LEN = 2.0;
const BAUD = 60.0;

imp.configure("Blinkup Fixture Test",[],[]);

function blinkup() {
    imp.wakeup(LEN, stop);
    hardware.pin9.write(0.5);
}

function stop() {
    hardware.pin9.write(0);
}

function btnPressed() {
    if (!hardware.pin8.read()) {
        server.log("Sending dummy blinkup");
        blinkup();
    }
}

hardware.pin8.configure(DIGITAL_IN_PULLUP, btnPressed);
hardware.pin9.configure(PWM_OUT, 1.0/(BAUD / 2.0), 0.0);