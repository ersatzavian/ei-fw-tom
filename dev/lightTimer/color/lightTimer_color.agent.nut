/* Electric Imp Light Timer Agent
 * Web Interface Served from the Agent
 * Tom Byrne
 * tom@electricimp.com
 * 12/6/13
 */
 
/* WEB PAGE AS STRING --------------------------------------------------------*/
webpage <- @"

<!DOCTYPE html>
<html lang='en'>
  <head>
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <meta name='description' content=''>
    <meta name='author' content=''>

    <title>Light Timer - Scheduling</title>

    <!-- Bootstrap core CSS -->
    <link href='https://netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap.min.css' rel='stylesheet'>

  </head>

  <body>

    <nav id='top' class='navbar navbar-fixed-top navbar-inverse' role='navigation'>
      <div class='container'>
        <div class='navbar-header'>
          <button type='button' class='navbar-toggle' data-toggle='collapse' data-target='.navbar-ex1-collapse'>
            <span class='sr-only'>Toggle navigation</span>
            <span class='icon-bar'></span>
            <span class='icon-bar'></span>
            <span class='icon-bar'></span>
          </button>
          <a class='navbar-brand'>Imp Light Scheduler</a>
        </div>

        <!-- Collect the nav links, forms, and other content for toggling -->
        <div class='collapse navbar-collapse navbar-ex1-collapse'>
          <ul class='nav navbar-nav'>
          </ul>
        </div><!-- /.navbar-collapse -->
      </div><!-- /.container -->
    </nav>
    
    <div class='container'>
      <div class='row' style='margin-top: 80px'>
    	<div class='col-md-offset-2 col-md-8 well'>
			<div class='row'>
			  <div class='col-md-12 form-group'>
			  	<h2 style='display: inline'>Lighting Schedule</h2>
			  	<button type='button' class='btn btn-default' style='vertical-align: top; margin-left: 15px;' onclick='newLight()'><span class='glyphicon glyphicon-plus'></span> New</button></div>
			  <div id='light'>
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
  <script type='text/javascript' src='https://cdn.firebase.com/v0/firebase.js'></script>

  <script>
    console.log('Javascript made it!');
  
    function logSuccess(title, message, autoclear) {
		autoclear = autoclear || true;
		var t = new Date().getTime();
		$('#top').append('<div id=\'' + t + '\' class=\'alert alert-success\'><button type=\'button\' class=\'close\' data-dismiss=\'alert\'>x</button><strong>' + title + '</strong>&nbsp;' + message + '</div>');
		if (autoclear) {
			window.setTimeout(function() { $('#' + t).alert('close'); }, 3000);
		}
	}
	
    var LightsBase = new Firebase('https://lights.firebaseio.com/schedule/onoff/lights');
    
	LightsBase.once('value', function(snapshot) {
		var lightschedule = snapshot.val();
        
        console.log('Got Schedule from Firebase:');
        for(var key in lightschedule) {
            console.log(key+' : '+lightschedule[key]);
        }
		
		for(var key in lightschedule) {
			newLight();
			$('.light-control').last().children()[0].value = lightschedule[key].onat;
			$('.light-control').last().children()[1].value = lightschedule[key].onfor;
		}
    });
	
	var lightHtml = " + "\"<div class='well row' style='width: 80%; margin-left: 20px;'><div class='col-md-4'><p style='margin-top: 10px'><strong>Turn light on at (24h): </strong></p><p style='margin-top: 10px'><strong>Keep lights on for (min): </strong></p></div><div class='col-md-3 light-control'><input type='text' class='form-control light-onat' placeholder='eg: 14:00'><input type='text' class='form-control light-onfor' placeholder='eg: 15 minutes'></div><div class='col-md-2 col-md-offset-3'><button type='button' class='btn btn-danger' style='margin-top: 68px;' onclick='$(this).parent().parent().remove();'>Remove</button></div></div>\";" + @"
	
    function newLight() {
		$('#light').append(lightHtml);
	}  
	
	function save() {
		var sendTo = document.URL+'/schedule'
		
		var lightTimes = $('.light-control');
		var schedule = { 'lights': []};
		
		lightTimes.each(function() {
 			schedule.lights.push({
				'onat': $(this).children()[0].value,
				'onfor': $(this).children()[1].value,
			});
		});
		
		$.ajax({
			url: sendTo,
			type: 'POST',
			dataType: 'application/json',
			data: JSON.stringify(schedule)
		});
        
        var lightschedule = new Firebase('https://lights.firebaseio.com/schedule/onoff');

        lightschedule.update(schedule, function(error) {
            if (error) alert('Synchronization failed.');
            else logSuccess('Success!', 'Schedule updated!');
        });

  }

  </script>
  </body>

</html>"

/* OTHER CONSTS AND GLOBALS --------------------------------------------------*/

controllerID <- 0;  // 433 MHz Comen Controller ID

const FIREBASEKEY = "YBPIBNwB349ri0rcFz8KzWUENukB0936Bq99QBY0";
const DBASE = "lights";
const FBRATELIMIT = 1; //minimum time between firebase posts

// Device Schedule
SCHED <- {lights = []};

/* FUNCTION AND CLASS DEFINITIONS --------------------------------------------*/

/* Generic function to convert a binary blob to a hex string
 * Input:
 *      data: a binary blob of arbitrary length
 * Return:
 *      str:  a hex string representing the original binary blob
 */
function BlobToHexString(data) {
  local str = "0x";
  foreach (b in data) str += format("%02x", b);
  return str;
}

