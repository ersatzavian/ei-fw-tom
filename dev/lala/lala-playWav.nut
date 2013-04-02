// Lala current measurement firmware
// Press a button to cycle power modes

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

//imp.setpowersave(true);
imp.configure("Lala Audio Playback", [],[]);

/* SAMPLER AND FIXED-FREQUENCY DAC -------------------------------------------*/

// buffers and sample rate for sampler and fixed-frequency DAC
sampleRate <- 16000;
buffer1 <- blob(2000);
buffer2 <- blob(2000);
buffer3 <- blob(2000);

// buffer lengths for playback and recording
playbackPtr <- 0;
playbackBufferLen <- 0;
playing <- false;
recordBufferLen <- 0;

// size of chunks to send between agent and device
CHUNKSIZE <- 256;

// flag for new message downloaded from the agent
newMessage <- false;

// callback and buffers for the sampler
function samplesReady(buffer, length) {
    if (length > 0) {
        // got a buffer
    } else {
        //server.log("Overrun");
    }
}

function stopSampler() {
    server.log("Stopping sampler");
    // stop the sampler
    hardware.sampler.stop();
}

// configure the sampler
hardware.sampler.configure(hardware.pin2, sampleRate, [buffer1,buffer2,buffer3], 
    samplesReady);

// callback for the fixed-frequency DAC
function bufferEmpty() {
    server.log("FFD Buffer empty");
    if (!buffer) {
        server.log("FFD Buffer underrun");
        return;
    }
    // return the pointer to the beginning of the buffer
    buffer.seek(0,'b');
    if (playbackPtr >= playbackBufferLen) {
        // we're at the end of the message buffer, so don't reload the DAC
        // the DAC will be stopped before it runs out of buffers anyway
        return;
    }
    buffer.writeblob(flash.read(playbackPtr, buffer.len()));
    playbackPtr += buffer.len();
    hardware.fixedfrequencydac.addbuffer(buffer);
}

// prep buffers to begin message playback
function loadPlayback() {
    playbackPtr = 0;
    // make sure buffers' pointers are all at the beginning of the buffer
    buffer1.seek(0,'b');
    buffer2.seek(0,'b');
    buffer3.seek(0,'b');
    // flash.read returns a blob
    buffer1.writeblob(flash.read(playbackPtr, buffer1.len()));
    playbackPtr += buffer1.len();
    buffer2.writeblob(flash.read(playbackPtr, buffer2.len()));
    playbackPtr += buffer2.len();
    buffer3.writeblob(flash.read(playbackPtr, buffer3.len()));
    playbackPtr += buffer3.len();
    
    // configure the DAC
    hardware.fixedfrequencydac.configure(hardware.pin5, sampleRate, [buffer1,buffer2,buffer3], bufferEmpty);
}

function stopPlayback() {
    // stop the DAC
    hardware.fixedfrequencydac.stop();
    // disable the speaker
    hardware.pinB.write(0);
    // put the flash back to sleep
    flash.sleep();
    // return the playback pointer for the next time we want to play this message (now that it's cached);
    playbackPtr = 0;
    // set the flag to show that there is no longer a playback in progress
    playing = false;
}

/* OTHER HARDWARE CONFIGURATION ----------------------------------------------*/

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

// configure spi bus for spi flash
hardware.spi189.configure(CLOCK_IDLE_LOW | MSB_FIRST, 15000);

/* GLOBAL FUNCTIONS ----------------------------------------------------------*/
button1 <- 1;
button2 <- 1;
blinkCntr <- 0;
function pollButtons() {
    imp.wakeup(0.1, pollButtons);
    // manage LED blink here
    if (newMessage) {
        // turn LED for 200 ms out of every 2 seconds
        if (blinkCntr == 18) {
            hardware.pinD.write(1);
        } else if (blinkCntr == 20) {
            hardware.pinD.write(0);
        }
    } else {
        // make sure the LED is off
        hardware.pinD.write(0);
    }
    if (blinkCntr > 19) {
        blinkCntr = 0;
    }
    blinkCntr++;
    // now handle the buttons
    local b1 = hardware.pin6.read();
    local b2 = hardware.pinE.read();
    if (b1 != button1) {
        button1 = b1;
        if (!button1) {
            recordMessage();
        }
    }
    if (b2 != button2) {
        button2 = b2;
        if (!button2) {
            playMessage();
        }
    }
}

function recordMessage() {
    server.log("Device: recording message to flash");
}

function playMessage() {
    server.log("Device: playing back stored message from flash");
    // wake the flash, as we'll be using it now
    flash.wake();
    // load the first set of buffers before we start the dac
    loadPlayback();
    // set the playing flag
    playing = true;
    // schedule the dac to stop running when we're done
    imp.wakeup((playbackBufferLen * 1.0) / (sampleRate * 1.0), stopPlayback);
    // enable the speaker
    hardware.pinB.write(1);
    // start the dac
    hardware.fixedfrequencydac.start();

}

