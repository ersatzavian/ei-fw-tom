// Traffic Light Agent
// Uses Sauce to automate google directions request via the browser
// in abscense of an actual duration in current traffic in Google Directions API
// Another fine product of the first EI company hackathon, 2/19/13

local baseURL = "YOUR SHIM HERE";

// this should later be updated to self-update from run to run via server.save() and server.load()
local routeString = "5050 El Camino Real Los Altos, CA to 1675 20th Ave, San Francisco CA";

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
    imp.wakeup((20*60), getTraffic);
    
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

getTraffic();
