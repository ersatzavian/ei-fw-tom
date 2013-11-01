/* 
 * Vanessa Reference Design Wake-Cycle Test Agent Firmware 
 * Display not written on wakes.
 * Tom Byrne
 * tom@electricimp.com
 * 10/23/2013
 */

server.log("Vanessa Agent Started.");

// Data logging to opensense
const APIKEY = "IIXRa2DQnLRkb7ZEURijBA";
const OPENSENSEURL = "http://api.sen.se/events/";
const VBATFEEDID = "44860";

// Data logging to imp server
const LOGURL = "http://demo.electricimp.com/csvlogger/csvlogger.php";

// post every opensense_dec-th value to opensense
const opensense_dec = 19;
opensense_cnt <- 0; 
 
device.on("vbat",function(value) {
    local url = LOGURL+"?name="+value.mac+"&value="+value.vbat;
    http.post(url, { "Content-Type": "text/xml" }, "").sendsync();
    
    // if this is the opensense_dec-th value, send it to opensense
    if (opensense_cnt == 0) {
        sendToOpenSense(value.vbat);
        opensense_cnt = opensense_dec;
    } else {
        opensense_cnt--;
    }

    server.log("VBat: "+value.vbat);
});

function sendToOpenSense(value) {
    local datapoint = {"feed_id" : VBATFEEDID, "value" : value};
    
    local reqURL = OPENSENSEURL+"?sense_key="+APIKEY;
    local req = http.post(reqURL, {"Content-Type" : "application/json"},http.jsonencode(datapoint));
    local res = req.sendsync();
    server.log("Sent to OpenSense, Res: "+res.statuscode+", Body: "+res.body);
}