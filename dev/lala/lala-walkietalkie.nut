/* Lala "imp communicator"
 Two-way audio impee with 4MB SPI flash, 
 Pinout:
 1 = Wake / SPI CLK
 2 = Sampler (Audio In)
 5 = DAC (Audio Out)
 6 = Button 1
 7 = SPI CS_L
 8 = SPI MOSI
 9 = SPI MISO
 A = Battery Check (ADC) (Enabled on Mic Enable)
 B = Speaker Enable
 C = Mic Enable
 D = User LED
 E = Button 2
 */

/* HARDWARE CONFIGURATION ---------------------------------------------------*/

// turn on wifi powersave
// we'll want to do better than this and revert to totally programmatic wifi power control 
// in battery - critical situations
imp.setpowersave(true);

// configure spi bus for spi flash
hardware.spi189.configure(CLOCK_IDLE_LOW | MSB_FIRST, 100);

// buttons
hardware.pin6.configure(DIGITAL_IN); // button 1 - record
hardware.pinE.configure(DIGITAL_IN); // button 2 - play back

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


/* GLOBAL VARIABLES ---------------------------------------------------------*/
// button states for polling
button1 <- 1;
button2 <- 1;

// buffers for audio operations
buffer1 <- blob(2000);
buffer2 <- blob(2000);
buffer3 <- blob(2000);

// flag for playback completion
playBackDone <- false;

// options for the sampler
sampleRate <- 8000; // in Hz

/* Register with the imp service: takes three arguments:
1 - text to display on the bluprint
2 - array of input ports (we have none; all communication is through agent)
3 - array of output ports (we have none, again, using agent instead)
*/
imp.configure("Lala Walkie-Talkie", [],[]);


/* SAMPLER: AUDIO INPUT -----------------------------------------------------*/
// Callback to send a finished buffer to the agent
function samplesReady(buffer, length) {
    if (length > 0) {
        // Create a local buffer for a workaround: blobs seem to be changing type when sent to the agent
        // Known bug, posted to Pivotal
        local data = blob(2000);
        // return the file pointer to the beginning of the buffer (the sampler will have it somewhere else)
        buffer.seek(0,'b');
        // write a chunk of data out of the buffer into ANOTHER buffer
        // (this is a workaround)
        data.writeblob(buffer.readblob(length));
        server.log("Device: sent buffer, length "+length);
        // send up the buffer
        agent.send("audioBuffer", data);
    } else {
        server.log("Device: Record buffer overrun");
    }
}

// callback to stop the sampler when finished and alert the agent that we're done
function stopSampler() {
    server.log("Stopping sampler");
    // stop the sampler
    hardware.sampler.stop();
    // signal to the agent that we're done
    // give the sampler 100 ms to finish moving buffers around so the last one doesn't get dropped
    imp.wakeup(0.1, function() {
        agent.send("audioDone", null);
    });
}

// configure the sampler
// this is all the way down here because we need to define the callback functions first
hardware.sampler.configure(hardware.pin2, sampleRate, [buffer1, buffer2, buffer3], 
    samplesReady, NORMALISE);

/* GENERAL PURPOSE CALLBACKS ------------------------------------------------*/
// poll the buttons to watch for them to change
function pollButtons() {
    // schedule this function to run again in 100 ms (more than fast enough for human response time)
    imp.wakeup(0.1, pollButtons);
    // read the current state of the buttons
    local b1 = hardware.pin6.read();
    local b2 = hardware.pinE.read();
    // if the state of the button has changed since our last read, act on it
    if (b1 != button1) {
        // button 1 is the "record" button, so state changes here will call to the mic
        if (b1) {
            mic.recStop();
        } else {
            mic.recStart();
        }
        button1 = b1;
    }
    // button 2 is the playback button
    if (b2 != button2) {
        button2 = b2;
        if (!b2) {
            server.log("Device: Requesting message from agent for playback");
            // playback button pressed; request message from the server
            agent.send("pull", 0);
            // clear the "message waiting" LED
            hardware.pinD.write(0);
            // clear the buffers for use in playback
            buffer1 = blob(2000);
            // enable the speaker
            hardware.pinB.write(1);
            // configure the DAC
            hardware.fixedfrequencydac.configure(hardware.pin5, 8000, [buffer1], playBufferEmpty);
        }
    }
}

// turn on the battery check resistive divider and read the battery voltage
function checkBattery() {
    // check every 5 minutes
    imp.wakeup((5*60), checkBattery);
    // mic enable is used to drive the battery check gate
    mic.enable();
    // pause for 10 ms to let things settle
    imp.sleep(0.01);
    // read the ADC and the imp's supply voltage (which scales the ADC), and calculate battery voltage
    local Vbatt = (hardware.pinA.read()/65535.0) * hardware.voltage() * (6.9/2.2);
    server.log(format("Battery Voltage %.2f V",Vbatt));
    // turn the divider back off to save power
    mic.disable();
}

