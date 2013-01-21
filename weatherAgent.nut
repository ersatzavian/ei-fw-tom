// Weather Agent
// Uses Wunderground API to obtain forecast for a provided zip every 10 minutes
// Relays parsed forecast to device (such as Emma 8-char display)

server.log("Weather Agent Running");

// Add your own wunderground API Key here. 
// Register for free at http://api.wunderground.com/weather/api/
local myAPIKey = "YOURKEYHERE";
local wunderBaseURL = "http://api.wunderground.com/api/"+myAPIKey+"/";

// Add the zip code you want to get the forecast for here.
local zip = "94022";

// The wunderground API has a lot of different features (tides, sailing, etc)
// We use "conditions" to indicate we just want a general weather report
local reportType = "conditions";

// This funciton is a temporary shim. The electric imp service will soon support 
// native JSON parsing, making this whole agent much more straightforward. For now, 
// we must manually dice up the JSON to form our weather report
function parseWeather(jsonString) {
    server.log("Parsing Report...");
    // declare an empty table
    local weather = {};
    
    // split the report on commas, then grab the appropriate line. 
    // Note that we also use split with index 0 to strip the quotes in the report
    local reportArr = split(jsonString, ",");
    weather["city"] <- split(split(reportArr[19],":")[1], "\"")[0];
    weather["state"] <- split(split(reportArr[20],":")[1], "\"")[0];
    weather["obsDay"] <- split(split(reportArr[28],":")[1], "\"")[0];
    weather["obsTime"] <- split(reportArr[29], "\"")[0];
    weather["conditions"] <- split(split(reportArr[39],":")[1],"\"")[0];
    weather["tempF"] <- split(split(reportArr[41],":")[1], "\"")[0];
    weather["tempC"] <- split(split(reportArr[42],":")[1], "\"")[0];
    weather["humidity"] <- split(split(reportArr[43],":")[1], "\"")[0];
    weather["wind"] <- split(split(reportArr[44],":")[1], "\"")[0];
    weather["pressureIn"] <- split(split(reportArr[52],":")[1], "\"")[0];
    weather["pressureTrend"] <- split(split(reportArr[53],":")[1], "\"")[0];
    
    // some debug logging to make sure you've got the right lines
    server.log("city: "+weather.city);
    server.log("state: "+weather.state);
    server.log("day: "+weather.obsDay)
    server.log("time: "+weather.obsTime);
    server.log("conditions "+weather.conditions);
    server.log("temp F: "+weather.tempF);
    server.log("temp C: "+weather.tempC);
    server.log("humidity: "+weather.humidity);
    server.log("wind: "+weather.wind);
    server.log("pressure: "+weather.pressureIn);
    server.log("pressure trend: "+weather.pressureTrend);
    
    return weather;
}

function getConditions() {
    server.log(format("Agent getting current conditions for %s", zip));
    // register the next run of this function, so we'll check again in five minutes
    
    // cat some strings together to build our request URL
    local reqURL = wunderBaseURL+reportType+"/q/"+zip+".json";

    // call http.get on our new URL to get an HttpRequest object. Note: we're not using any headers
    server.log(format("Sending request to %s", reqURL));
    local req = http.get(reqURL);

    // send the request synchronously (blocking). Returns an HttpMessage object.
    local res = req.sendsync();

    // check the status code on the response to verify that it's what we actually wanted.
    server.log(format("Response returned with status %d", res.statuscode));
    if (res.statuscode != 200) {
        server.log("Request for weather data failed.");
        imp.wakeup(600, getConditions);
        return;
    }

    // log the body of the message and find out what we got.
    //server.log(res.body);

    // call our handy JSON "parsing" function from above. Added plus:
    // when we add JSON support, we can change JUST that function
    local weather = parseWeather(res.body);
    
    local forecastString = "";
    
    // Chunk together our forecast into a printable string
    server.log(format("Obtained forecast for ", weather.city));
    forecastString += ("Forecast for "+weather.city+", "+weather.state+" ");
    forecastString += (weather.conditions+", ");
    forecastString += ("Temperature "+weather.tempF+"F, ");
    forecastString += (weather.tempC+"C, ");
    forecastString += ("Humidity "+weather.humidity+", ");
    forecastString += ("Pressure "+weather.pressureIn+" in. ");
    if (weather.pressureTrend == "+") {
        forecastString += "and rising, ";
    } else if (weather.pressureTrend == "-") {
        forecastString += "and falling, ";
    } else {
        forecastString += "and steady, ";
    }
    forecastString += ("Wind "+weather.wind+". ");
    forecastString += weather.obsDay;
    forecastString += (" at "+weather.obsTime+".");

    // relay the formatting string to the device
    // it will then be handled with function registered with "agent.on":
    // agent.on("newData", function(data) {...});
    server.log(format("Sending forecast to imp: %s",forecastString));
    device.send("newData", forecastString);
        
    imp.wakeup(600, getConditions);
}

imp.sleep(2);
getConditions();

// Here's an example function that would go on the device to actually handle the new data:
/*
agent.on("newData", function(data){
    server.log(format("Imp got new data: %s",data));
    displayInput.set(data);
});
*/
