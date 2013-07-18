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

// Traffic Light Agent
// Uses Sauce to automate google directions request via the browser
// in abscense of an actual duration in current traffic in Google Directions API
// Another fine product of the first EI company hackathon, 2/19/13

local baseURL = "http://demo2.electricimp.com/cgi-bin/gmaps.rb";

// this should later be updated to self-update from run to run via server.save() and server.load()
local routeString = "5050 El Camino Real Los Altos CA to 1675 20th Ave San Francisco ";

http.onrequest(function(request,res){
    server.log("Agent got request: "+request.body);
    if (request.body != "") {
        try {
            routeString = split(request.body,"\n")[3];
            server.log("Agent: updated route string to: "+routeString);
            local successPage = "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>Update Route</title><meta name=\"author\" content=\"\"></head><body><h3>Accepted: "+routeString+"</h3></body>";
            if (!getTraffic()) {
                res.send(200, successPage);
            } else {
                res.send(400, "Error, not updated.");
            }
        } catch (err) {
            server.log("Agent: unknown request: "+request.body);
            res.send(400, "Error, not updated.");
        }
    } else {
        local updateRoutePage = "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>Update Route</title><meta name=\"author\" content=\"\"></head><body><form enctype=\"multipart/form-data\"method=\"post\"><input type=\"text\"name=\"routeString\"><br><input type=\"submit\" name=\"Update\"></body>";
        res.send(200, updateRoutePage);
    }
});

function getTraffic () {
    local now = date(time(),'l');
    //server.log("The hour is "+now.hour+" GMT");
    local localHour = now.hour - 7;
    server.log("The local hour is "+localHour+" PST");
    if ((localHour > 9) || (localHour < 6)) {
        server.log("Outside of peak traffic window");
        if (localHour < 6) {
            local sleepTime = (((6 - localHour) * 60) - now.min);
            server.log("Sleeping for "+sleepTime+" minutes");
            imp.wakeup((sleepTime * 60), getTraffic);
        } else {
            // it's after 10
            local sleepTime = ((6*60) + ((24 - localHour)*60) - now.min);
            server.log("Sleeping for "+sleepTime+" minutes");
            imp.wakeup((sleepTime * 60), getTraffic);
        }
    } else {
        imp.wakeup((20*60), getTraffic);
        // it's between 6 and 10 AM, go get the data.
        local req = http.post(baseURL, {}, http.urlencode({route=routeString}));
        server.log("Agent: Getting new traffic data.");
        local resp = req.sendsync();
        local trafficTable = http.jsondecode(resp.body);
        try {
            server.log(format("Agent: Travel time for %s: %s (%s)",routeString,trafficTable.time,trafficTable.color));
            device.send("trafficUpdate",trafficTable.color);
        } catch (err) {
            server.log("Error parsing traffic data: "+resp.body)
            return 1;
        }
        return 0;
    }
}

getTraffic();