// play a note at the given frequency (in Hz) via PWM
function tone(freq) {
    server.log(format("Playing %d Hz tone",freq));
    hardware.pinB.write(1);
    hardware.pin5.configure(PWM_OUT, 1.0/freq, 0.5);
}

// set PWM duty cycle to 0 to stop the note
function endTone() {
    server.log("Done with tone");
    hardware.pinB.write(0);
    hardware.pin5.write(0.0);
}

/* FIXED-FREQUENCY DAC: AUDIO OUTPUT ----------------------------------------*/
// callback for when we've cleared a buffer during playback
// requests a new buffer from the agent
// shuts down the DAC and speaker power if we've finished playback
function playBufferEmpty(buffer) {
    server.log("Device: emptied a playback buffer");
    // if the agent has signaled that we've already grabbed the last chunk of the buffer,
    // stop the DAC and clean up
    if (playBackDone) {
        server.log("Device: finished last playback buffer.");
        hardware.fixedfrequencydac.stop();
        hardware.pinB.write(0);
        // now that we've handled the flag, clear it
        playBackDone = false;
    } else {
        // we're not done with the buffer yet, so request another chunk from the agent
        if (!buffer) {
            server.log("Device: buffer underrun");
            return;
        }
        agent.send("pull", 0);
    }
}

// register a callback for new buffers sent from the agent
// when the device sends "pull", the agent responds with "playData" and a new buffer
// add this buffer to the DAC, which will use it as soon as it needs it
agent.on("playData", function(buffer) {
    server.log("Device: got new data buffer from agent");
    hardware.fixedfrequencydac.addbuffer(buffer);
});

// this callback will be called when the agent sees that we've finished playing back our buffer
// just set a flag so that we stop the DAC next time we clear a buffer
agent.on("playDone", function() {
    playBackDone = true;
});

/* CLASS DEFINITIONS --------------------------------------------------------*/
// Microphone class
class microphone {
    
    isRecording = false
    
    // turn on the 2.7V LDO to power on the mic
    function enable() {
        hardware.pinC.write(1);
        server.log("Microphone Enabled");
    }
    // power off the mic
    function disable() {
        hardware.pinC.write(0);
        server.log("Microphone Disabled");
    }
    // start recording
    function recStart() {
        // turn on the mic power
        this.enable();
        this.isRecording = true;
        server.log("Recording");
        // turn on the LED
        hardware.pinD.write(1);
        hardware.sampler.start();
        // set a callback for 30s from now to force-stop recording
        // does nothing if we've already released the button and stopped at that time
        imp.wakeup(30.0, function() {
            // turn off the sampler, LED, and mic power
            mic.recStop(); 
        });
    }
    // stop recording
    function recStop() {
        // check if we've already stopped
        if (this.isRecording) {
            server.log("Stopping Recording");
            // turn off the LED
            hardware.pinD.write(0);
            
            stopSampler();
            // turn off mic power
            this.disable();
            
            // clear the recording flag
            this.isRecording = false;
        } else {
            // sampler is already stopped due to button release; no timeout    
        }
    }
}

// SPI Flash class
class spiFlash {
    // MX25L3206E SPI Flash
    // Clock up to 86 MHz (we go up to 15 MHz)
    // device commands:
    static WREN = 0x06 // write enable
    static WRDI = 0x04; // write disable
    static RDID = 0x9F; // read identification
    static RDSR = 0x05; // read status register
    static READ = 0x03; // read data
    static RES = 0xAB; // read electronic ID
    static REMS = 0x90; // read electronic mfg & device ID
    static SE = 0x20; // sector erase
    static BE = 0x52; // block erase
    static CE = 0x60; // chip erase
    static PP = 0x02; // page program
    static DP = 0xB9; // deep power down
    static RDP = 0xAB; // release from deep power down
    
    // manufacturer and device ID codes
    mfgID = null;
    devID = null;
    
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
    
}

/* EXECUTION STARTS HERE ----------------------------------------------------*/
// instatiate the class objects we've defined
mic <- microphone();
flash <- spiFlash(hardware.spi189);

// start polling the buttons and checking the battery voltage
pollButtons(); // 100 ms polling interval
checkBattery(); // 5 min polling interval

/* AGENT CALLBACKS ----------------------------------------------------------*/
agent.on("newMsg", function(value) {
    // called when the agent receives a new audio message from the cloud
    // signal the user by turning on the LED and playing a beep
    hardware.pinD.write(1);
    tone(500);
    imp.sleep(0.1);
    tone(1000);
    imp.sleep(0.1);
    endTone();
});
