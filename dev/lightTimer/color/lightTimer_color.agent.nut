/* Electric Imp Light Timer Agent
 * Web Interface Served from the Agent
 * Tom Byrne
 * tom@electricimp.com
 * 12/6/13
 */
 

/* CONSTS AND GLOBALS --------------------------------------------------------*/

const WUNDERGROUND_KEY = "YOUR KEY HERE";

WEBPAGE <- "Agent initializing, please refresh";
refreshtime <- "00:00";
lightstate <- 0;
scheduledEvents <- [];
location <- "CA/Los_Altos";
saveData <- server.load();

/* FUNCTION AND CLASS DEFINITIONS --------------------------------------------*/

function prepWebpage() {
    WEBPAGE = @"
    <!DOCTYPE html>
    <html lang='en'>
      <head>
        <meta charset='utf-8'>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <meta name='description' content=''>
        <meta name='author' content=''>
    
        <title>Timer</title>
        <link href='data:image/x-icon;base64,AAABAAEAEBAQAAAAAAAoAQAAFgAAACgAAAAQAAAAIAAAAAEABAAAAAAAgAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAioqKAFXm3gBj4NoARvrxAHNzcwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAARAAAAAAAABVEQAAAAAAABFVAAAAAAAAVREAAAAAAAARVQAAAAAAADRDAAAAAAAANEMAAAAAAANERDAAAAAAA0REMAAAAAADREQwAAAAADREREMAAAAANEREQwAAAAA0IkRDAAAAADQiREMAAAAAA0REMAAAAAAAMzMAAAD+fwAA/D8AAPw/AAD8PwAA/D8AAPw/AAD8PwAA+B8AAPgfAAD4HwAA8A8AAPAPAADwDwAA8A8AAPgfAAD8PwAA' rel='icon' type='image/x-icon'/>
        <link href='https://netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap.min.css' rel='stylesheet'>
    
      </head>
      <body>

        <nav id='top' class='navbar navbar-static-top navbar-inverse' role='navigation'>
          <div class='container'>
            <div class='navbar-header'>
              <button type='button' class='navbar-toggle' data-toggle='collapse' data-target='.navbar-ex1-collapse'>
                <span class='sr-only'>Toggle navigation</span>
                <span class='icon-bar'></span>
                <span class='icon-bar'></span>
                <span class='icon-bar'></span>
              </button>
              <a class='navbar-brand'>Light Timer</a>
            </div>
    
            <!-- Collect the nav links, forms, and other content for toggling -->
            <div class='collapse navbar-collapse navbar-ex1-collapse'>
              <ul class='nav navbar-nav'>
              </ul>
            </div><!-- /.navbar-collapse -->
          </div><!-- /.container -->
        </nav>
        
        <div class='container'>
          <div class='row' style='margin-top: 20px'>
            <div class='col-md-offset-2 col-md-8 well'>
                <div id='disconnected' class='alert alert-warning' style='display:none'>
                    <button type='button' class='close' data-dismiss='alert' aria-hidden='true'>&times;</button>
                    <strong>Device Not Connected.</strong> Check your sprinkler's internet connection .
                </div>
                <div id='schedulesetok' class='alert alert-success' style='display:none'>
                    <button type='button' class='close' data-dismiss='alert' aria-hidden='true'>&times;</button>
                    <strong>New Schedule Set.</strong>
                </div>
                <div id='scheduleseterr' class='alert alert-error' style='display:none'>
                    <button type='button' class='close' data-dismiss='alert' aria-hidden='true'>&times;</button>
                    <strong>New Schedule Not Set.</strong> Something has gone wrong.
                </div>
                <div class='row'>
                  <div class='col-md-12 form-group'>
                    <h2 style='display: inline'>Light Schedule</h2>
                    <button type='button' class='btn btn-default' style='vertical-align: top; margin-left: 15px;' onclick='newEntry()'><span class='glyphicon glyphicon-plus'></span> New</button>
                    <button type='button' id='lightoff' class='btn btn-default' style='vertical-align: top; margin-left: 15px; display: inline;' onclick='lightoff()'><span class='glyphicon glyphicon-off'></span> On</button>
                    <button type='button' id='lighton' class='btn btn-default' style='vertical-align: top; margin-left: 15px; display: none;' onclick='lighton()'><span class='glyphicon glyphicon-off'></span> Off</button>
                  </div>
                  <div id='entries'>
                  </div>
                </div>
                <div class='row'>
                  <div class='col-md-4'>
                    <button type='button' class='btn btn-primary' style='margin-top: 36px;' onclick='save()'>Save</button>
                  </div>
                </div>
            </div>
          </div>
          <hr>
    
          <footer>
            <div class='row'>
              <div class='col-lg-12'>
                <p class='text-center'>Copyright &copy; Electric Imp 2013 &middot; <a href='http://facebook.com/electricimp'>Facebook</a> &middot; <a href='http://twitter.com/electricimp'>Twitter</a></p>
              </div>
            </div>
          </footer>
          
        </div><!-- /.container -->
    
      <!-- javascript -->
      <script src='https://cdnjs.cloudflare.com/ajax/libs/jquery/2.0.3/jquery.min.js'></script>
      <script src='https://netdna.bootstrapcdn.com/bootstrap/3.0.2/js/bootstrap.min.js'></script>
      <script>
      
        function showSchedule(rawdata) {
            console.log('got schedule from agent: '+rawdata);
            var schedule = JSON.parse(rawdata);
            if (schedule.length > 0) {
                for (var i = 0; i < schedule.length; i++) {
                    newEntry();
                    $('.light-start').last()[0].value = schedule[i].onat;
                    $('.light-stop').last()[0].value = schedule[i].offat;
                    $('.light-color').last()[0].value = schedule[i].color;
                }
            } else {
                //console.log('Empty Schedule Received from Agent: '+rawdata);
            }
        }
        
        function showLightState(state) {
            if (state == '0') {
                $('#lightoff').css('display', 'none');
                $('#lighton').css('display', 'inline');
            } else {
                $('#lighton').css('display', 'none');
                $('#lightoff').css('display', 'inline');
            }
        }
        
        function showConnStatus(status) {
            if (status == true) {
                $('#disconnected').css('display', 'block');
            } else {
                $('#disconnected').css('display', 'none');
            }
        }
      
        function getSchedule() {
            $.ajax({
                url: document.URL+'/getSchedule',
                type: 'GET',
                success: showSchedule
            });    
        }
        
        function getLightState() {
            $.ajax({
                url: document.URL+'/state',
                type: 'GET',
                success: showLightState
            });
         }
         
        function getConnectionStatus() {
            $.ajax({
                url: document.URL+'/status',
                type: 'GET',
                success: showConnStatus
            });
        }
        
        var entryHtml = " + "\""+@"<div class='well row' style='width: 80%; margin-left: 20px;'>\
                                <div class='col-md-4'>\
                                    <p style='margin-top: 10px'><strong>On at: </strong></p>\
                                    <p style='margin-top: 20px'><strong>Off at: </strong></p>\
                                    <p style='margin-top: 20px'><strong>Color: </strong></p>\
                                </div>\
                                <div class='col-md-8 light-control'>\
                                    <div class='light-time'>\
                                        <p><input data-format='hh:mm' type='time' value='12:00' class='form-control light-start'></input></p>\
                                    </div>\
                                    <div class='light-time'>\
                                        <p><input data-format='hh:mm' type='time' value='12:00' class='form-control light-stop'></input></p>\
                                    </div>\
                                    <div>\
                                        <p><input type='color' value='#ffff00' class='form-control light-color'></input></p>\
                                    </div>\
                                </div>\
                                <div class='col-md-1 col-md-offset-10'>\
                                    <button type='button' class='btn btn-danger' style='margin-top: 10px;' onclick='$(this).parent().parent().remove();'>Remove</button>\
                                </div>\
                                </div>" + "\";" + @"
                                
        function newEntry() {
            $('#entries').append(entryHtml);
        }
        
        function lightoff() {
            $('#lightoff').css('display', 'none');
            $('#lighton').css('display', 'inline');
            var sendTo = document.URL+'/lightoff';
            $.ajax({
                url: sendTo,
                type: 'GET'
            });
        }
        
        function lighton() {
            $('#lighton').css('display', 'none');
            $('#lightoff').css('display', 'inline');
            var sendTo = document.URL+'/lighton';        
            $.ajax({
                url: sendTo,
                type: 'GET'
            });
        }
        
        function logSuccess() {
            $('#schedulesetok').css('display', 'block');
            window.setTimeout(function() { $('#schedulesetok').css('display','none'); }, 3000);
        }
        
        function logError(xhr, status, error) {
            console.log('error setting schedule: '+xhr.responseText+' : '+error);
            $('#scheduleseterr').css('display', 'block');
            window.setTimeout(function() { $('#scheduleseterr').css('display','none'); }, 3000);
        }
        
        function save() {
            var sendTo = document.URL+'/setSchedule'
            
            var waterings = $('.light-control');
            var schedule = [];
            
            waterings.each(function() {
                schedule.push({
                    'onat': $(this).find('.light-start')[0].value,
                    'offat': $(this).find('.light-stop')[0].value,
                    'color': $(this).find('.light-color')[0].value
                });
            });
            
            $.ajax({
                url: sendTo,
                type: 'POST',
                data: JSON.stringify(schedule),
                success: logSuccess,
                error: logError
            });
      }
      
      getSchedule();
      getLightState();
      
      setInterval(getLightState, 1000);
      setInterval(getConnectionStatus, 60000);
    
      </script>
      </body>
    
    </html>"
}

