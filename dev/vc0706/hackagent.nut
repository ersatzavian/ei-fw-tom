/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

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