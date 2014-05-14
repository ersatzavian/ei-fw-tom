// simple audio playback example

/* GLOBAL CONSTANTS ---------------------------------------------------------*/
const BUFFERSIZE  = 8192; // size of data chunks sent to/from the agent

/* CLASS AND FUNCTION DEFINITIONS ----------------------------------------------------------*/

// Audio playback class
class Playback {
    dac             = null; // audio output pin
    amp_en          = null; // amplifier enable pin
    flash           = null; // spi flash object, pre-contructed
    sampleroptions  = null;
    samplewidth     = null;
    samplerate      = null;
    compression     = null;
    playing         = false; // flag for callbacks
    playback_ptr    = 0;     // pointer for callbacks
    buffersize      = null;
    len             = null;

    constructor(_dac, _amp_en, _flash, _buffersize) {
        this.dac            = _dac;
        this.amp_en         = _amp_en;
        this.flash          = _flash;
        this.buffersize     = _buffersize;
    }

    function isPlaying() {
        return playing;
    }

    function setSamplerate(_samplerate) {
        this.samplerate = _samplerate;
    }

    function setCompression(_compression) {
        this.compression = _compression;
    }

    function setLength(_len) {
        this.len = _len;
    }
    
    function getLength() {
        return len;
    }

    // helper: callback, called when the FFD consumes a buffer
    function bufferEmpty(buffer) {
        if (!buffer) {
            if (playback_ptr >= len) {
                // we've just played the last buffer; time to stop the ffd
                this.stop();
                return;
            } else {
                server.log("FFD Buffer underrun");
                return;
            }
        }
        if (playback_ptr >= len) {
            // we're at the end of the message buffer, so don't reload the DAC
            // the DAC will be stopped before it runs out of buffers anyway
            return;
        }

        // read another buffer out of the flash and load it back into the DAC
        hardware.fixedfrequencydac.addbuffer( flash.read(playback_ptr, buffer.len()) );
        playback_ptr += buffer.len();
    }

    // helper: prep buffers to begin message playback
    function load() {
        // advance the playback pointer to show we've loaded the first three buffers
        playback_ptr = 3 * buffersize;
        hardware.fixedfrequencydac.configure(dac, samplerate, [flash.read(0,buffersize),flash.read(buffersize, buffersize),flash.read((2 * buffersize), buffersize)], bufferEmpty.bindenv(this), compression);
    }

    // start playback
    function start() {
        flash.wake();
        // load the first set of buffers before we start the dac
        this.load();
        playing = true;
        // start the dac before enabling the speaker to avoid a "pop"
        hardware.fixedfrequencydac.start();
        amp_en.write(1);
    }

    // stop playback
    function stop() {
        hardware.fixedfrequencydac.stop();
        amp_en.write(0);
        flash.sleep();
        playback_ptr = 0;
        playing = false;
        server.log("Playback stopped.");
    }
}

playback.start();

/* AGENT CALLBACK HOOKS ------------------------------------------------------*/

// allow the agent to signal that it's got new audio data for us, and prepare for download
agent.on("new_audio", function(params) {
    
    server.log(format("Device: New playback buffer in agent, len: %d bytes", params.data_chunk_size));
    // takes length of the new playback buffer in bytes
    // we have 4MB flash - with A-law compression -> 1 byte/sample -> 4 000 000 / sampleRate seconds of audio
    // @ 16 kHz -> 250 s of audio (4.16 minutes)
    // allow 3 min for playback buffer (@16kHz -> 2 880 000 bytes)
    // allow 1 min for outgoing buffer (@16kHz -> 960 000 bytes)
    if (params.data_chunk_size > 2880000) {
        server.error(format("Device: new audio buffer length too large (%d bytes, max %d bytes)",params.data_chunk_size,MAX_DATA_CHUNK_SIZE));
        return 1;
    }
    // erase the message portion of the SPI flash
    // 2880000 bytes is 45 64-kbyte blocks
    flash.wake();
    flash.erasePlayBlocks();
    playback.setLength(params.data_chunk_size);
    if (params.compression_code == 0x06) {
        playback.setCompression(AUDIO | A_LAW_COMPRESS);
    } else {
        playback.setCompression(AUDIO);
    }
    playback.setSamplerate(params.samplerate);

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
    local buffer = data.chunk;
    // server.log(format("Got buffer chunk %d from agent, len %d", index, buffer.len()));
    // stash this chunk away in flash, then pull another from the agent

    flash.writeChunk((index*buffer.len()), buffer);
    
    // see if we're done downloading
    if ((index + 1)*buffer.len() >= playback.getLength()) {
        // we're done.
        imp.setpowersave(true);
        new_message = true;
        blink_led(true);
        flash.sleep();
        server.log("Device: New message downloaded to flash");
    } else {
        // not done yet, get more data
        agent.send("pull", buffer.len());
    }
});


/* BEGIN EXECUTION -----------------------------------------------------------*/
server.log("Started. Free memory: "+imp.getmemoryfree());

dac         <- hardware.pin5;
playback    <- Playback(dac, amp_en, flash, CHUNKSIZE);
