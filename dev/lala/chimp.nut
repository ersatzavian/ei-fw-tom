/* Lala Audio Impee

 Tom Buttner, May 2013
 Electric Imp, inc
 tom@electricimp.com
*/

/* GLOBAL CONSTANTS ---------------------------------------------------------*/
// determines size of data chunks sent to/from the agent
const CHUNKSIZE = 4096;

/* REGISTER WITH IMP SERVICE and do power-sensitive configuration -----------*/

// turn on powersave to reduce average wifi power by skipping beacons
// note that this increases network latency by up to 300 ms
imp.setpowersave(true);

// register with the imp service
imp.configure("Lala Audio Impee", [],[]);

/* GLOBAL PARAMETERS AND FLAGS ----------------------------------------------*/

// parameters for wav file are passed in from the agent
inParams <- {};

// pointers and flags for playback and recording
playbackPtr <- 0;
playing <- false;

// flag for new message downloaded from the agent
newMessage <- false;

/* PIN CONFIGURATION AND ALIASING -------------------------------------------*/
/*
 Pinout:
 1 = SPI CLK
 5 = DAC (Audio Out)
 7 = SPI CS_L
 8 = SPI MOSI
 9 = SPI MISO
*/

// SPI CS_L
hardware.pin7.configure(DIGITAL_OUT);

// configure spi bus for spi flash
hardware.spi189.configure(CLOCK_IDLE_LOW | MSB_FIRST, 15000);

// pin C makes the chimp clap
chimp <- hardware.pinC;
hardware.pinC.write(0);

/* SAMPLER AND FIXED-FREQUENCY DAC -------------------------------------------*/

// callback for the fixed-frequency DAC
function playbackBufferEmpty(buffer) {
    //server.log("Playback buffer empty");
    //server.log("Device: free memory: "+imp.getmemoryfree());
    if (!buffer) {
        if (playbackPtr >= inParams.dataChunkSize) {
            // we've just played the last buffer; time to stop the ffd
            stopPlayback();
            return;
        } else {
            server.log("FFD Buffer underrun");
            return;
        }
    }
    if (playbackPtr >= inParams.dataChunkSize) {
        server.log("Not reloading buffers; end of message");
        // we're at the end of the message buffer, so don't reload the DAC
        // the DAC will be stopped before it runs out of buffers anyway
        return;
    }
    playbackPtr += buffer.len();

    // read another buffer out of the flash and load it back into the DAC
    hardware.fixedfrequencydac.addbuffer( flash.read( playbackPtr, buffer.len() ) );
}

// prep buffers to begin message playback
function loadPlayback() {
    server.log("Device: loading buffers before starting playback");

    // advance the playback pointer to show we've loaded the first three buffers
    playbackPtr = 3*CHUNKSIZE;

    local compression = 0;
    if (inParams.compressionCode == 0x06) {
        compression = A_LAW_DECOMPRESS;
    }

    // configure the DAC
    hardware.fixedfrequencydac.configure( hardware.pin5, inParams.samplerate,
         [flash.read(0, CHUNKSIZE),
            flash.read(CHUNKSIZE, CHUNKSIZE),
            flash.read((2*CHUNKSIZE), CHUNKSIZE)],
         playbackBufferEmpty, compression );

    server.log("Device: DAC configured");
}

function stopPlayback() {
    server.log("Device: Stopping Playback");
    // stop the DAC
    hardware.fixedfrequencydac.stop();
    // disable the speaker
    speakerEnable.write(0);
    // put the flash back to sleep
    flash.sleep();
    // return the playback pointer for the next time we want to play this message (now that it's cached);
    playbackPtr = 0;
    // set the flag to show that there is no longer a playback in progress
    playing = false;
}

/* GLOBAL FUNCTIONS ----------------------------------------------------------*/

