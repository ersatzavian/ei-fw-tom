// STM32 microprocessor firmware updater agent
// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// GLOBALS AND CONSTS ----------------------------------------------------------

agent_buffer <- blob(2);
fetch_url <- "";
fetch_ptr <- 0;

// DEVICE CALLBACKS ------------------------------------------------------------

device.on("pull", function(buffersize) {
    if (fetch_url != "") {
        local buffer = blob(buffersize);
        buffer.writestring(http.get(fetch_url, { Range=format("bytes=%u-%u", fetch_ptr, fetch_ptr + buffersize) }).sendsync().body);
        device.send("push", buffer);
    } else {
        server.log(format("Device requested %d bytes",buffersize));
        device.send("push", agent_buffer.readblob(buffersize));
    }
});

device.on("fw_update_complete", function(success) {
    if (success) {
        server.log("FW Update Successfully Completed.");
    } else {
        server.log("FW Update Failed.");
    }
});

// HTTP REQUEST HANDLER --------------------------------------------------------

http.onrequest(function(req, res) {
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    
    if (req.path == "/push" || req.path == "/push/") {
        server.log("Agent received new firmware, starting update");
        server.log(req.body.len());
        agent_buffer = blob(req.body.len());
        agent_buffer.writestring(req.body);
        agent_buffer.seek(0,'b');
        device.send("load_fw", agent_buffer.len());
        res.send(200, "OK");
    } else if (req.path == "/fetch" || req.path == "/fetch/") {
        local fw_len = 0;
        if ("len" in req.query) {
            fw_len = req.query.len.tointeger();
        } else {
            res.send(400, "Request must include length as query parameter (&len=<length in bytes>)");
            return;
        }
        if ("url" in req.query) {
            fetch_url = req.query.url;
            fetch_ptr = 0;
            device.send("load_fw", fw_len);
            res.send(200, "OK");
            server.log(format("Fetching new firmware (%d bytes) from %s",fw_len,fetch_url));
        } else {
            res.send(400, "Request must include source url to fetch image from.");
        }
    } else {
        // send a response to prevent request hang
        res.send(200, "OK");
    }
});
    
// MAIN ------------------------------------------------------------------------

server.log("Agent Started. Free Memory: "+imp.getmemoryfree());