function secondsTill(targetTime) {
    local data = split(targetTime,":");
    local target = { hour = data[0].tointeger(), min = data[1].tointeger() };
    local now = date(time() - (3600 * 8));
    
    if ((target.hour < now.hour) || (target.hour == now.hour && target.min < now.min)) {
        target.hour += 24;
    }
    
    local secondsTill = 0;
    secondsTill += (target.hour - now.hour) * 3600;
    secondsTill += (target.min - now.min) * 60;
    return secondsTill;
}

function lightsOnSched() {
    server.log("Executing Scheduled Lights-On.");
    device.send("switch",{channel="all",state=1});
}

function lightsOffSched() {
    server.log("Executing Scheduled Lights-Off.");
    device.send("switch",{channel="all",state=0});
}

function refreshSched() {
    
    foreach (lighting in SCHED.lights) {
       // schedule wake-and-lights-on
        imp.wakeup(secondsTill(lighting.onat), lightsOnSched);
        // schedule wake-and-lights-off
        imp.wakeup(secondsTill(lighting.onat)+(lighting.onfor.tointeger() * 60), lightsOffSched); 
    }
}

function setNewSched(sched) {
    if ("lights" in sched) {
        SCHED.lights = sched.lights;
    }
    
    foreach (lighting in SCHED.lights) {
        // schedule wake-and-lights-on
        server.log("lights-on in "+secondsTill(lighting.onat));
        imp.wakeup(secondsTill(lighting.onat), lightsOnSched);
        // schedule wake-and-lights-off
        server.log("lights-off in "+(secondsTill(lighting.onat)+(lighting.onfor.tointeger() * 60)));
        imp.wakeup(secondsTill(lighting.onat)+(lighting.onfor.tointeger() * 60), lightsOffSched); 
    }
    
    imp.wakeup(secondsTill("00:00"), refreshSched);
}

// -----------------------------------------------------------------------------
// Firebase class: Implements the Firebase REST API.
// https://www.firebase.com/docs/rest-api.html
//
// Author: Aron
// Created: September, 2013
//
class Firebase {
    
    database = null;
    authkey = null;
    agentid = null;
    url = null;
    headers = null;
    
    // ........................................................................
    constructor(_database, _authkey, _path = null) {
        database = _database;
        authkey = _authkey;
        agentid = http.agenturl().slice(-12);
        headers = {"Content-Type": "application/json"};
        set_path(_path);
    }
    
    
    // ........................................................................
    function set_path(_path) {
        if (!_path) {
            _path = "agents/" + agentid;
        }
        url = "https://" + database + ".firebaseIO.com/" + _path + ".json?auth=" + authkey;
    }


    // ........................................................................
    function write(data, callback = null) {
    
        //if (typeof data == "table") data.heartbeat <- time();
        http.request("PUT", url, headers, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res);
                else server.log("Write: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                if (callback) callback(null);
            }
        }.bindenv(this));
    
    }
    
    // ........................................................................
    function update(data, callback = null) {
    
        //if (typeof data == "table") data.heartbeat <- time();
        http.request("PATCH", url, headers, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res);
                else server.log("Update: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                if (callback) callback(null);
            }
        }.bindenv(this));
    
    }
    
    // ........................................................................
    function push(data, callback = null) {
    
        //if (typeof data == "table") data.heartbeat <- time();
        http.post(url, headers, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res, null);
                else server.log("Push: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                local body = null;
                try {
                    body = http.jsondecode(res.body);
                } catch (err) {
                    if (callback) return callback(err, null);
                }
                if (callback) callback(null, body);
            }
        }.bindenv(this));
    
    }
    
    // ........................................................................
    function read(callback = null) {
        http.get(url, headers).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res, null);
                else server.log("Read: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                local body = null;
                try {
                    body = http.jsondecode(res.body);
                } catch (err) {
                    if (callback) return callback(err, null);
                }
                if (callback) callback(null, body);
            }
        }.bindenv(this));
    }
    
    // ........................................................................
    function remove(callback = null) {
        http.httpdelete(url, headers).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res);
                else server.log("Delete: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                if (callback) callback(null, res.body);
            }
        }.bindenv(this));
    }
    
}

/* DEVICE CALLBACK HANDLERS --------------------------------------------------*/

/* During initialization, the device sends its MAC address to be hashed and returned as
 * a unique 24-bit controllerID for the comen sub-device protocol.
 */
device.on("controllerIDfromMAC", function(mac) {
    
    local rawhash = http.hash.md5(mac);
    server.log("imp MAC address: 0x"+mac);
    server.log("hashed MAC address: "+BlobToHexString(rawhash));
    
    for (local i = 2; i >= 0; i--) {
        controllerID += (rawhash[i] << (16 - (8 * i)));
    }
    
    server.log(format("Generated Controller ID: 0x%03x",controllerID));
    
    device.send("setControllerId",controllerID);
});

/* HTTP REQUEST HANDLER ------------------------------------------------------*/

http.onrequest(function(req,res) {
    // set headers to allow cross-origin send
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");

    if (req.path == "/schedule" || req.path == "/schedule/") {
        server.log("Setting new schedule");
        server.log(req.body);
        local newSched = http.jsondecode(req.body);
        setNewSched(newSched);
        res.send(200,SCHED);
    } else if (req.path == "/on" || req.path == "/on/") {
        res.send(200, "Lights On!");
        "switch",{channel="all",state=1}
    } else if (req.path == "/off" || req.path == "/off/") {
        res.send(200, "Lights Off!");
        "switch",{channel="all",state=0}
    } else {
        res.send(200, webpage);
    }
    
});

/* RUNTIME BEGINS HERE -------------------------------------------------------*/
