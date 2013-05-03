// Tomato-watering Agent

// Time Zone Offset. Pacific Time is UTC - 7:00
const TZOFFSET = 7;

html <- @"<!DOCTYPE html>
<html lang='en'>
  <head>
    <meta charset='utf-8'>
    <title>Garden Control</title>
    <meta name='apple-mobile-web-app-capable' content='yes'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <meta name='description' content=''>
    <meta name='author' content=''>

    <!-- styles -->
    <link href='http://demo2.electricimp.com/bootstrap/css/bootstrap.css' rel='stylesheet'>
    <link href='http://demo2.electricimp.com/bootstrap/css/bootstrap-responsive.css' rel='stylesheet'>
	<link href='http://demo2.electricimp.com/components/toggle-switch-styles.css' rel='stylesheet'>
	<style>
		body {
			padding-top: 60px;
		}
		.centered {
			text-align:center;
			padding:4px;
		}
	</style>
  </head>

  <body>
	<!-- javascript -->
	<script type='text/javascript' src='http://code.jquery.com/jquery-latest.js'></script>
	<script src='http://demo2.electricimp.com/bootstrap/js/bootstrap.js' type='text/javascript'></script> 
	<script type='text/javascript'> 
		//cache of values
		infoCache = {
			onTime: null,
			offTime: null,
			pump: false,
		}

		impURL = 'http://agent.electricimp.com/iGtzrIyRilv4';

		// meta-function to call other functions
		$(function() {
			getDeviceInfo();
		});

		function getDeviceInfo() {
			// send a req to server-side getDeviceInfo.php to avoid cross-site scripting
			if (window.XMLHttpRequest) {
				devInfoReq=new XMLHttpRequest();
			} else {
				devInfoReq=new ActiveXObject('Microsoft.XMLHTTP');
			}
			
			try {
				devInfoReq.open('GET', impURL+'/info', false);
				devInfoReq.send();
	
				// this will be the block of JSON returned from the imp's agent
				console.log(devInfoReq);
	
				var response = devInfoReq.responseText;
				deviceInfo = JSON.parse(response);
				console.log(deviceInfo);
	
				//parse the JSON from the agent here
				infoCache.pump = deviceInfo.pump;
				infoCache.onTime = deviceInfo.onTime;
				infoCache.offTime = deviceInfo.offTime;

			} catch (err) {
				console.log('Error parsing device info from imp');
			}

			console.log('Updating Page Fields');

			if (infoCache.pump) {
				document.getElementById('pumpRunning').style.display = 'block';
				document.getElementById('pumpNotRunning').style.display = 'none';
			} else {
				document.getElementById('pumpRunning').style.display = 'none';
				document.getElementById('pumpNotRunning').style.display = 'block';
			}
			document.getElementById('currentOnTime').innerHTML = infoCache.onTime;
			document.getElementById('currentOffTime').innerHTML = infoCache.offTime;

			setTimeout('getDeviceInfo()', 2000);
		}

		function sendToImp(command) {
			// send a req to server-side getDeviceInfo.php to avoid cross-site scripting
			if (window.XMLHttpRequest) {
				devInfoReq=new XMLHttpRequest();
			} else {
				devInfoReq=new ActiveXObject('Microsoft.XMLHTTP');
			}
			try {
				devInfoReq.open('GET', impURL+command, false);
				devInfoReq.send(command);
			} catch(err) {
				console.log('Error sending command to imp');
			}
		}
		function togglePump() {
			if (infoCache.pump) {
				sendToImp('/pumpOff');			
			} else {
				sendToImp('/pumpOn');
			}
		}
		function setSchedule(form) {
			console.log('Setting Schedule');
			infoCache.onTime = form.onTime.value;
			infoCache.offTime = form.offTime.value;
			if (window.XMLHttpRequest) {
				request=new XMLHttpRequest();
			} else {
				request=new ActiveXObject('Microsoft.XMLHTTP');
			}
			request.open('POST', impURL+'/schedule', false);
			var json = JSON.stringify(infoCache);
			console.log(json);
			request.send(json);
			console.log('Sent message to imp');
			getDeviceInfo();
		}

	</script>
	<div class='container'>
		<div class='span12 centered'>
			<img src='http://demo2.electricimp.com/images/tomato.png' width=120 alt='nomnomnomnomnom' style='padding-top: 10px; padding-bottom: 20px;'>
			<form>
				<h3>On At: <input type='time' name='onTime'></h3>
				<h3>Off At: <input type='time' name='offTime'></h3>
				<button class='btn btn-primary' type='button' onClick='setSchedule(this.form)'>OK</button>
				<h2>Currently Set to:</h2>
				<h3>On At: <span id='currentOnTime'></span></h3>
				<h3>Off At: <span id='currentOffTime'</span></h3>
				<!--<span id='deltaT'></span>hours, <span id='volume'></span> mL-->
				<span id='pumpRunning' style='padding-top: 20px; display: none;' onClick='togglePump()'><div class='alert alert-success'><h4>Pump Running</h4></div></span>
				<span id='pumpNotRunning' style='padding-top: 20px; display: none;' onClick='togglePump()'><div class='alert alert-info'><h4>Pump Off</h4></div>
			</form>
		</div>
		<div class='span12 centered'>
			Tomatoes are watered in Pacific Standard or Daylight Time by <b><a href='http://electricimp.com'>electric imp</a></b>.
		</div>
	</div>

  </body>
