// Lala test agent.
// Primary purpose in life: collect audio buffers, paste them together, 
// send them along to a server for download

server.log("Lala Walkie-Talkie Agent Running");

// URL to post finish messages up to; this script will 
// re-post them down to a list of agent URLs. We'll get our own message back, but so will everyone else
msgSrvrURL <- "http://demo2.electricimp.com/lala/lalaHub.php";
// start the audio buffer as a small blob; it'll grow as needed
audio <- blob(500);
bufferCount <- 0;

// handle new audio buffers from the device as they're recorded
device.on("audioBuffer", function(data) {
    //server.log(typeof(data));
    audio.writeblob(data.readblob(data.len()));
    bufferCount++;
});

// write to the log and post the full buffer when the device signals it's done recording
device.on("audioDone", function(value) {
    server.log("Agent got "+bufferCount+" audio buffers from device ("+audio.len()+" bytes)");
    postMessage();
});

// while the imp is doing playback, it will request more data as it empties its playback buffers
// serve up more data for playback on request
device.on("pull", function(value) {
    server.log("Agent: device requested audio for playback");
    local chunk = blob(2000);
    // if we've got enough data left in the message to take a full chunk, do
    if ((audio.tell() - audio.len()) > chunk.len()) {
        chunk.writeblob(audio.readblob(chunk.len()));
    } else {
        // otherwise, grab from here to the end, send it, then tell the imp it's done with playback
        chunk.writeblob(audio.readblob(audio.len()-audio.tell()));
        imp.wakeup(0.25, function() {
            // this will be sent after the last buffer goes out and the imp has a chance to process it
            device.send("playDone", 0);
        });
    }
    // send the chunk down
    device.send("playData", chunk);
});

// post audio data to server and clear local buffer
function postMessage() {
    server.log("Agent: posting message to server");
    // audio data has to be base-64 encoded to upload
    local req = http.post(msgSrvrURL, {"Access-Control-Allow-Origin": "*"}, http.base64encode(audio));
    local res = req.sendsync();
    server.log("Agent: posted, status: "+res.statuscode+", body: "+res.body);
    // clear the local buffer counter and audio file
    bufferCount = 0;
    audio = blob(2000);
}

// respond to requests from the internet. This is primarily to take in new messages from the server via POST
http.onrequest(function(request, res) {
    server.log("Agent got new request");
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    
    if (request.path == "/newmsg") {
        if (request.body == "") {
            server.log("Agent got empty request to newmsg");
            // handle preflights with null request body
        } else {
            // audio data comes in base 64 encoded; decode it
            // NOTE: bug here: base64decode returns a string, which breaks this. Added to Pivotal.
            audio = http.base64decode(request.body);
            server.log("Agent got message of type "+typeof(audio));
            // return the pointer to the beginning of the audio buffer
            audio.seek(0,'b');
            server.log("Agent: got new audio message, length: "+audio.len());
            // inform the device there's a new message waiting for playback
            device.send("newMsg", 0);
        }
    }
    // send the response to requests
    res.send(200, "OK");
});