requests <- []

jpeg_buffer <- null

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
    foreach(res in requests) {
        res.header("Content-Type", "image/jpeg");
        res.send(200, s);
    }
    /*
    local req = http.post("http://demo2.electricimp.com/hackathon/upload.php", {}, s);
    req.sendsync();
    foreach(res in requests) {
        res.header("Location", "http://demo2.electricimp.com/hackathon/camera.jpg");
        res.send(302, "Found\n");
    }
    */
    server.log(format("Agent: JPEG Sent (%d bytes)"s.len()));
});

http.onrequest(function(req, res) {
    device.send("take_picture", 1);
    requests.push(res);
});