// -----------------------------------------------------------------------------
const WUNDERGROUND_URL = "http://api.wunderground.com/api";
function get_lat_lon(location, callback = null) {
    local url = format("%s/%s/geolookup/q/%s.json", WUNDERGROUND_URL, WUNDERGROUND_KEY, location);
    http.get(url, {}).sendasync(function(res) {
        if (res.statuscode != 200) {
            server.log("Wunderground error: " + res.statuscode + " => " + res.body);
            if (callback) callback(null, null);
        } else {
            try {
                local json = http.jsondecode(res.body);
                local lat = json.location.lat.tofloat();
                local lon = json.location.lon.tofloat();

                if (callback) callback(lat, lon);
            } catch (e) {
                server.error("Wunderground error: " + e)
                if (callback) callback(null, null);
            }
            
        }
    });
}

// -----------------------------------------------------------------------------
const GOOGLE_MAPS_URL = "https://maps.googleapis.com/maps/api";
function get_gmtoffset(lat, lon, callback = null) {
    local url = format("%s/timezone/json?sensor=false&location=%f,%f&timestamp=%d", GOOGLE_MAPS_URL, lat, lon, time());
    http.get(url, {}).sendasync(function(res) {
        if (res.statuscode != 200) {
            server.log("Google maps error: " + res.statuscode + " => " + res.body);
            if (callback) callback(null);
        } else {
            try {
                local json = http.jsondecode(res.body);
                local dst = json.dstOffset.tofloat();
                local raw = json.rawOffset.tofloat();
                local gmtoffset = ((raw+dst)/60.0/60.0);
                
                if (callback) callback(gmtoffset);
            } catch (e) {
                server.error("Google maps error: " + e);
                if (callback) callback(null);
            }
            
        }
    });
}

