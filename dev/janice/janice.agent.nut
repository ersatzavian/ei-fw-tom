/* Janice Sprinkler Controller Agent Firmware
 * Tom Byrne
 * 12/19/13
 */ 
 
/* CONSTS AND GLOBALS ========================================================*/

// Watering Schedule
SCHEDULE <- server.load(); // attempt to pick the schedule back up from the server in case of agent restart

// UI webpage will be stored at global scope as a multiline string
WEBPAGE <- @"<h2>Agent initializing, please refresh.</h2>";

/* GLOBAL FUNCTIONS AND CLASS DEFINITIONS ====================================*/

/* Pack up the UI webpage. The page needs the xively parameters as well as the device ID,
 * So we need to wait to get the device ID from the device before packing the webpage 
 * (this is done by concatenating some global vars with some multi-line verbatim strings).
 * Very helpful that this block can be compressed, as well. */
function prepWebpage() {
    WEBPAGE = @"
    <!DOCTYPE html>
    <html lang='en'>
      <head>
        <meta charset='utf-8'>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <meta name='description' content=''>
        <meta name='author' content=''>
    
        <title>Electric Imp Connected Chef</title>
        <link href='data:image/x-icon;base64,AAABAAEAEBAAAAAAAABoBQAAFgAAACgAAAAQAAAAIAAAAAEACAAAAAAAAAEAAAAAAAAAAAAAAAEAAAAAAAAAAAAABSV/AAgQmgAAA2IAWHzMACdRwgAEElAAVoHSACVawgBDcsEARHPEAPv+/wABG80A//7/AO7o6wAXLuoAAzWvADZltgBNfM0AEBluAB064QALB0IAIjmFAD1rvwApdOMAPmrFADdWnABDbr8AVYXWAAECGQD8+fEAV4XWAERvwgD+/PEARnDFAFRqswBIcsIABQYcADI+5AD9/f0ANnjmAAUaaQAJGssAJzhfABAevAAkQV8ALUqdAC5UlwAzIh4AKlamAAEWQwAqIzwAE0OkAEdpugD7+vUAQ3LDAERxyQAuYLsASHbGAC1K5QBTZ8YACDCiAAEc0gBKdcwAFjPpABNRxQAmFjoA7vH2ADZQlQBAa8EAMlOnAApCvQD09/8Ad5DUAERtvgAzWqEAtLzPAPj7+QBZhNUAAAl3ACEtWwBGdMEA//zzAAoaUAD/9/8A/fr/AEpuygApU90A///8AGKK1QAdIJcAOGe2AAMJQgAZduwAIEBwAAwNlQAsT7cAPE6ZAEVuuQATDZ4A8v/9AD1DVQBGccIAJkeOAP/7+gBJeb8AV11sACIZKgANStYAUXi8ABRMygBLessAMHDJAPHv+wA9bL0AAAjGAFSD1ABVg9QAIVrHACdDgwBEc8kA/f34AGGF0QD///4ADAqFAAoILwAFEywACyxbAD9jtQAPIWcAOEWbACBoqgASJHAAE5nrAEFwwQAoPocADCrkAEBYjABDccQAJ1bOAPj+/AAnfvQATW24ABIdOAAcTJ8A/v//AENdmwD///8AS3PKADlfswAYL5EAPUDmADNKkABBZ6cAFDKjALGxzQA+bL8AARVOAAkRSwAMGDwA+f7rAPv79AAKQsoA+fz3ACFkzAAeIRgARXTFACYpXAD//v0AEx2kABguPwAcVr4ARGyuAPH68gBIaqgA9PP4AAgTQABBacAAEitsACE3+gC6ucIARESjAAtFwgAXHuYARnDDAP/1/gAPIT0A/fv+AP7+/gD//v4AG2jiAA46hwAjOloAIZztABkwhAAIVtoADQ6CACE3fgAQV9QAAiV/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJOTvCcnJ0MrGi8tTFiTk5OTqA5QpLCQERecclufjKG9C2V+woBFMQqKijcJlVasHjaLoplKeDqmNzcKG2YiiXGtMscGlAd1ElFiN4EgJCNqYGvDPXpOH3Q/soaYII6rV24wbJpaWRxvGX8DLml2hLWbXiy3KqlJS0Z8YVOWvl0YeSaXQAI+c5I4Y4K/KTSlBFU7FcQPiE8BNV+Fwa7GxVJkoH0zswwQR7E8noOHjzlIk3shFBMdQbYWuGcFRFxNk5OTDa+0nbpCcCh3JQije5OTk5N7e2inqm2NwLlUu5GTAAAAAAAAAAAAAAAAAAAAAP//AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP//AAA=' rel='icon' type='image/x-icon' />
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
              <a class='navbar-brand'>Connected Chef</a>
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
                    <h2 style='display: inline'>Now<span id='currentTemp' style='padding-left: 15px'>0.0&degF</span></h2>
                    <button type='button' class='btn btn-default' style='vertical-align: top; margin-left: 15px;' onclick='toggleUnits()'><span class='glyphicon glyphicon-globe'></span> &degF / &degC</button>
                  </div>
                  <div id='lowbatt' class='alert alert-warning' style='display:none'>Warning: Low Battery</div>
                  <div id='graphcontainer'>
                    <img id='tempgraph' style='margin-left: 15px' src=''></img>
                  </div>
                  <div style='padding-top: 10px' class='col-md-12 form-group'>
                    <button type='button' class='btn btn-default' style='vertical-align: top; margin-left: 15px;' onclick='graph5min()'>5 min</button>
                    <button type='button' class='btn btn-default' style='vertical-align: top; margin-left: 15px;' onclick='graph30min()'>30 min</button>
                    <button type='button' class='btn btn-default' style='vertical-align: top; margin-left: 15px;' onclick='graph1hour()'>1 hour</button>
                    <button type='button' class='btn btn-default' style='vertical-align: top; margin-left: 15px;' onclick='graph3hour()'>3 hour</button>
                  </div>
                </div>
                <div class='row'>
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
      <script src='https://d23cj0cdvyoxg0.cloudfront.net/xivelyjs-1.0.4.min.js'></script> 
      <script src='https://netdna.bootstrapcdn.com/bootstrap/3.0.2/js/bootstrap.min.js'></script>
      <script>
      
        var XIVELY_KEY = '" + XIVELY_API_KEY + @"';
        var XIVELY_FEED_ID = '" + XIVELY_FEED_ID + @"';
        var XIVELY_BASE_URL = 'https://api.xively.com/v2/feeds/';
        var DEVICE_ID ='" + config.myDeviceId + @"';
        var graphwidth = document.getElementById('graphcontainer').offsetWidth - 30;
        var graphheight = graphwidth / 2;
        var XIVELY_PARAMS = 'width='+graphwidth+'&height='+graphheight+'&colour=00b0ff&timezone=UTC&b=true&g=true';
        var XIVELY_GRAPH_URL = XIVELY_BASE_URL + XIVELY_FEED_ID + '/datastreams/temperature'+DEVICE_ID+'.png' + '?' + XIVELY_PARAMS;
        var UNITS = 'F';
        var graphDuration = '1hour';
        
        xively.setKey( XIVELY_KEY ); 
        
        var graphRefreshInterval = 60; // graph refresh interval in seconds
          
        function graph5min() {
            graphDuration = '5minute';
            document.getElementById('tempgraph').src=XIVELY_GRAPH_URL+'&duration=5minute';
        }
        
        function graph30min() {
            graphDuration = '30minute';
            document.getElementById('tempgraph').src=XIVELY_GRAPH_URL+'&duration=30minute';
        }
        
        function graph1hour() {
            graphDuration = '1hour';
            document.getElementById('tempgraph').src=XIVELY_GRAPH_URL+'&duration=1hour';
        }
        
        function graph3hour() {
            graphDuration = '1hour';
            document.getElementById('tempgraph').src=XIVELY_GRAPH_URL+'&duration=3hour';
        }
        
        function refreshTemp() {
            var feedID        = XIVELY_FEED_ID,            
                datastreamID  = 'temperature'+DEVICE_ID;
                
            xively.datastream.get (feedID, datastreamID, function ( datastream ) {
                if (UNITS == 'C') {
                    var temp = Math.round(10 * ((datastream['current_value'] - 32) / 1.8)) / 10;
                    $('#currentTemp').html(temp+'&deg'+UNITS);
                } else {
                    $('#currentTemp').html(datastream['current_value']+'&deg'+UNITS);
                }
            });
        }
        
        function refreshGraph() {
            document.getElementById('tempgraph').src=XIVELY_GRAPH_URL+'&duration='+graphDuration;        
        }
        
        function checkBatt() {
            var feedID        = XIVELY_FEED_ID,            
                datastreamID  = 'lowbatt'+DEVICE_ID;
                
            xively.datastream.get (feedID, datastreamID, function ( datastream ) {
                if (datastream['current_value'] == 1) {
                    console.log('low batt alert set!');
                    document.getElementById('lowbatt').style.display = 'block';
                } else {
                    console.log('low batt alert not set.')
                    document.getElementById('lowbatt').style.display = 'none';    
                }
            });
        }
        
        function refreshAll() {
            // grab the graph update right away
            refreshGraph();
            refreshTemp();
            checkBatt();
        }
        
        function toggleUnits() {
            if (UNITS == 'F') {
                UNITS = 'C';
            } else {
                UNITS = 'F';
            }
            refreshTemp();
        }
        
        // setInterval takes an interval in ms; multiply by 1000.
        refreshAll();
        setInterval(refreshAll, graphRefreshInterval * 1000);
        
        // refresh the entire page if the viewport is resized to make sure the chart is the right size
        window.onresize = function(event) {
            document.location.reload(true);
        }
    
      </script>
      </body>
    
    </html>"
}

/* DEVICE EVENT CALLBACKS ====================================================*/ 

device.on("newSchedule", function(val) {
    device.send("newSchedule", SCHEDULE);
});

/* HTTP REQUEST HANDLER =======================================================*/ 

http.onrequest(function(request, res) {
    server.log("Agent got new HTTP Request");
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (request.path == "/schedule" || request.path == "/schedule/") {
        try {
            SCHEDULE = http.jsondecode(req.body);
            device.send("newSchedule", SCHEDULE);
            res.send(200, "Schedule Set");
            server.save(SCHEDULE);
        } catch (err) {
            server.log(err);
            res.send(400, "Invalid Schedule: "+err);
        }
        
    } else {
        server.log("Agent got unknown request");
        res.send(200, WEBPAGE);
    }
});

/* RUNTIME BEGINS HERE =======================================================*/

server.log("Sprinkler Agent Started.");