/* Lala Audio Impee

 Tom Buttner, April 2013
 Electric Imp, inc
 tom@electricimp.com

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

// turn on powersave to reduce average wifi power by skipping beacons
// note that this increases network latency by up to 300 ms
//imp.setpowersave(true);

// register with the imp service
imp.configure("Lala Audio Playback", [],[]);

/* GLOBAL PARAMETERS AND FLAGS ----------------------------------------------*/

// parameters for wav file from the agent
inParams <- {
    // agent passes in compression settings (A_LAW_DECOMPRESS, if applicable)
    compression = null,
    // width parameter sets sample width character flag for blob read/write:
    //    'b' - 8 bits/sample
    //    'w' - 16 bits/sample
    width = null,
    // sample rate in Hz
    samplerate = 16000,
    // length of actual data in data chunk
    len = 0,
}

// parameters for files uploaded to agent
outParams <- {
    compression = A_LAW_COMPRESS | NORMALISE,
    width = 'b',
    samplerate = 16000,
    len = 0,
}

// buffers for sampler and fixed-frequency DAC
// buffers size must be a multiple of 256 for flash page alignment
const npts = 2048;
buffer1 <- blob(npts);
buffer2 <- blob(npts);
buffer3 <- blob(npts);

// pointers and flags for playback and recording
playbackPtr <- 0;
playing <- false;
recordPtr <- 0;
recording <- false;

// size of chunks to send between agent and device
const CHUNKSIZE = 4096;

// flag for new message downloaded from the agent
newMessage <- false;
// flag for new message waiting to go up to the agent
uploadReady <- false;

/* SAMPLER AND FIXED-FREQUENCY DAC -------------------------------------------*/

// callback and buffers for the sampler
function samplesReady(buffer, length) {
    if (length > 0) {
        // got a buffer
        // we can't write the whole buffer in at once; it has to be written to flash in pages (256 bytes each)
        for (local i = 0; i < length; i+=256) {
            local leftInBuffer = length - buffer.tell();
            if (leftInBuffer < 256) {
                flash.write(((46*64000)+(recordPtr+i)), buffer.readblob(leftInBuffer));
            } else {
                flash.write(((46*64000)+(recordPtr+i)), buffer.readblob(256));
            }
        }
        // advance the record pointer
        recordPtr += length;
        // reset the handle on the buffer; the sampler will pick it up again as it is needed
        buffer.seek(0,'b');
    } else {
        server.log("Device: Sampler Buffer Overrun");
        return;
    }
}

function finishRecording() {
    server.log("Device: done recording, stopping.");
    // put the flash to sleep to save power
    flash.sleep();
    // remember how long the recorded buffer is
    outParams.len = recordPtr;
    // reset the record pointer; we'll use it to walk through flash and upload the message to the agent
    recordPtr = 0;
    // signal to the agent that we're ready to upload this new message
    agent.send("newMessage", outParams);
    // the agent will call back with a "pull" request, at which point we'll read the buffer out of flash and upload
}

function stopSampler() {
    if (recording) {
        server.log("Device: Stopping Sampler");
        // stop the sampler
        hardware.sampler.stop();
        // clear the recording flag
        recording = false;
        // we erase pages at startup and after upload, so we don't need to do so again here
        // disable the microphone preamp
        mic.disable();
        // the sampler will finish clearing its' buffers, so we need to wait before putting the flash back to sleep
        // and signalling the agent we're ready for upload
        imp.wakeup(((3*buffer1.len())/outParams.samplerate)+0.01, finishRecording);
    }   
}