function playMessage() {
    server.log("Device: playing back stored message from flash");

    // clear new message flag
    newMessage = false;

    // wake the flash, as we'll be using it now
    flash.wake();

    // load the first set of buffers before we start the dac
    loadPlayback();

    // set the playing flag
    playing = true;

    // enable the speaker
    speakerEnable.write(1);

    // start the dac
    server.log("Device: starting the DAC");
    hardware.fixedfrequencydac.start();
}

/* CLASS DEFINITIONS ---------------------------------------------------------*/

class spiFlash {
    // MX25L3206E SPI Flash
    // Clock up to 86 MHz (we go up to 15 MHz)
    // device commands:
    static WREN     = "\x06"; // write enable
    static WRDI     = "\x04"; // write disable
    static RDID     = "\x9F"; // read identification
    static RDSR     = "\x05"; // read status register
    static READ     = "\x03"; // read data
    static FASTREAD = "\x0B"; // fast read data
    static RDSFDP   = "\x5A"; // read SFDP
    static RES      = "\xAB"; // read electronic ID
    static REMS     = "\x90"; // read electronic mfg & device ID
    static DREAD    = "\x3B"; // double output mode, which we don't use
    static SE       = "\x20"; // sector erase (Any 4kbyte sector set to 0xff)
    static BE       = "\x52"; // block erase (Any 64kbyte sector set to 0xff)
    static CE       = "\x60"; // chip erase (full device set to 0xff)
    static PP       = "\x02"; // page program 
    static RDSCUR   = "\x2B"; // read security register
    static WRSCUR   = "\x2F"; // write security register
    static ENSO     = "\xB1"; // enter secured OTP
    static EXSO     = "\xC1"; // exit secured OTP
    static DP       = "\xB9"; // deep power down
    static RDP      = "\xAB"; // release from deep power down

    // offsets for the record and playback sectors in memory
    // 64 blocks
    // first 48 blocks: playback memory
    // blocks 49 - 64: recording memory
    static totalBlocks = 64;
    static playbackBlocks = 48;
    static recordOffset = 0x2EE000;
    
    // manufacturer and device ID codes
    mfgID = null;
    devID = null;
    
    // spi interface
    spi = null;
    cs_l = null;

    // constructor takes in pre-configured spi interface object and chip select GPIO
    constructor(spiBus, csPin) {
        this.spi = spiBus;
        this.cs_l = csPin;

        // read the manufacturer and device ID
        cs_l.write(0);
        spi.write(RDID);
        local data = spi.readblob(3);
        this.mfgID = data[0];
        this.devID = (data[1] << 8) | data[2];
        cs_l.write(1);
    }
    
    function wrenable() {
        cs_l.write(0);
        spi.write(WREN);
        cs_l.write(1);
    }
    
    function wrdisable() {
        cs_l.write(0);
        spi.write(WRDI);
        cs_l.write(1);
    }
    
    // pages should be pre-erased before writing
    function write(addr, data) {
        wrenable();
        
        // check the status register's write enabled bit
        if (!(getStatus() & 0x02)) {
            server.error("Device: Flash Write not Enabled");
            return 1;
        }
        
        cs_l.write(0);
        // page program command goes first
        spi.write(PP);
        // followed by 24-bit address
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        spi.write(data);
        cs_l.write(1);
        
        // wait for the status register to show write complete
        // typical 1.4 ms, max 5 ms
        local timeout = 50000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        
        return 0;
    }

    // allow data chunks greater than one flash page to be written in a single op
    function writeChunk(addr, data) {
        // separate the chunk into pages
        data.seek(0,'b');
        for (local i = 0; i < data.len(); i+=256) {
            local leftInBuffer = data.len() - data.tell() - 1;
            if (leftInBuffer < 256) {
                flash.write((addr+i),data.readblob(leftInBuffer));
            } else {
                flash.write((addr+i),data.readblob(256));
            }
        }
    }

    function read(addr, bytes) {
        cs_l.write(0);
        // to read, send the read command and a 24-bit address
        spi.write(READ);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        local readBlob = spi.readblob(bytes);        
        cs_l.write(1);
        return readBlob;
    }
    
