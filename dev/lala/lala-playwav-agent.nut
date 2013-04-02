// wav upload agent for Lala audio board

// buffer for storing audio data downloaded from the server
parameters <- {
    fmtChunkOffset = 0,
    fmtChunkDataSize = 0,
    dataChunkOffset = 0,
    dataChunkSize = 0,
    compressionCode = 0,
    width = 0,
    channels = 0,
    samplerate = 0,
    avgBytesPerSec = 0,
    blockAlign = 0,
    sigBits = 0,
    len = 0,
}
wavBlob <- blob(500000);
// new message flag so that we can respond appropriately when polled
newMessage <- false;

// size of chunks to pull from device when fetching new recorded message
CHUNKSIZE <- 8192;

server.log("Lala wav playback agent running");
server.log("Agent: free memory: "+imp.getmemoryfree());

function fetch(url) {
    offset <- 0;
    const LUMP = 4096;
    server.log("Fetching content from "+url);
    do {
        response <- http.get(url, 
            {Range=format("bytes=%u-%u", offset, offset+LUMP-1) }
        ).sendsync();
        got <- response.body.len();
        
        /* Since the response is a string, use string "find" to locate
        chunk offsets before we convert to a blob
        */
        local fmtOffset = response.body.find("fmt ");
        if (fmtOffset) {
            parameters.fmtChunkOffset = fmtOffset + offset;
            server.log("Located format chunk at offset "+parameters.fmtChunkOffset);
        }
        local dataOffset = response.body.find("data");
        if (dataOffset) {
            parameters.dataChunkOffset = dataOffset + offset;
            server.log("Located data chunk at offset "+parameters.dataChunkOffset);
        }
        
        offset += got;
        addToBlob(response.body);
        //server.log(format("Downloading (%d bytes)",offset));
    } while (response.statuscode == 206 && got == LUMP);
    
    server.log("Done, got "+offset+" bytes total");
}

function addToBlob(str) {
    for (local i = 0; i < str.len(); i++) {
        wavBlob.writen(str[i],'b');
    }
}

function playTest() {
    server.log("Agent: running play test");
    // blob to hold audio data exists at global scope
    wavBlob.seek(0,'b');
    
    //Download audio from the electric imp server
    fetch("http://demo2.electricimp.com/wav/dynamo_alaw.wav");
    //fetch("http://demo2.electricimp.com/wav/extra_poetic_alaw.wav");
    //fetch("http://demo2.electricimp.com/wav/shortchirp.wav");
    
    if (getFormatData()) {
        server.log("Agent: failed to get audio format data for file");
        return 1;
    }
    
    // seek to the beginning of the audio data chunk
    wavBlob.seek(parameters.dataChunkOffset+4,'b');
    parameters.len = wavBlob.readn('i');
    server.log(format("Agent: at beginning of audio data chunk, length %d", parameters.len));
    
    // Notifty the device we have audio waiting, and wait for a pull request to serve up data
    device.send("newAudio", parameters.len);
}

function getFormatData() {
    local startPos = wavBlob.tell();
    wavBlob.seek(parameters.fmtChunkOffset+4,'b');

    parameters.fmtChunkDataSize = wavBlob.readn('i');
    parameters.compressionCode = wavBlob.readn('w');
    if (parameters.compressionCode == 0x01) {
        // 16-bit PCM
        parameters.width = 'w';
    } else if (parameters.compressionCode == 0x06) {
        // A-law
        parameters.width = 'b';
    } else {
        server.log(format("Audio uses unsupported compression code 0x%02x",
            parameters.compressionCode));
        return 1;
    }
    parameters.channels = wavBlob.readn('w');
    parameters.samplerate = wavBlob.readn('i');
    parameters.avgBytesPerSec = wavBlob.readn('i');
    parameters.blockAlign = wavBlob.readn('w');
    parameters.sigBits = wavBlob.readn('w');

    server.log(format("Compression Code: %x", parameters.compressionCode));
    server.log(format("Channels: %d",parameters.channels));
    server.log(format("Sample rate: %d", parameters.samplerate));

    // return the file pointer
    wavBlob.seek(startPos, 'b');

    return 0;
}

/* HTTP REQUEST HANDLER ------------------------------------------------------*/
http.onrequest(function(request, res) {
    server.log("Agent got new HTTP Request");
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (request.path == "/getmsg") {
        if (newMessage) {
            server.log("Agent: Responding with new audio buffer, len "+parameters.len);
            wavBlob.seek(0,'b');
            res.send(200, http.base64encode(wavBlob.readblob(parameters.len)));
            newMessage = false;
        } else {
            server.log("Agent: Responding with 204");
            res.send(204, "No new messages");
        }
    }
    
    // send a generic response to prevent browser hang
    res.send(200, "OK");
});

/* DEVICE CALLBACK HOOKS -----------------------------------------------------*/
// let the device initiate the playback test
device.on("playtest", function(value) {
    playTest();
});

// serve up data to the device when requested
device.on("pull", function(size) {

    local buffer = blob(size);
    // make a "sequence number" out of our position in audioData
    local chunkIndex = (wavBlob.tell()-parameters.dataChunkOffset) / size;
    server.log("Agent: sending chunk "+chunkIndex+" of "+(parameters.len/size));
    
    // wav data is interlaced
    // skip channels if there are more than one; we'll always take the first
    local max = size;
    local bytesLeft = (parameters.len - (wavBlob.tell() - parameters.dataChunkOffset + 8)) / parameters.channels;
    if (parameters.width == 'w') {
        // if we're A-law encoded, it's 1 byte per sample; if we're 16-bit PCM, it's two
        bytesLeft = bytesLeft * 2;
    }
    if (size > bytesLeft) {
        max = bytesLeft;
    }
    for (local i = 0; i < max; i += parameters.channels) {
        buffer.writen(wavBlob.readn(parameters.width), parameters.width);
    } 

    // pack up the sequence number and the buffer in a table
    local data = {
        index = chunkIndex,
        chunk = buffer,
    }
    
    // send the data out to the device
    device.send("push", data);
});

device.on("newMessage", function(length) {
    server.log("Agent: device signaled new message ready, length "+length);
    newMessage = true;
    // prep our buffer to begin writing in chunks from the device
    wavBlob.seek(0,'b');
    // use the file parameters table for pertinent information
    parameters.len = length;
    // tell the device we're ready to receive data; device will respond with "push" and a blob
    device.send("pull", CHUNKSIZE);
});

device.on("push", function(chunk) {
    local numChunks = (parameters.len / CHUNKSIZE) + 1;
    local index = (wavBlob.tell() / CHUNKSIZE) + 1;
    server.log(format("Agent: got chunk %d of %d, len %d", index, numChunks, chunk.len()));
    wavBlob.writeblob(chunk);
    if (index < numChunks) {
        // there's more file to fetch
        device.send("pull", CHUNKSIZE);
    } else {
        server.log("Agent: Done fetching recorded buffer from device");
    }
});