</html>"

server.log("Tomato Agent Started");

info <- {
    pump = false,
    onTime = "00:00",
    offTime = "00:00",
}

device.send("pump", false);

function startPump() {
    device.send("pump",true);
    info.pump = true;
    // wait one minute and then schedule next pump start (for tomorrow)
    imp.wakeup(60, schedulePumpStart);
}

function stopPump() {
    device.send("pump",false);
    info.pump = false;
    // wait one minute and then schedule next pump stop (for tomorrow);
    imp.wakeup(60, schedulePumpStop);
}

function schedulePumpStart() {
    local schHrs = split(info.onTime,":")[0].tointeger();
    local schMins = split(info.onTime,":")[1].tointeger();
    local now = date();
    local minsUntil = (schHrs*60 + schMins) - ((now.hour.tointeger()-TZOFFSET)*60 + now.min.tointeger());
    if (minsUntil == 0) {
        // if the scheduled on time happens to be right now, get to it.
        startPump()
    } else if (minsUntil < 0) {
        // start time is actually tomorrow
        // wait out the rest of today, then until the proper time tomorrow
        local leftToday = 1440 - ((now.hour.tointeger()-TZOFFSET)*60 + now.min.tointeger());
        // imp.wakeup timing is in seconds
        local totalMinsToGo = (leftToday + (schHrs*60 + schMins));
        local hrsToGo = totalMinsToGo / 60;
        local minsToGo = totalMinsToGo % 60;
        server.log(format("Pump start scheduled in %02d:%02d",hrsToGo,minsToGo));
        imp.wakeup(totalMinsToGo*60, startPump);
    } else {
        // base case. We need to start the pump later today.
        local hrsToGo = minsUntil / 60;
        local minsToGo = minsUntil % 60;
        server.log(format("Pump start scheduled in %02d:%02d",hrsToGo,minsToGo));
        imp.wakeup(minsUntil*60, startPump);
    }
}

function schedulePumpStop() {
    local schHrs = split(info.offTime,":")[0].tointeger();
    local schMins = split(info.offTime,":")[1].tointeger();
    local now = date();
    local minsUntil = (schHrs*60 + schMins) - ((now.hour.tointeger()-TZOFFSET)*60 + now.min.tointeger());
    if (minsUntil == 0) {
        // if the scheduled on time happens to be right now, get to it.
        stopPump()
    } else if (minsUntil < 0) {
        // stop time is actually tomorrow
        // wait out the rest of today, then until the proper time tomorrow
        local leftToday = 1440 - ((now.hour.tointeger()-TZOFFSET)*60 + now.min.tointeger());
        // imp.wakeup timing is in seconds
        local totalMinsToGo = (leftToday + (schHrs*60 + schMins));
        local hrsToGo = totalMinsToGo / 60;
        local minsToGo = totalMinsToGo % 60;
        server.log(format("Pump stop scheduled in %02d:%02d",hrsToGo,minsToGo));
        imp.wakeup((leftToday + (schHrs*60 + schMins))*60, stopPump);
    } else {
        // base case. We need to stop the pump later today.
        local hrsToGo = minsUntil / 60;
        local minsToGo = minsUntil % 60;
        server.log(format("Pump stop scheduled in %02d:%02d",hrsToGo,minsToGo));
        imp.wakeup(minsUntil*60, stopPump);
    }
}

http.onrequest(function(request, res) {
    //server.log("Agent got new HTTP Request");
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (request.path == "/info") {
        // client has just started and needs device information
        //server.log("Sending device status info to client");
        res.send(200, http.jsonencode(info));
    } else if (request.path == "/schedule") {
        if (request.body == "") {
            // handle preflight checks
            res.send(200, "OK");
        } else {
            // client has just submitted a new watering schedule
            server.log("Got new watering schedule request");
            local schedule = http.jsondecode(request.body);
            info.onTime = schedule.onTime;
            info.offTime = schedule.offTime;
            schedulePumpStart();
            schedulePumpStop();
            res.send(200, "OK");
        }
        
    } else if (request.path == "/pumpOn") {
        startPump();
        res.send(200, "OK");
    } else if (request.path == "/pumpOff") {
        stopPump()
        res.send(200, "OK");
    } else {
        // client just started, serve up the page
        res.send(200, html);
    }
});
