// Lala "imp communicator"
// Two-way audio impee with 4MB SPI flash, 
// Pinout:
// 1 = Wake / SPI CLK
// 2 = Sampler (Audio In)
// 5 = DAC (Audio Out)
// 6 = Button 1
// 7 = SPI CS_L
// 8 = SPI MOSI
// 9 = SPI MISO
// A = Battery Check (ADC) (Enabled on Mic Enable)
// B = Speaker Enable
// C = Mic Enable
// D = User LED
// E = Button 2

sampleRate <- 8000;

imp.setpowersave(true);

buffer1 <- blob(16000);
function bufferEmpty(buffer) {
    server.log("In bufferEmpty");
    if (!buffer) {
        server.log("Underrun");
        return;
    }
    hardware.fixedfrequencydac.addbuffer(buffer);
}
// callback and buffers for the sampler
function samplesReady(buffer, length) {
    hardware.sampler.stop();
    
    if (length > 0) {
        server.log("playing");
        hardware.fixedfrequencydac.configure(hardware.pin5, sampleRate, [buffer1], bufferEmpty);
        mic.disable();
        imp.sleep(0.05);
        hardware.fixedfrequencydac.start();
    } else {
        server.log("Overrun");
    }
}
function stopSampler() {
    server.log("Stopping sampler");
    // turn off the aux LED
    hardware.pinD.write(0);
    // stop the sampler
    hardware.sampler.stop();
    // signal to the agent that we're done
    agent.send("audioDone", null);
    // disable the microphone
    mic.disable();
}
// configure the sampler at 8kHz
hardware.sampler.configure(hardware.pin2, sampleRate, [buffer1], 
    samplesReady);

// buttons
hardware.pin6.configure(DIGITAL_IN);
hardware.pinE.configure(DIGITAL_IN);

// SPI CS_L
hardware.pin7.configure(DIGITAL_OUT);
// Battery Check
hardware.pinA.configure(ANALOG_IN);
// speaker enable
hardware.pinB.configure(DIGITAL_OUT);
hardware.pinB.write(0);
// mic enable
hardware.pinC.configure(DIGITAL_OUT);
hardware.pinC.write(0);
// user LED driver
hardware.pinD.configure(DIGITAL_OUT);
hardware.pinD.write(0);

imp.configure("Lala Repeat", [],[]);

button1 <- 1;
button2 <- 1;
function pollButtons() {
    imp.wakeup(0.1, pollButtons);
    local b1 = hardware.pin6.read();
    local b2 = hardware.pinE.read();
    if (b1 != button1) {
        server.log("Button 1 = "+b1);
        button1 = b1;
    }
    if (b2 != button2) {
        server.log("Button 2 = "+b2);
        button2 = b2;
    }
}

function checkBattery() {
    // check every 5 minutes
    imp.wakeup((5*60), checkBattery);
    local Vbatt = (hardware.pinA.read()/65535.0) * hardware.voltage() * (6.9/2.2);
    server.log(format("Battery Voltage %.2f V",Vbatt));
}

function endTone() {
    server.log("Done with tone");
    hardware.pinB.write(0);
    hardware.pin5.write(0.0);
}

function tone(freq) {
    server.log(format("Playing %d Hz tone",freq));
    hardware.pinB.write(1);
    hardware.pin5.configure(PWM_OUT, 1.0/freq, 0.5);
    //imp.wakeup(time, endTone);
}

class microphone {
    function enable() {
        hardware.pinC.write(1);
        // wait for the LDO to stabilize
        imp.sleep(0.05);
        server.log("Microphone Enabled");
    }
    function disable() {
        hardware.pinC.write(0);
        imp.sleep(0.05);
        server.log("Microphone Disabled");
    }
}

// instantiate class objects
mic <- microphone();

// turn on the 2.7V rail so we can measure it manually
mic.enable();

// start polling the buttons and checking the battery voltage
pollButtons(); // 100 ms polling interval
checkBattery(); // 5 min polling interval

server.log("Testing speaker with PWM...");
tone(250);
imp.sleep(0.25);
tone(500);
imp.sleep(0.25);
hardware.pin5.configure(DIGITAL_OUT);
hardware.pin5.write(0);
imp.sleep(0.25);

server.log("Mic Recording for 10s");
hardware.pinD.write(1);
hardware.sampler.start();
imp.wakeup(2, stopSampler);