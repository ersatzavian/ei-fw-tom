/* Weather Underground Forecast Agent
 * Copyright (C) 2014 electric imp, inc.
 *
 */

const FORECASTINTERVAL = 600; // fetch forecast every 10 minutes

server.log("Weather Agent Running");

// Add your own wunderground API Key here. 
// Register for free at http://api.wunderground.com/weather/api/
local myAPIKey = "YOUR KEY HERE";
local wunderBaseURL = "http://api.wunderground.com/api/"+myAPIKey+"/";

// Add the zip code you want to get the forecast for here.
local zip = 94041;

// The wunderground API has a lot of different features (tides, sailing, etc)
// We use "conditions" to indicate we just want a general weather report
local reportType = "conditions";

function getConditions() {
    // schedule this function to run again after our set interval
    imp.wakeup(FORECASTINTERVAL, getConditions);
    
    server.log(format("Agent getting current conditions for %d", zip));
    // register the next run of this function, so we'll check again in five minutes
    
    // cat some strings together to build our request URL
    local reqURL = wunderBaseURL+reportType+"/q/"+zip.tostring()+".json";

    // call http.get on our new URL to get an HttpRequest object. Note: we're not using any headers
    //server.log(format("Sending request to %s", reqURL));
    local req = http.get(reqURL);

    // send the request synchronously (blocking). Returns an HttpMessage object.
    local res = req.sendsync();

    // check the status code on the response to verify that it's what we actually wanted.
    //server.log(format("Response returned with status %d", res.statuscode));
    if (res.statuscode != 200) {
        server.log("Request for weather data failed.");
        imp.wakeup(600, getConditions);
        return;
    }

    // hand off data to be parsed
    local response = http.jsondecode(res.body);
    local weather = response.current_observation;
    
    local forecastString = "";
        
    // Chunk together our forecast into a printable string
    forecastString += ("Forecast for "+weather.display_location.city+", "+weather.display_location.state+": ");
    forecastString += (weather.weather+", ");
    forecastString += ("Temperature "+weather.temp_f+"F, ");
    forecastString += (weather.temp_c+"C, ");
    forecastString += ("Humidity "+weather.relative_humidity+", ");
    forecastString += ("Pressure "+weather.pressure_in+" in. ");
    if (weather.pressure_trend == "+") {
        forecastString += "and rising, ";
    } else if (weather.pressure_trend == "-") {
        forecastString += "and falling, ";
    } else {
        forecastString += "and steady, ";
    }
    forecastString += ("Wind "+weather.wind_mph+". ");
    forecastString += weather.observation_time;

    server.log(forecastString);
    device.send("seteffect", {conditions = weather.weather, temperature = weather.temp_c});
}

imp.sleep(2);
getConditions();