/* CLASS DEFINITIONS ---------------------------------------------------------*/
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

class spiFlash {
    // MX25L3206E SPI Flash
    // Clock up to 86 MHz (we go up to 15 MHz)
    // device commands:
    static WREN = "\x06" // write enable
    static WRDI = "\x04"; // write disable
    static RDID = "\x9F"; // read identification
    static RDSR = "\x05"; // read status register
    static READ = "\x03"; // read data
    static FASTREAD = "\x0B"; // fast read data
    static RDSFDP = "\x5A"; // read SFDP
    static RES = "\xAB"; // read electronic ID
    static REMS = "\x90"; // read electronic mfg & device ID
    static DREAD = "\x3B"; // double output mode, which we don't use
    static SE = "\x20"; // sector erase (Any 4kbyte sector set to 0xff)
    static BE = "\x52"; // block erase (Any 64kbyte sector set to 0xff)
    static CE = "\x60"; // chip erase (full device set to 0xff)
    static PP = "\x02"; // page program (note: write can only set bytes from "1" to "0";
                // erase to set from "0" to "1")
    static RDSCUR = "\x2B"; // read security register
    static WRSCUR = "\x2F"; // write security register
    static ENSO = "\xB1"; // enter secured OTP
    static EXSO = "\xC1"; // exit secured OTP
    static DP = "\xB9"; // deep power down
    static RDP = "\xAB"; // release from deep power down
    
    // manufacturer and device ID codes
    mfgID = null;
    devID = null;
    
    // spi interface
    spi = null;
    cs_l = null;

    // constructor takes in pre-configured spi interface object and chip select GPIO
    constructor(spiBus, csPin) {
        spi = spiBus;
        cs_l = csPin;
    }
    
    // drive the chip select low to select the spi flash
    function select() {
        cs_l.write(0);
    }
    
    // release the chip select for the spi flash
    function unselect() {
        cs_l.write(1);
    }
    
    function wrenable() {
        this.select();
        spi.write(WREN);
        this.unselect();
    }
    