// callback for the fixed-frequency DAC
function bufferEmpty(buffer) {
    //server.log("FFD Buffer empty");
    if (!buffer) {
        server.log("FFD Buffer underrun");
        return;
    }
    // return the pointer to the beginning of the buffer
    buffer.seek(0,'b');
    if (playbackPtr >= inParams.len) {
        server.log("Not reloading buffers; end of message");
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
    server.log("Device: loading buffers before starting playback");
    playbackPtr = 0;
    // make sure buffers' pointers are all at the beginning of the buffer
    buffer1.seek(0,'b');
    buffer2.seek(0,'b');
    buffer3.seek(0,'b');
    // for each buffer, read a chunk out of flash to fill the buffer
    // flash.read returns a blob
    buffer1.writeblob(flash.read(playbackPtr, buffer1.len()));
    playbackPtr += buffer1.len();
    buffer2.writeblob(flash.read(playbackPtr, buffer2.len()));
    playbackPtr += buffer2.len();
    buffer3.writeblob(flash.read(playbackPtr, buffer3.len()));
    playbackPtr += buffer3.len();
    
    // configure the DAC
    hardware.fixedfrequencydac.configure(hardware.pin5, inParams.samplerate,
         [buffer1,buffer2,buffer3], bufferEmpty, inParams.compression);
    server.log("Device: DAC configured");
}

function stopPlayback() {
    server.log("Device: Stopping Playback");
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

/* HARDWARE CONFIGURATION ----------------------------------------------*/

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
    } else if (recording) {
        // let the LED stay on if we're recording
        hardware.pinD.write(1);
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
            if (recording || playing) {
                server.log("Device: operation already in progress");
                return;
            }
            recordMessage();
        } else {
            // stop recording on button release
            if (recording) {
                stopSampler();
            }
        }
    }
    if (b2 != button2) {
        button2 = b2;
        if (!button2) {
            if (recording || playing) {
                server.log("Device: operation already in progress");
                return;
            }
            if (parameters.len > 0) {
                playMessage();
            }
        }
    }
}

function recordMessage() {
    server.log("Device: recording message to flash");
    // set the recording flag
    recording = true;
    // set the record pointer to zero; this points filled buffers to the proper area in flash
    recordPtr = 0;
    // wake up the flash
    flash.wake();
    // we erase pages at startup and after upload, so we don't need to do so again here
    // enable the microphone preamp
    mic.enable();
    // make sure the buffers all have their handles in the proper place
    buffer1.seek(0,'b');
    buffer2.seek(0,'b');
    buffer3.seek(0,'b');
    // configure the sampler
    hardware.sampler.configure(hardware.pin2, outParams.samplerate, [buffer1,buffer2,buffer3], 
        samplesReady, outParams.compression);
    // schedule the sampler to stop running at our max record time
    imp.wakeup(30.0, stopSampler);
    // start the sampler
    server.log("Device: recording to flash");
    hardware.sampler.start();
}

