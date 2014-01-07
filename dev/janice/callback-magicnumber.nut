schedule <- {
    "0" : {
        "startin": 1,
        "stopin": 20,
        "magicnumber": 5
    },
    "1" : {
        "startin": 5,
        "stopin": 10,
        "magicnumber": 7
    }
}

foreach(key,value in schedule) {
    local k = key;
    server.log("Scheduling "+key);
    // schedule the watering starts
    imp.wakeup(schedule[k].startin, function() {
        server.log(format("Starting Event %s (Magic Number is %d)",k,schedule[k].magicnumber));
    }.bindenv(this));
    // schedule the watering stops
}