    function wrdisable() {
        this.select();
        spi.write(WRDI);
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
        
        this.select();
        // page program command goes first
        spi.write(PP);
        // followed by 24-bit address
        spi.write(format("%c%c%c", (offset >> 16) & 0xFF, (offset >> 8) & 0xFF, offset & 0xFF));
        spi.write(data);
        // release the chip select so the chip doesn't reject the write
        this.unselect();
        
        // wait for the status register to show write complete
        // typical 1.4 ms, max 5 ms
        local timeout = 25;
        while ((this.getStatus() & 0x01) && timeout > 0) {
            imp.sleep(0.0002);
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
        spi.write(READ);
        spi.write(format("%c%c%c", (offset >> 16) & 0xFF, (offset >> 8) & 0xFF, offset & 0xFF));
        local readBlob = spi.readblob(bytes);        
        this.unselect();
        return readBlob;
    }
    
    function getStatus() {
        this.select();
        spi.write(RDSR);
        local status = spi.readblob(1);
        this.unselect();
        return status[0];
    }
    
    function getID() {
        this.select();
        spi.write(RDID);
        local data = spi.readblob(3);
        this.mfgID = data[0];
        this.devID = (data[1] << 8) | data[2];
        this.unselect();
    }
    
    function sleep() {
        this.select();
        spi.write(DP);
        this.unselect();
    }
    
    function wake() {
        this.select();
        spi.write(RDP);
        this.unselect();
    }
    
    // set any 4kbyte sector of flash to all 0xff
    // takes a starting address, 24-bit, MSB-first
    function sectorErase(addr) {
        server.log(format("Device: erasing 4kbyte SPI Flash sector beginning at 0x%04x",addr));
        this.wrenable();
        this.select();
        spi.write(SE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        this.unselect();
        // wait for sector erase to complete
        // typ = 60ms, max = 300ms
        local timeout = 300; // time in tenths of a second
        while ((this.getStatus() & 0x01) && timeout > 0) {
            imp.sleep(0.001);
            timeout--;
        }
        if (timeout == 0) {
            server.error("Device: Timed out waiting for sector erase to finish");
            return 1;
        }
        server.log("Device: done with sector erase");
        return 0;
    }
    
    // set any 64kbyte block of flash to all 0xff
    // takes a starting address, 24-bit, MSB-first
    function blockErase(addr) {
        server.log(format("Device: erasing 64kbyte SPI Flash block beginning at 0x%04x",addr));
        this.wrenable();
        this.select();
        spi.write(BE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        this.unselect();
        // wait for sector erase to complete
        // typ = 700ms, max = 2s
        local timeout = 2000; // time in ms
        while ((this.getStatus() & 0x01) && timeout > 0) {
            imp.sleep(0.001);
            timeout--;
        }
        if (timeout == 0) {
            server.error("Device: Timed out waiting for sector erase to finish");
            return 1;
        }
        //server.log("Device: done with sector erase");
        return 0;
    }
    
    // clear the full flash to 0xFF
    function chipErase() {
        server.log("Device: Erasing SPI Flash");
        this.wrenable();
        this.select();
        spi.write(CE);
        this.unselect();
        // chip erase takes a *while*
        // typ = 25s, max = 50s
        local timeout = 50000; // time in ms
        while ((this.getStatus() & 0x01) && timeout > 0) {
            imp.sleep(0.001);
            timeout--;
        }
        if (timeout == 0) {
            server.error("Device: Timed out waiting for chip erase to finish");
            return 1;
        }
        server.log("Device: Done with chip erase");
        return 0;
    }
    
    // erase the message portion of the SPI flash
    // 2880000 bytes is 45 64-kbyte blocks
    function erasePlayBlocks() {
        for(local i = 0; i < 45; i++) {
            if(this.blockErase(i*64000)) {
                server.error(format("Device: SPI flash failed to erase block %d (addr 0x%06x)",
                    i, i*64000));
                return 1;
            }
        }
        return 0;
    }
    
    // erase the record buffer portion of the SPI flash
    // this is a 960000-byte sector, beginning at block 46 and going to block 60
    function eraseRecBlocks() {
        for (local i = 46; i < 60; i++) {
            if(this.blockErase(i*640000)) {
                server.error(format("Device: SPI flash failed to erase block %d (addr 0x%06x)",
                    i, i*64000));
                return 1;
            }
        }
        return 0;
    }
}

/* AGENT CALLBACK HOOKS ------------------------------------------------------*/
// allow the agent to signal that it's got new audio data for us, and prepare for download
agent.on("newAudio", function(len) {
    server.log(format("Device: New playback buffer in agent, len: %d bytes", len));
    // set our global playback buffer length variable so that when we go to playback this buffer later,
    // we don't wind up playing noise past the end of the buffer
    playbackBufferLen = len;
    // takes length of the new playback buffer in bytes
    // we have 4MB flash - with A-law compression -> 1 byte/sample -> 4 000 000 / sampleRate seconds of audio
    // @ 16 kHz -> 250 s of audio (4.16 minutes)
    // allow 3 min for playback buffer (@16kHz -> 2 880 000 bytes)
    // allow 1 min for outgoing buffer (@16kHz -> 960 000 bytes)
    if (len > 2880000) {
        server.error("Device: new audio buffer length too large ("+len+" bytes, max 2880000 bytes)");
        return 1;
    }
    // erase the message portion of the SPI flash
    // 2880000 bytes is 45 64-kbyte blocks
    server.log("Device: Clearing playback flash sectors");
    // wake the flash in preparation for download
    flash.wake();
    flash.erasePlayBlocks();
    server.log("Device: playback flash sectors clear");
    
    // signal to the agent that we're ready to download a chunk of data
    agent.send("pull", CHUNKSIZE);
});

// when device sends "pull" request to agent for new chunk of data, agent responds with "push"
agent.on("push", function(data) {
    // agent sends a two-element table
    // data.index is the segment number of this chunk
    // data.chunk is the chunk itself
    // allows for out-of-order delivery, and helps us place chunks in flash
    local addr = data.index*CHUNKSIZE;
    local chunk = data.chunk;
    server.log(format("Got buffer chunk %d from agent, len %d", addr, chunk.len()));
    // stash this chunk away in flash, then pull another from the agent
    // this allows us to throttle transmission from the agent
    flash.write(addr,chunk);
    
    // see if we're done downloading
    if (addr + chunk.len() >= playbackBufferLen) {
        // we're done. set the global new message flag
        // this will cause the LED to blink (in the button-poll function) as well
        newMessage = true;
        // we can put the flash back to sleep now to save power
        flash.sleep();
        server.log("Device: New message downloaded to flash");
    } else {
        // not done yet, get more data
        agent.send("pull", CHUNKSIZE);
    }
});

/* BEGIN EXECUTION -----------------------------------------------------------*/
// instantiate class objects
mic <- microphone();
flash <- spiFlash(hardware.spi189, hardware.pin7);
// flash powers up in high-power standby. Put it to sleep to save power
flash.sleep();

// start polling the buttons
pollButtons(); // 100 ms polling interval

// request the test audio from the agent
server.log("Device: sending request to run playback test");
agent.send("playtest", null);