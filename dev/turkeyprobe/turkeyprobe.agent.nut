/* Turkey Probe Calibration Agent Firmware
 * Tom Byrne
 * 11/22/13
 */ 
 
/* CONSTS AND GLOBALS ========================================================*/ 
// Data logging to opensense
const APIKEY = "IIXRa2DQnLRkb7ZEURijBA";
const OPENSENSEURL = "http://api.sen.se/events/";
const VINFEEDID = "46459";
const VTHERMFEEDID = "46458";

// Data logging to imp server
const LOGURL = "http://demo.electricimp.com/csvlogger/csvlogger.php";
 
device.on("data",function(value) {
    // Post to demo server
    local url = LOGURL+"?name="+value.mac+"&value="+value.vin+","+value.vtherm;
    http.post(url, { "Content-Type": "text/xml" }, "").sendsync();
    // Post to opensense
    sendToOpenSense(value);
    // log for the hell of it
    server.log("Vin: "+value.vin);
    server.log("Vtherm: "+value.vtherm);
});

function sendToOpenSense(value) {
    local reqURL = OPENSENSEURL+"?sense_key="+APIKEY;
    local res1 = http.post(reqURL, {"Content-Type" : "application/json"},http.jsonencode({"feed_id" : VINFEEDID, "value" : value.vin})).sendsync();
    local res2 = http.post(reqURL, {"Content-Type" : "application/json"},http.jsonencode({"feed_id" : VTHERMFEEDID, "value" : value.vtherm})).sendsync();
    server.log("Sent Vin to OpenSense, Res: "+res1.statuscode+", Body: "+res1.body);
    server.log("Sent Vtherm to OpenSense, Res: "+res2.statuscode+", Body: "+res2.body);
}

http.onrequest(function(request, res) {
    server.log("Agent got new HTTP Request");
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (request.path == "/sleep" || request.path == "/sleep/") {
        device.send("sleep",0);
        res.send(200, "Going to Sleep");
    } else {
    	server.log("Agent got unknown request");
    	res.send(200, "OK");
    }
});

 
/* RUNTIME BEGINS HERE =======================================================*/
server.log("Turkey Probe Agent Running");