function hexdec(c) {
    if (c <= '9') {
        return c - '0';
    } else {
        return 0x0A + c - 'A';
    }
}

function decodeColorString(colorString) {
    local rStr = colorString.slice(1,3);
    local gStr = colorString.slice(3,5);
    local bStr = colorString.slice(5,7);
    
    local red = (hexdec(rStr[0]) * 16) + hexdec(rStr[1]);
    local green = (hexdec(gStr[0]) * 16) + hexdec(gStr[1]);
    local blue = (hexdec(bStr[0]) * 16) + hexdec(bStr[1]);

    local rgbTuple = {r=red,g=green,b=blue};
    return rgbTuple;
}

function secondsTil(targetStr) {
    local data = split(targetStr,":");
    local target = { hour = data[0].tointeger(), min = data[1].tointeger() };
    target.hour -= saveData.gmtoffset;
    if (target.hour > 23) {
        target.hour -= 24;
    }

    local now = date(time(),'u');
    
    if ((target.hour < now.hour) || (target.hour == now.hour && target.min < now.min)) {
        target.hour += 24;
    }
    
    local result = 0;
    result += (target.hour - now.hour) * 3600;
    result += (target.min - now.min) * 60;
    return result;
}

function runSched() {
    if (!saveData.schedule) { 
        server.error("No Schedule.");
        return;
    }
    
    while (scheduledEvents.len() > 0) {
        imp.cancelwakeup(scheduledEvents.pop());
        device.send("setColor",{r=0,g=0,b=0});
        lightstate = 0;
    }
    
    foreach (lighting in saveData.schedule) {
        
        local myColor = lighting.color;
        
        // schedule wake-and-lights-on
        local handle = imp.wakeup(secondsTil(lighting.onat), function() {
            device.send("setColor",decodeColorString(myColor));
            lightstate = 1;
        }.bindenv(this)); 
        scheduledEvents.push(handle);
    
        handle = imp.wakeup(secondsTil(lighting.offat), function() {
            device.send("setColor",{r=0,g=0,b=0});
            lightstate = 0;
        }.bindenv(this));
        scheduledEvents.push(handle);
        
        if (secondsTil(lighting.offat) < secondsTil(lighting.onat)) {
            device.send("setColor",decodeColorString(myColor));
            lightstate = 1;
        }
    }
    
    local refreshHandle = imp.wakeup(secondsTil(refreshtime)+60, function() { runSched(); });
    scheduledEvents.push(refreshHandle);
}

