// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

const PUBKEY = "demo";
const SUBKEY = "demo";
SECRETKEY <- split(http.agenturl(), "/").top();

class PubNub {
    _pubNubBase = "https://pubsub.pubnub.com";
    
    _publishKey = null;
    _subscribeKey = null;
    _secretKey = null;
    _uuid = null
    
    constructor(publishKey, subscribeKey, secretKey, uuid = null) {
        this._publishKey = publishKey;
        this._subscribeKey = subscribeKey;
        this._secretKey = secretKey;
        
        if (uuid == null) uuid = split(http.agenturl(), "/").top();
        this._uuid = uuid;
    }
    
        
    /******************** PRIVATE FUNCTIONS (DO NOT CALL) *********************/
    function _defaultPublishCallback(err, data) {
        if (err) {
            server.log(err);
            return;
        }
        if (data[0] != 1) {
            server.log("Error while publishing: " + data[1]);
        } else {
            server.log("Published data at " + data[2]);
        }
    }
    
    /******************* PUBLIC MEMBER FUNCTIONS ******************************/
    function publish(channel, data, callback = null) {
        local url = format("%s/publish/%s/%s/%s/%s/%s/%s?uuid=%s", _pubNubBase, _publishKey, _subscribeKey, _secretKey, channel, "0", http.jsonencode(data), _uuid);
        
        http.get(url).sendasync(function(resp) {
            local err = null;
            local data = null;
            
            // process data
            if (resp.statuscode != 200) {
                err = format("%i - %s", resp.statuscode, resp.body);
            } else {
                try {        
                    data = http.jsondecode(resp.body);
                } catch (ex) {
                    err = ex;
                }
            }
            
            // callback
            if (callback != null) callback(err, data);
            else _defaultPublishCallback(err, data);
        }.bindenv(this));
    }
    
    function subscribe(channels, callback, tt = 0) {
        local channellist = "";
        local channelidx = 1;
        foreach (channel in channels) {
            channellist += channel;
            if (channelidx < channels.len()) {
                channellist += ",";
            }
            channelidx++;
        }
        local url = format("%s/subscribe/%s/%s/0/%s?uuid=%s", _pubNubBase, _subscribeKey, channellist, tt.tostring(), _uuid);
        http.get(url).sendasync( function(resp) {
            //server.log(resp.body);
            local err = null;
            local data = null;
            local messages = null;
            local rxchannels = null;
            local tt = null;
            local result = {};
            
            // process data
            if (resp.statuscode != 200) {
                err = format("%i - %s", resp.statuscode, resp.body);
            } else {
                try {        
                    data = http.jsondecode(resp.body);
                    messages = data[0];
                    tt = data[1];
                    // [["ch1_msg", "ch2_msg"], 14066688760709590, "ch1, ch2"]
                    if (data.len() > 2) {
                        rxchannels = split(data[2],",");
                        local chidx = 0;
                        foreach (ch in rxchannels) {
                            result[ch] <- messages[chidx++]
                        }
                    } else { 
                        if (messages.len() == 0) {
                            // successfully subscribed; no data yet
                        } else  {
                            // no rxchannels, so we have to fall back on the channel we called with
                            result[channels[0]] <- messages[0];
                        } 
                    }
                } catch (ex) {
                    err = ex;
                }
            }
            
            // re-start polling loop
            // channels and callback are still in scope because we got here with bindenv
            this.subscribe(channels,callback,tt);
            // callback
            callback(err, result, tt);
        }.bindenv(this));
    }
    
    function history(channel, limit, callback) {
        local url = format("%s/history/%s/%s/0/%d", _pubNubBase, _subscribeKey, channel, limit);
        
        http.get(url).sendasync(function(resp) {
            local err = null;
            local data = null;
            
            // process data
            if (resp.statuscode != 200) {
                err = format("%i - %s", resp.statuscode, resp.body);
            } else {
                data = resp.body;
            }
            
            // callback
            callback(err, data);
            
        }.bindenv(this));
    }
}

device.on("current", function(val) {
    pubNub.publish("temp_c",format("%0.2f",val));
});

function postdummy() {
    imp.wakeup(10, postdummy);
    pubNub.publish("demo","hi at "+time());
}

// publish key, subscribe key, secret key, [uuid]
// if no uuid is provided, the agent's external unique ID is used
pubNub <- PubNub(PUBKEY, SUBKEY, SECRETKEY);

pubNub.subscribe(["temp_c", "demo"], function(err, data, tt) {
    
    if (err != null) {
        server.log(err);
        return;
    }
    
    local logstr = "Received at " + tt + ": "
    local idx = 1;
    foreach (channel, value in data) {
        logstr += (channel + ": "+ value);
        if (idx++ < data.len()) {
            logstr += ", ";
        }
    }
    server.log(logstr);
});

// pubNub.history("temp_c",50,function(err, data) {
//     if (err != null) {
//         server.error(err);
//     } else {
//         server.log("History: "+data);
//     }
// });

postdummy();