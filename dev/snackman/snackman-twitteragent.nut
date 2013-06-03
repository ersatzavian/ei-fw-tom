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

function poll() {
    server.log("Long polling");
    local req = http.get("http://demo2.electricimp.com:3077/");
    req.sendasync(handleResponse);
}

function handleResponse(res) {
    server.log(res.body);
    server.log(res.statuscode);
    if(res.statuscode == 200) {
        local body = http.jsondecode(res.body);
        local follower_count = body.followers;
        if(follower_count == 0) { follower_count = 1}; // math lol
        local seconds = 0.1+math.log(follower_count)*0.2;
        server.log(seconds);
        device.send("dispense", seconds);
    
        poll();
    } else {
        imp.wakeup(0.2, poll);
    }
}

poll();
