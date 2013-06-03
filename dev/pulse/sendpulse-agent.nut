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