function playMessage() {
    // clear new message flag
    newMessage = false;
    server.log("Device: playing back stored message from flash");
    // wake the flash, as we'll be using it now
    flash.wake();
    // load the first set of buffers before we start the dac
    loadPlayback();
    // set the playing flag
    playing = true;
    // schedule the dac to stop running when we're done
    imp.wakeup(((inParams.len * 1.0) / (inParams.samplerate * 1.0)), stopPlayback);
    // enable the speaker
    hardware.pinB.write(1);
    // start the dac
    server.log("Device: starting the DAC");
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
        //server.log(format("Device: SPI writing %d bytes to offset 0x%06x",data.len(), offset));
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
        local start = hardware.micros();
        local timeout = 50000; // time in us
        while ((this.getStatus() & 0x01) && (hardware.micros() - start) < timeout) {
            // waiting
        }
        if ((hardware.micros() - start) > timeout) {
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
        // to read, send the read command and a 24-bit address
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
        //server.log(format("Device: erasing 4kbyte SPI Flash sector beginning at 0x%06x",addr));
        this.wrenable();
        this.select();
        spi.write(SE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        this.unselect();
        // wait for sector erase to complete
        // typ = 60ms, max = 300ms
        local start = hardware.micros();
        local timeout = 300000; // time in us
        while ((this.getStatus() & 0x01) && (hardware.micros() - start) < timeout) {
            // waiting
        }
        if ((hardware.micros() - start) > timeout) {
            server.error("Device: Timed out waiting for sector erase to finish");
            return 1;
        }
        server.log("Device: done with sector erase");
        return 0;
    }
    
    // set any 64kbyte block of flash to all 0xff
    // takes a starting address, 24-bit, MSB-first
    function blockErase(addr) {
        //server.log(format("Device: erasing 64kbyte SPI Flash block beginning at 0x%06x",addr));
        this.wrenable();
        this.select();
        spi.write(BE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        this.unselect();
        // wait for sector erase to complete
        // typ = 700ms, max = 2s
        local start = hardware.micros();
        local timeout = 2000000; // time in us
        while ((this.getStatus() & 0x01) && (hardware.micros() - start) < timeout) {
            // waiting
        }
        if ((hardware.micros() - start) > timeout) {
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
        local start = hardware.micros();
        local timeout = 50000000; // time in us
        while ((this.getStatus() & 0x01) && (hardware.micros() - start) < timeout) {
            // just wait here
        }
        if ((hardware.micros() - start) > timeout) {
            server.error("Device: Timed out waiting for chip erase to finish");
            return 1;
        }
        server.log("Device: Done with chip erase");
        return 0;
    }
    
    // erase the message portion of the SPI flash
    // 2880000 bytes is 45 64-kbyte blocks
    function erasePlayBlocks() {
        server.log("Device: clearing playback flash sectors");
        for(local i = 0; i < 46; i++) {
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
        server.log("Device: clearing recording flash sectors");
        for (local i = 46; i < 60; i++) {
            if(this.blockErase(i*64000)) {
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
agent.on("newAudio", function(parameters) {
    // set our inbound parameters to the values provided by the agent
    inParams = parameters;

    server.log(format("Device: New playback buffer in agent, len: %d bytes", inParams.len));
    // takes length of the new playback buffer in bytes
    // we have 4MB flash - with A-law compression -> 1 byte/sample -> 4 000 000 / sampleRate seconds of audio
    // @ 16 kHz -> 250 s of audio (4.16 minutes)
    // allow 3 min for playback buffer (@16kHz -> 2 880 000 bytes)
    // allow 1 min for outgoing buffer (@16kHz -> 960 000 bytes)
    if (inParams.len > 2880000) {
        server.error("Device: new audio buffer length too large ("+inParams.len+" bytes, max 2880000 bytes)");
        return 1;
    }
    // erase the message portion of the SPI flash
    // 2880000 bytes is 45 64-kbyte blocks
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
    local index = data.index;
    local chunk = data.chunk;
    server.log(format("Got buffer chunk %d from agent, len %d", index, chunk.len()));
    // stash this chunk away in flash, then pull another from the agent
    // this allows us to throttle transmission from the agent
    for (local i = 0; i < chunk.len(); i+=256) {
        local leftInChunk = chunk.len() - chunk.tell();
        if (leftInChunk < 256) {
            flash.write((index*CHUNKSIZE)+i, chunk.readblob(leftInChunk));
        } else {
            flash.write((index*CHUNKSIZE)+i, chunk.readblob(256));
        }
    }
    
    // see if we're done downloading
    if ((index+1)*CHUNKSIZE >= inParams.len) {
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

// when agent sends a "pull" request, we respond with a "push" and a chunk of recorded audio
agent.on("pull", function(size) {
    // make sure the flash is awake
    flash.wake();
    // read a chunk from flash
    local numChunks = (outParams.len / size) + 1;
    local chunkIndex = (recordPtr / size) + 1;
    local bytesLeft = outParams.len - recordPtr;
    if (bytesLeft < size) {
        size = bytesLeft;
    }
    local buffer = flash.read((46*64000)+recordPtr, size);
    // advance the pointer for the next chunk
    recordPtr += size;
    // send the buffer up to the agent
    server.log(format("Device: sending chunk %d of %d, len %d",chunkIndex, numChunks, size));
    agent.send("push", buffer);

    // if we're done uploading, clean up
    if (recordPtr >= outParams.len - 1) {
        server.log("Device: Done with audio upload, clearing flash");
        flash.eraseRecBlocks();
        flash.sleep();
        recordPtr = 0;
        outParams.len = 0;
        server.log("Device: ready.");
    }
});

/* BEGIN EXECUTION -----------------------------------------------------------*/
// instantiate class objects
mic <- microphone();
// flash constructor takes pre-configured spi bus and cs_l pin
flash <- spiFlash(hardware.spi189, hardware.pin7);
// in case this is software reload and not a full power-down reset, make sure the flash is awake
flash.wake();
// make sure the flash record sectors are clear so that we're ready to record as soon as the user requests
flash.eraseRecBlocks();
// flash initialized; put it to sleep to save power
flash.sleep();

// start polling the buttons
pollButtons(); // 100 ms polling interval

server.log("Device: ready.");