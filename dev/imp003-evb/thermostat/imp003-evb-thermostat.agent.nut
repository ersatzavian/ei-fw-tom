// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// Agent Code

target <- 30.0;
current <- "Unkown";

device.send("target", target);
device.on("current", function(t){ current <- format("%0.1f C",t)});

http.onrequest(function(request,res){
    if(request.method == "POST"){
        local post = http.urldecode(request.body);
        if("target" in post){
            target = post.target.tofloat();
            device.send("target", target);
        }
    }
    
    local html = "<html><body><form method='post'>Current Temperature: "+current+"<input type='submit' value='Refresh'><br><form method='post'>Set Temperature: <input name='target' type='number' min='20' max='40' step='0.5' value='"+target+"'><input type='submit'></form></body></html>";
    res.send(200,html);
    
});