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
    
        <title>Janice</title>
        <link href='data:image/x-icon;base64,AAABAAEAEBAAAAAAAABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAD///8A////AP///wD///8A////AP///wD///8AcHBwMl9rT65DZwZX////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8Aam9ioUxuHv9FbgX/Q28DV////wD///8A////AP///wD///8A////AP///wD///8A////AP///wByb29VU3Qz/UZ1Bv9GdQb/RnUG/0Z1Blf///8A////AP///wD///8A////AP///wD///8A////AP///wD///8ASn0U+0d9CP9HfQj/R30I/0d9CP9WeC+RbW1tFf///wD///8A////AP///wD///8A////AP///wD///8A////AEmEBf9JhAX/SYQF/0mEBf9JhAX/S4sYoGV8W/lxbGw0////AP///wD///8A////AP///wD///8A////AP///wBKiwb/SosG/0qLBv9Kiwb/SosG/02RIKBQmD7/VpNH/211aNp1amoY////AP///wD///8A////AP///wD///8AS5IA/0uSAP9LkgD/S5IA/0qTAP5OmSaUUp5N/1KeTf9Snk3/YIxcv////wD///8A////AP///wD///8A////AE2aAP9NmgD/TZoA/0yaAO1OmgaDXZhdaFSkV/9UpFf/VKRX/1eiWb////8A////AP///wD///8A////AP///wBNngD/TZ4A/02eAPxQnQlwaYBcUFypTqBWp1z/Vqdc/1anXP9YpF2/////AP///wD///8A////AP///wD///8AT6YA/06mALRreWVyaada+Ga3Uf9gtFugWK9l/1ivZf9Yr2X/Watnv////wD///8A////AP///wD///8A////AFGrAExup2x0a75p/2u+af9rvmn/aL1qZVu1cOBbtm//W7Zv/12zb7////8A////AP///wD///8A////AP///wD///8AcMN/u3DEfv9wxH7/cMR+/2/EflcA//8BXr53jV++eP9gune/////AP///wD///8A////AP///wD///8A////AHfIkbt3yZH/d8mR/3fJkf94ypBX////AP///wD///8BYcSAhv///wD///8A////AP///wD///8A////AP///wB9z6K7fs+j/37Po/9+zqLnZsyZBf///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8Ag9O0u4PUs+WD07Yj////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AIjcxjr///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A/38AAPx/AAD4fwAA8D8AAPAfAADwBwAA8AMAAPBDAADxgwAA8gMAAPxDAAD4YwAA+HsAAPh/AAD5/wAA//8AAA==' rel='icon' type='image/x-icon' /> 
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
              <a class='navbar-brand'>Sprinker Control</a>
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
                    <h2 style='display: inline'>Watering Schedule</h2>
                    <button type='button' class='btn btn-default' style='vertical-align: top; margin-left: 15px;' onclick='newEntry()'><span class='glyphicon glyphicon-plus'></span> New</button></div>
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
      <script type='text/javascript' src='https://cdn.firebase.com/v0/firebase.js'></script>
    
      <script>
      
        function showSchedule(rawdata) {
            console.log('got schedule from agent: '+rawdata);
            var data = JSON.parse(rawdata);
            if (Object.keys(data).length > 0) {
                for(var key in data) {
                    newEntry();
                    $('.water-control').last().children()[0].value = data[key].onat;
                    $('.water-control').last().children()[1].value = data[key].offat;
                    for (var i = 0; i < data[key].channels.length; i++) {
                        var ch = data[key].channels[i];
                        $('.water-channels').last().find('#'+ch)[0].checked = 1;
                    }
                }
            } else {
                console.log('Invalid Schedule Received from Agent: '+rawdata);
            }
        }
      
        $.ajax({
            url: document.URL+'/getSchedule',
            type: 'GET',
            success: showSchedule,
            error: function() {
                console.log('error in ajax call!');
            }
        });
      
        function logSuccess(title, message, autoclear) {
            autoclear = autoclear || true;
            var t = new Date().getTime();
            $('#top').append('<div id=\'' + t + '\' class=\'alert alert-success\'><button type=\'button\' class=\'close\' data-dismiss=\'alert\'>x</button><strong>' + title + '</strong>&nbsp;' + message + '</div>');
            if (autoclear) {
                window.setTimeout(function() { $('#' + t).alert('close'); }, 3000);
            }
        }
        
        var entryHtml = " + "\""+@"<div class='well row' style='width: 80%; margin-left: 20px;'>\
                                <div class='col-md-4'>\
                                    <p style='margin-top: 10px'><strong>Start watering at (24h): </strong></p>\
                                    <p style='margin-top: 10px'><strong>Stop Watering at (24h): </strong></p>\
                                    <p style='margin-top: 10px'><strong>Zones: </strong></p>\
                                </div>\
                                <div class='col-md-8 water-control'>\
                                    <input type='text' class='form-control water-onat' placeholder='eg: 14:00'>\
                                    <input type='text' class='form-control water-offat' placeholder='eg: 16:00'>\
                                    <div class='water-channels'>\
                                        <label class='checkbox-inline'><input type='checkbox' id='0' value='channel1'> 1</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='1' value='channel2'> 2</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='2' value='channel3'> 3</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='3' value='channel4'> 4</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='4' value='channel5'> 5</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='5' value='channel6'> 6</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='6' value='channel7'> 7</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='7' value='channel8'> 8</label>\
                                    </div>\
                                </div>\
                                <div class='col-md-1 col-md-offset-6'>\
                                    <button type='button' class='btn btn-danger' style='margin-top: 10px;' onclick='$(this).parent().parent().remove();'>Remove</button>\
                                </div>\
                                </div>" + "\";" + @"
                                
        function newEntry() {
            $('#entries').append(entryHtml);
        }  
        
        function save() {
            var sendTo = document.URL+'/setSchedule'
            
            var waterings = $('.water-control');
            var schedule = {};
            var i = 0;
            
            waterings.each(function() {
                var channels = [];
                for (var ch = 0; ch < 8; ch++) {
                    if ($(this).find('#'+ch)[0].checked == 1) {
                        channels.push(ch);
                    };
                }
                schedule[i] = {
                    'onat': $(this).children()[0].value,
                    'offat': $(this).children()[1].value,
                    'channels': channels
                };
                i++;
            });
            
            $.ajax({
                url: sendTo,
                type: 'POST',
                dataType: 'application/json',
                data: JSON.stringify(schedule)
            });
    
      }
    
      </script>
      </body>
    
    </html>"
}

/* DEVICE EVENT CALLBACKS ====================================================*/ 

device.on("getSchedule", function(val) {
    device.send("newSchedule", SCHEDULE);
});

/* HTTP REQUEST HANDLER =======================================================*/ 

http.onrequest(function(req, res) {
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (req.path == "/setSchedule" || req.path == "/setSchedule/") {
        server.log("Agent got new Schedule Set request");
        try {
            SCHEDULE = http.jsondecode(req.body);
            device.send("newSchedule", SCHEDULE);
            res.send(200, "Schedule Set");
            server.log("New Schedule Set: "+req.body);
            server.save(SCHEDULE);
        } catch (err) {
            server.log(err);
            res.send(400, "Invalid Schedule: "+err);
        }
        
    } else if (req.path == "/getSchedule" || req.path == "/getSchedule/") {
        server.log("Agent got schedule request");
        res.send(200,http.jsonencode(SCHEDULE));  
    } else {
        server.log("Agent got unknown request");
        res.send(200, WEBPAGE);
    }
});

/* RUNTIME BEGINS HERE =======================================================*/

server.log("Sprinkler Agent Started.");

prepWebpage();