/* HTTP REQUEST HANDLER ------------------------------------------------------*/

http.onrequest(function(req,res) {
    // set headers to allow cross-origin send
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");

    if (req.path == "/setSchedule" || req.path == "/setSchedule/") {
        server.log("Setting new schedule");
        try {
            saveData.schedule = http.jsondecode(req.body);
            // respond to web UI 
            res.send(200, "Schedule Set");
            server.log("New Schedule Set: "+req.body);
            // store schedule in case of agent reset
            server.save(saveData);
            runSched();
        } catch (err) {
            server.log(err);
            res.send(400, "Invalid Schedule: "+err);
        }
    } else if (req.path == "/getSchedule" || req.path == "/getSchedule/") {
        server.log("Serving Current Schedule.");
        res.send(200,http.jsonencode(saveData.schedule));
    } else if (req.path == "/state" || req.path == "/state/") {
        res.send(200, lightstate);
    } else if (req.path == "/status" || req.path == "/status/") {
        res.send(200, device.isconnected());
    } else if (req.path == "/lighton" || req.path == "/lighton/") {
        res.send(200, "OK");
        lightstate = 1;
        device.send("setColor",{r=256,g=256,b=0});
    } else if (req.path == "/lightoff" || req.path == "/lightoff/") {
        res.send(200, "OK");
        lightstate = 0;
        device.send("setColor",{r=0,g=0,b=0});
    } else {
        server.log("Serving Web UI");
        res.send(200, WEBPAGE);
    }
    
});

/* RUNTIME BEGINS HERE -------------------------------------------------------*/

server.log("Light Timer Color Agent Running");

prepWebpage();

if (!("schedule" in saveData)) {
    server.log("No schedule loaded.");
    saveData.schedule <- [];
} else {
    server.log("Loaded Schedule: "+http.jsonencode(saveData.schedule));
}

if (!("gmtoffset" in saveData)) {
    get_lat_lon(location, function(lat, lon) {
        server.log("Finding GMT Offset from Location; Lat = "+lat+", Lon = "+lon);
        get_gmtoffset(lat, lon, function(offset) {
            server.log("GMT Offset = "+offset+" hours.");
            saveData.gmtoffset <- offset;
            server.save(saveData);
        });
    });
} else {
    server.log("Loaded GMT Offset: "+saveData.gmtoffset+" hours.");
}

// Now we're up and running, so let the device request a refresh if it restarts
device.on("juststarted", function(val) {
    runSched();
});

