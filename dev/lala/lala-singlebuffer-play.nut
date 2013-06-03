/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

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

imp.setpowersave(true);

buffer1 <- blob(16000);

// configure spi bus for spi flash
hardware.spi189.configure(CLOCK_IDLE_LOW | MSB_FIRST, 100);

function bufferEmpty(buffer)
{
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
        //local b = blob(length);
        //buffer.seek(0);
        //b.writeblob(buffer.readblob(length));
        //agent.send("audioBuffer", b);
        //server.log("sent buffer, len "+length)
        //server.log(length);
        server.log("playing");
hardware.fixedfrequencydac.configure(hardware.pin5, 8000, [buffer1], bufferEmpty);
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
hardware.sampler.configure(hardware.pin2, 8000, [buffer1], 
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

imp.configure("Lala Test", [],[]);

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
function button1Changed() {
    server.log("Button 1 = "+hardware.pin6.read());
}
function button2Changed() {
    server.log("Button 2 = "+hardware.pinE.read());
}

function checkBattery() {
    // check every 5 minutes
    imp.wakeup((5*60), checkBattery);
    local Vbatt = (hardware.pinA.read()/65535.0) * hardware.voltage() * (6.9/2.2);
    server.log(format("Battery Voltage %.2f V",Vbatt));
}

function blinkOff() {
    imp.wakeup(5, blink);
    hardware.pinD.write(0);
}

function blink() {
    imp.wakeup(0.5, blinkOff);
    hardware.pinD.write(1);
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
        server.log("Microphone Enabled");
    }
    function disable() {
        hardware.pinC.write(0);
        server.log("Microphone Disabled");
    }
}

class spiFlash {
    // MX25L3206E SPI Flash
    // Clock up to 86 MHz (we go up to 15 MHz)
    // device commands:
    WREN = 0x06 // write enable
    WRDI = 0x04; // write disable
    RDID = 0x9F; // read identification
    RDSR = 0x05; // read status register
    READ = 0x03; // read data
    FASTREAD = 0x0B; // fast read data
    RDSFDP = 0x5A; // read SFDP
    RES = 0xAB; // read electronic ID
    REMS = 0x90; // read electronic mfg & device ID
    //const DREAD = 0x3B; // double output mode, which we don't use
    SE = 0x20; // sector erase
    BE = 0x52; // block erase
    CE = 0x60; // chip erase
    PP = 0x02; // page program
    RDSCUR = 0x2B; // read security register
    WRSCUR = 0x2F; // write security register
    ENSO = 0xB1; // enter secured OTP
    EXSO = 0xC1; // exit secured OTP
    DP = 0xB9; // deep power down
    RDP = 0xAB; // release from deep power down
    
    // manufacturer and device ID codes
    mfgID = 0;
    devID = 0;
    
    // spi interface
    spi = hardware.spi189;
    
    constructor(spi) {
        // pin 1 will always be configured as a wakeup source right before we sleep (along with using onidle)
        this.spi = spi;
    }
    
    // drive the chip select low to select the spi flash
    function select() {
        hardware.pin7.write(0);
    }
    
    // release the chip select for the spi flash
    function unselect() {
        hardware.pin7.write(1);
    }
    
    function wrenable() {
        this.select();
        spi.write(format("%c",WREN));
        this.unselect();
    }
    
    function wrdisable() {
        this.select();
        spi.write(format("%c",WRDI));
        this.unselect();
    }
    
    // note that page write can only set a given bit from 1 to 0
    // a separate erase command must be used to clear the page
    function write(offset, data) {
        this.wrenable();
        
        // check the status register's write enabled bit
        if (!(this.getStatus() & 0x02)) {
            server.error("Device: Flash Write not Enabled");
            return 1;
        }
        
        // the command, offset, and data need to go in one burst, so copy into one blob
        local writeBlob = blob(4+data.len());
        // page program command goes first
        writeBlob.writen(PP, 'b');
        // followed by 24-bit address, with no dummy 8 bits (unlike the read command);
        writeBlob.writen((offset >> 16) & 0xFF, 'b');
        writeBlob.writen((offset >> 8) & 0xFF, 'b');
        writeBlob.writen((offset & 0xFF), 'b');
        // then the page of data
        for (local i = 0; i < data.len(); i++) {
            writeBlob.writen(data[i], 'b');
        }
        this.select();
        // now send it all off
        spi.write(writeBlob);
        // release the chip select so the chip doesn't reject the write
        this.unselect();
        
        // wait for the status register to show write complete
        // 1-second timeout
        local timeout = 1000;
        while ((this.getStatus() & 0x01) && timeout > 0) {
            imp.sleep(0.001);
            timeout--;
        }
        if (timeout == 0) {
            server.error("Device: Timed out waiting for write to finish");
            return 1;
        }
        
        // writes should be automatically disabled again at the end of the page program, verify.
        if (this.getStatus() & 0x02) {
            server.error("Device: Flash failed to reset write enable after program");
            return 1;
        }
        
        // write successful 
        return 0;
    }
    
    function read(offset, bytes) {
        this.select();
        // to read, send the read command, a 24-bit address, and a dummy byte
        local readBlob = blob(bytes);
        spi.write(format("%c%c%c%c", READ, (offset >> 16) & 0xFF, (offset >> 8) & 0xFF, offset & 0xFF));
        readBlob = spi.readblob(bytes);        
        this.unselect();
        return readBlob;
    }
    
    function getStatus() {
        this.select();
        spi.write(format("%c",RDSR));
        local status = spi.readblob(1);
        this.unselect();
        return status[0];
    }
    
    function getID() {
        this.select();
        spi.write(format("%c",RDID));
        local data = spi.readblob(3);
        this.mfgID = data[0];
        this.devID = (data[1] << 8) | data[2];
        this.unselect();
    }
    
    function sleep() {
        this.select();
        spi.write(format("%c", DP));
        this.unselect();
    }
    
    function wake() {
        this.select();
        spi.write(format("%c", RDP));
        this.unselect();
    }
    
    // clear the spi flash to 0xFF
    function erase() {
        server.log("Device: Erasing SPI Flash");
        this.wrenable();
        this.select();
        spi.write(format("%c", CE));
        this.unselect();
        // chip erase takes a *while*
        local timeout = 50;
        while ((this.getStatus() & 0x01) && timeout > 0) {
            imp.sleep(1);
            timeout--;
        }
        if (timeout == 0) {
            server.error("Device: Timed out waiting for erase to finish");
            return 1;
        }
        server.log("Device: Done with chip erase");
    }
    
    function test() {
        server.log("Testing SPI Flash...");
        local testByte = 0xCC;
        local testAddr = 0x100;
        // read 2 bytes from offset 0x (just a random reg, we're not doing 
        // rigorous memtesting here, just r/w)
        local startVal = this.read(testAddr, 2);
        server.log(format("starting value: 0x %02x %02x",startVal[0],startVal[1]));
        
        // write in one page of test data
        local writeBlob = blob(2);
        for (local i = 0; i < 2; i++) {
            writeBlob.writen(testByte, 'b');
        }
        this.write(testAddr, writeBlob);
        server.log(format("wrote two bytes of 0x%02x at address 0x%04x", testByte, testAddr));
        
        // read out some test bytes to verify
        local testVal = this.read(testAddr, 2);
        server.log(format("read back: 0x %02x %02x",testVal[0],testVal[1]));
    }
}

// instantiate class objects
mic <- microphone();
flash <- spiFlash(hardware.spi189);

// turn on the 2.7V rail so we can measure it manually
mic.enable();

// start polling the buttons and checking the battery voltage
pollButtons(); // 100 ms polling interval
checkBattery(); // 5 min polling interval
//blink(); // start user LED blinking every 30 seconds

// test out the flash
flash.getID();
// should read out "0xC2" for manufacturer code, "0x2016" for device id code
server.log(format("Flash MFG ID: 0x%02x, DEV ID: 0x%04x", flash.mfgID, flash.devID));
//flash.erase();
//flash.test();

server.log("Testing speaker with PWM...");
tone(250);
imp.sleep(0.25);
tone(500);
imp.sleep(0.25);
hardware.pin5.write(0.0);

server.log("Mic Recording for 10s");
hardware.pinD.write(1);
hardware.sampler.start();
imp.wakeup(1, stopSampler);

/* For external audio test
// enable the speaker
hardware.pinB.write(1);
// high-Z the imp pin so we don't do something bad while using an external signal to test
hardware.pin5.configure(ANALOG_IN);
*/
