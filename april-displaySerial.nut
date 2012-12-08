// Shows input on parallax 16x2 UART display

function busywait(time) {
    local counter = 0;
    while ( counter < (time*500000) ) {
        counter++;
    }
    server.log("Waited "+time+" seconds");
}

class parDisplay
{
    serPort = null;
    // clear screen
    CTRL_CLEAR = 0x0C;
    // new line
    CTRL_NEWL = 0x0D;
    // backlight on
    CTRL_BLON = 0x11;
    // backlight off
    CTRL_BLOFF = 0x12;
    // sound tone at concert A (440 Hz)
    CTRL_SNDA = 0xDC;
    
    constructor(port)
    {
        if (port == UART_57) {
            hardware.configure(UART_57);
            serPort = hardware.uart57;
            server.log("Configured UART 57")
        } else if (port == UART_12) {
            hardware.configure(UART_12);
            serPort = hardware.uart12;
            server.log("Configured UART 12")
        } else {
            server.log("Invalid UART port specified.")
        }
        
        serPort.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS);
        
        // start with cleared screen
        clear();
    }
    
    function clear() {
        serPort.write(CTRL_CLEAR);
    }
    
    function newl() {
        serPort.write(CTRL_NEWL);
    }
    
    function toneA() {
        serPort.write(CTRL_SNDA);
    }
    
    function light(state) {
        if (state == 0) {
            server.log("Light off")
            serPort.write(CTRL_BLOFF);
        } else {
            server.log("Light on")
            serPort.write(CTRL_BLON);
        }
    }
    
    function print(inputString) {
        foreach (item in inputString) {
            serPort.write(item);
        }
    }
}

class displayInput extends InputPort
{
    name = "Number Input"
    type = "number"
    
    function set(value) {
        local display = parDisplay(UART_57);
        display.light(1);
        local printString = format("%c", value);
        display.print(value+" Imps Online");
        busywait(5);
        display.light(0);
    }

}

server.log("Disp UART: Start");
imp.configure("Disp UART", [ displayInput() ], []);

//EOF