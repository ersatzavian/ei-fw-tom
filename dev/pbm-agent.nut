/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/* Electric Imp Thermal Printer Agent

 This agent is your printer's internet interface. Print text messages by sending them to 
 <agent_url>/text.

 This agent is designed to accept 384-pixel-wide PBM images in one of two ways:

 1. Direct POST to <agent_url>/image
 2. POST a URL to <agent_url>/fetch. The agent will fetch your image from the given URL.

 For more information on the PBM file format and the Netpbm suite, have a look at:
 http://netpbm.sourceforge.net/doc/index.html#impconv
*/

server.log("Printer Agent Started");

// a list of message parameters we support
// we really only need the keys, but put in dummy values to prevent the possibility of a non-working state
msgParams <- {
    justify = "left",
    bold = false,
    underline = false,
    deleteLine = false,
    reverse = false,
    updown = false
}

function stripPbmComments(pbm) {
    server.log("Agent: PBM is "+pbm.len()+" lines with comments");
    local strippedPbm = [];
    foreach (line in pbm) {
        if (line[0] == '#') {
            // don't append to the stripped file
            server.log("Tossing comment line of length "+line.len());
        } else {
            server.log("Keeping data line of length "+line.len());
            strippedPbm.append(line);
        }
    }
    server.log("Agent: PBM is "+strippedPbm.len()+" lines without comments");
    return strippedPbm;
}

// handler to parse and relay a pbm image to the printer
function printPBM(pbm) {
    server.log(pbm);
    pbm = split(pbm, "\n");
    server.log(pbm);
    local image = {};
    pbm = stripPbmComments(pbm);
    local formatkey = pbm[0];
    server.log("Format Key: "+formatkey);
    local width = (split(pbm[1].tostring()," ")[0]).tointeger();         // width in pixels
    local height = (split(pbm[1].tostring(), " ")[1]).tointeger();       // height in pixels
    //local length = (width * height) / 8;        // file length in bytes
    server.log("Width: "+width+" px.");
    server.log("Height: "+height+" px.");

    image.width <- width;
    image.height <- height;
    image.data <- pbm[2];

    device.send("image", image);
}

http.onrequest(function(request,res){
    // regardless of response, we need the proper headers to allow cross-origin requests
    // NOTE: You may want to set this field to allow only the domain you expect (and want to allow)
    // requests from. 
    res.header("Access-Control-Allow-Origin", "*");
    // NOTE: if you're sending data cross-site, you won't even see your request body unless these headers 
    // are set to allow your request in. The client-side will send a "preflight check" to test whether
    // the agent will accept the request, and if not, request.body is going to come up empty
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
        
    // new text-based message handler
    if (request.path == "/text") {
        server.log("Agent got new text message: "+request.body);
        try {
            local message = http.jsondecode(request.body);
            //server.log("Text of message: "+message.text);
            // set up the printer to print the way we've been instructed to
            foreach (key, value in msgParams) {
                //server.log("setting "+key+" to "+message[key]);
                device.send(key, message[key]);
            }
            // now feed the message down and print it
            // the PHP script that feeds us text takes care of doing the word wrapping 
            device.send("print", message.text);
            
            res.send(200, "printed");
        } catch (err) {
            res.send(400, "request error");
            server.log("Agent: Error parsing new message");    
        }
    } 
    
    // new image handler
    else if (request.path == "/image") {
        //local pbm = http.base64decode(request.body);
        local pbm = request.body;
        server.log("Agent: got image of length "+pbm.len());

        // send response 
        res.send(200, "Printing.\n");

        // process pbm image and relay it to the printer
        printPBM(pbm);
    } 

    // get a new URL and go fetch an image from that location.
    else if (request.path == "/fetch") {

    } else {
        server.log("Agent got unknown request: "+request.body);
        res.send(400, "request error");
    }
});

device.on("logo", function(value) {
    printLogo();
});
