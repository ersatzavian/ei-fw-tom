// Lala test agent.
// Primary purpose in life: collect audio buffers, paste them together, 
// send them along to a server for download

server.log("Lala Test Agent Running");

audio <- blob(20000);
bufferCount <- 0;

device.on("audioBuffer", function(data) {
    audio.writeblob(data.readblob(data.len()));
    bufferCount++;
});

device.on("audioDone", function(value) {
    server.log("Agent got "+bufferCount+" audio buffers from device ("+audio.len()+" bytes)");
});

http.onrequest(function(request, res) {
    server.log("Agent got new request");
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    res.header("Content-Disposition"," attachment; filename=\"audio.pcm\"");
    local audioData = http.base64encode(audio);
    res.send(200, audioData);
    audio.seek(0,'b');
    server.log("Agent sent audio data");
});