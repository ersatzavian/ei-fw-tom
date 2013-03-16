// Adafruit thermal printer
server.log("Printer Started");

// Hardware Configuration
local serial = hardware.uart57;
serial.configure(19200, 8, PARITY_NONE, 1, NO_CTSRTS);

local text = null;

local function writeString(a) {
    server.log(format("Actually printing: %s", a));
    foreach(c in a) {
        serial.write(c);
    }
}

local function printThing() {

}

class printInput extends InputPort {
    function set(s) {
        text = s;
        if (text != null){
            server.log(format("Readying print: %s", text));
    
            writeString(text + "\r\n");
    
            // Some blank lines between each print
            writeString("\r\n\r\n");
        
            text=null;
        
        }
    }
}


imp.configure("Printer", [printInput()], []);