    function getStatus() {
        cs_l.write(0);
        spi.write(RDSR);
        local status = spi.readblob(1);
        cs_l.write(1);
        return status[0];
    }
    
    function sleep() {
        cs_l.write(0);
        spi.write(DP);
        cs_l.write(1);     
   }
    
    function wake() {
        cs_l.write(0);
        spi.write(RDP);
        cs_l.write(1);
    }
    
    // erase any 4kbyte sector of flash
    // takes a starting address, 24-bit, MSB-first
    function sectorErase(addr) {
        this.wrenable();
        cs_l.write(0);
        spi.write(SE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        cs_l.write(1);
        // wait for sector erase to complete
        // typ = 60ms, max = 300ms
        local timeout = 300000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        return 0;
    }
    
    // set any 64kbyte block of flash to all 0xff
    // takes a starting address, 24-bit, MSB-first
    function blockErase(addr) {
        //server.log(format("Device: erasing 64kbyte SPI Flash block beginning at 0x%06x",addr));
        this.wrenable();
        cs_l.write(0);
        spi.write(BE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        cs_l.write(1);
        // wait for sector erase to complete
        // typ = 700ms, max = 2s
        local timeout = 2000000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        return 0;
    }
    
    // clear the full flash to 0xFF
    function chipErase() {
        server.log("Device: Erasing SPI Flash");
        cs_l.write(0);
        this.select();
        spi.write(CE);
        cs_l.write(1);
        // chip erase takes a *while*
        // typ = 25s, max = 50s
        local timeout = 50000000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        server.log("Device: Done with chip erase");
        return 0;
    }
    
    // erase the message portion of the SPI flash
    // 2880000 bytes is 45 64-kbyte blocks
    function erasePlayBlocks() {
        server.log("Device: clearing playback flash sectors");
        for(local i = 0; i < this.playbackBlocks; i++) {
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
        for (local i = this.playbackBlocks; i < this.totalBlocks; i++) {
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
    // turn off power save for latency
    imp.setpowersave(false);
    // set our inbound parameters to the values provided by the agent
    inParams = parameters;

    server.log(format("Device: New playback buffer in agent, len: %d bytes", inParams.dataChunkSize));
    // takes length of the new playback buffer in bytes
    // we have 4MB flash - with A-law compression -> 1 byte/sample -> 4 000 000 / sampleRate seconds of audio
    // @ 16 kHz -> 250 s of audio (4.16 minutes)
    // allow 3 min for playback buffer (@16kHz -> 2 880 000 bytes)
    // allow 1 min for outgoing buffer (@16kHz -> 960 000 bytes)
    if (inParams.dataChunkSize > 2880000) {
        server.error("Device: new audio buffer length too large ("+inParams.dataChunkSize+" bytes, max 2880000 bytes)");
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

    flash.writeChunk((index*CHUNKSIZE), chunk);
    
    // see if we're done downloading
    if ((index+1)*CHUNKSIZE >= inParams.dataChunkSize) {
        // we're done. set the global new message flag
        // this will cause the LED to blink (in the button-poll function) as well
        newMessage = true;
        // we can put the flash back to sleep now to save power
        flash.sleep();
        server.log("Device: New message downloaded to flash");
        imp.setpowersave(true);
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
    local buffer = flash.read(flash.recordOffset+recordPtr, size);
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
        imp.setpowersave(true);
        server.log("Device: ready.");
    }
});

// allow agent to start and stop the chimp
agent.on("chimp", function(value)) {
    if (value) {
        chimp.write(1);
    } else {
        chimp.write(0);
    }
}

/* BEGIN EXECUTION -----------------------------------------------------------*/
// flash constructor takes pre-configured spi bus and cs_l pin
flash <- spiFlash(hardware.spi189, hardware.pin7);
// in case this is software reload and not a full power-down reset, make sure the flash is awake
flash.wake();
// flash initialized; put it to sleep to save power
flash.sleep();

server.log("Device: ready.");