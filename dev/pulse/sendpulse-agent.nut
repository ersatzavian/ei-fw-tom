server.log("Sendpulse agent started");

http.onrequest( function(req,res) {
    if (request.path == "/pulse") {
        server.log("Agent got pulse request");
        local len = request.body;
        device.send("pulse", len);
        res.send(200, "OK");
    } else if (request.path == "/double") {
        server.log("Agent got double pulse request");
        local params = request.body.split(",");
        local sendParams = {};
        sendParams.len <- params[0];
        sendParams.gap <- params[1];
        device.send("doublepulse", sendParams);
        res.send(200, "OK");
    } else {
        server.log("Agent got empty request");
        res.send(200, "OK");
    }
});