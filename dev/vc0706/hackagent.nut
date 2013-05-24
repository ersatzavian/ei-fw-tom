requests <- []
 
jpeg_buffer <- null
impeeid <- null;
 
device.on("id", function(val) {
    impeeid = val;
});
 
device.on("jpeg_start", function(size) {
    jpeg_buffer = blob(size);
});
 
device.on("jpeg_chunk", function(v) {
    local offset = v[0];
    local b = v[1];
    for(local i = offset; i < (offset+b.len()); i++) {
        if(i < jpeg_buffer.len()) {
            jpeg_buffer[i] = b[i-offset];
        }
    }
});
 
device.on("jpeg_end", function(v) {
    local s = "";
    foreach(chr in jpeg_buffer) {
        s += format("%c", chr);
    }
    local reqData = {
        image = s,
        source = impeeid,
    }
    local req = http.post("http://demo2.electricimp.com/hackathon/upload3.php", {"Host":impeeid.tostring()}, s);
    req.sendsync();
    foreach(res in requests) {
        res.header("Location", "http://demo2.electricimp.com/hackathon/camera.jpg");
        res.send(302, "Found\n");
    }
    server.log("Agent: Latest Photo Sent.");
});
 
http.onrequest(function(req, res) {
    server.log("Got new request - taking picture");
    device.send("take_picture", 1);
    requests.push(res);
});

function snap() {
   imp.wakeup(60, snap);
   device.send("take_picture",1);
}

snap();