// Thermal Printer Impee
// Uses CSN-A2-T thermal receipt printer from Adafruit
// Imp sends serial commands to the printer on UART57

// Lots of ASCII to be used, so we'll define the relevant non-printables here 
const LF = 0x0A;
const HT = 0x09; // Horizontal TAB
const ESC = 0x1B;
const GS = 0x1D; // group seperator
const SP = 0x20; // space
const FF = 0x0C; // NP form feed; new page
// chunk size for downloading image data buffers from the agent
// equal to one paper width
const CHUNK_SIZE = 384;

// printer default baud rate is generally 19200. Print a test page to verify.
hardware.uart57.configure(19200, 8, PARITY_NONE, 1, NO_CTSRTS);

// register with the imp service
imp.configure("Thermal Printer", [], []);

// printer needs a moment of warmup time on power-on
imp.sleep(0.5);

class printer {
    /* Print Commands
    LF          -> Print and line feed
    HT (TAB)    -> Jump to next TAB position
    ESC FF      -> Print the data in the buffer
    ESC J       -> Print and feed n dots paper
    ESC d       -> Print and feed n lines
    */
    // some basic printer parameters
    printDensity = 14 // yields 120% density, experimentally determined to be good
    printBreakTime = 4 // 500 us; slower but darker
    dotPrintTime = 30000; // time to print a single-dot line in us
    dotFeedTime = 2100; // time to feed a single-dot line in us
    // current mode of the printer, in case we need to check and see
    lineSpacing = 32
    bold = false
    underline = false
    justify = "left"
    reverse = false
    updown = false
    emphasized = false
    doubleHeight = false
    doubleWidth = false
    deleteLine = false
    // the actual byte sent to the printer to select modes.
    // masked in methods below to set mode
    modeByte = 0x00
    // pointers for image download from the agent
    imageDataLength = 0
    loadedDataLength = 0
    // image parameters need to be written out on each row as we stream in an image
    imageWidth = 0;
    imageHeight = 0;
    
    constructor() {
        // the imp can be reset without resetting the printer
        // clear the mode and the buffer every time we construct a new printer
        this.reset();
    }
    
    // reset printer to default mode and print settings
    function reset() {
        // reset the class parameters
        this.modeByte = 0x00;
        this.reverse = false;
        this.updown = false;
        this.emphasized = false;
        this.doubleHeight = false;
        this.doubleWidth = false;
        this.deleteLine = false;
        this.justify = "left";
        this.bold = false;
        this.underline = false;
        this.lineSpacing = 32;
        
        // reset the image download pointer
        this.imageDataLength = 0;
        this.loadedDataLength = 0; 
        // and the image parameters
        this.imageWidth = 0;
        this.imageHeight = 0;
        
        // send the printer reset command
        hardware.uart57.write(ESC);
        hardware.uart57.write('@');

        // set the basic printer settings
        hardware.uart57.write(ESC);
        hardware.uart57.write('7');
        // ESC 7 n1 n2 n3 
        // n1 = 0-255: max printing dots, unit = 8 dots, default = 7 (64 dots)
        // n2 = 3-255: heating time, unit = 10 us, default = 80 (800 us)
        // n3 = 0-255: heating interval, unit = 10 us, default = 2 (20 us)
        // first, set the "printing dots"
        // more max dots -> faster printing. Max heating dots is 8*(n1+1)
        // more heating -> slower printing
        // not enough heating -> blank page
        hardware.uart57.write(20); // Adafruit's library uses this default setting as well
        // now set the heating time
        hardware.uart57.write(255); // max heating time
        // last, the heat interval
        hardware.uart57.write(250); // 500 us -> slower but darker

        // set the print density as well
        hardware.uart57.write(18);
        hardware.uart57.write(35); 
        // 18 35 N
        // N[4:0] sets printing density (50% + 5% * N[4:0])
        // N[7:5] sets printing break time (250us * N[5:7])
        hardware.uart57.write((this.printBreakTime << 5) | this.printDensity);
        
        imp.sleep(1);
        server.log("Printer Ready.");
    }
    
    // Load a buffer and print it immediately
    function print(printStr) {
        // load the string into the buffer
        hardware.uart57.write(printStr);
        hardware.uart57.write("\n");
        // print the buffer
        hardware.uart57.write(FF);
    }
    
    // load buffer into the printer's buffer without printing
    function load(buffer) {
        hardware.uart57.write(buffer);
    }
    
    // this function pulls data from the agent down to the imp, which can then push it to the printer
    // part of the printer class because it eventually calls the "print downloaded image command" itself
    function pull() {
        if(this.loadedDataLength < this.imageDataLength) {
            agent.send("pull", CHUNK_SIZE);
        } else {        
            // reset image download pointers
            this.imageDataLength = 0;
            this.loadedDataLength = 0;
            // tell the agent we're done and it should reset download pointers too
            agent.send("imageDone", 0);
            imp.sleep(0.5);
            this.reset();
            server.log("Device: done loading image");
        }
    }
    
    // this function writes a row of bitmap image data to the printer
    function printImgRow(buffer) {
        hardware.uart57.write(18);
        hardware.uart57.write(42);
        hardware.uart57.write(8);
        hardware.uart57.write(this.imageWidth / 8);
        //hardware.uart57.write(this.imageHeight);
        hardware.uart57.write(buffer);
        imp.sleep(0.02);
    }
    
    // print the buffer and feed n lines
    function feed(lines) {
        while(lines--) {
            this.print("\n");
        }
    }
    
    // set line spacing to 'n' dots (default is 32)
    function setLineSpacing(dots = 32) {
        hardware.uart57.write(ESC);
        if (dots == 32) {
            // just set default line spacing if called with no or an invalid argument
            hardware.uart57.write('2');
            this.lineSpacing = 32;
        } else if (dots > 0 && dots < 256) {
            hardware.uart57.write('3');
            hardware.uart57.write(dots);
            this.lineSpacing = dots;
        } else {
            server.error("Setting line spacing to invalid value (0-255 dots per line)");
        }
    }
    
    // select justification
    function setJustify(justifyValue) {
        local justifyByte = 0;
        if (justifyValue == "left") {
            justifyByte = 0;
            this.justify = "left";
        } else if (justifyValue == "center") {
            justifyByte = 1;
            this.justify = "center";
        } else if (justifyValue == "right") {
            justifyByte = 2;
            this.justify = "right";
        } else {
            server.error("Invalid Justify (left, center, right)");
            return;
        }
        hardware.uart57.write(ESC);
        hardware.uart57.write('a');
        hardware.uart57.write(justifyByte);
    }
    
    // write mode byte to device
    // functions below are used to mask modes on and off in the mode byte
    function writeMode() {
        hardware.uart57.write(ESC);
        hardware.uart57.write('!');
        hardware.uart57.write(this.modeByte);
    }
    
    // toggle bold print
    // takes one boolean argument
    // defaults to true
    function setBold(value = true) {
        hardware.uart57.write(ESC);
        hardware.uart57.write(SP);
        if (value) {
            hardware.uart57.write(1);
            this.bold = true;
        } else {
            hardware.uart57.write(0);
            this.bold = false;
        }
    }
    
    // set underline weight
    function setUnderline(value = true) {
        // send the command to set underline weight
        hardware.uart57.write(ESC);
        hardware.uart57.write(0x2D);
        // we'll just support two weights: none and "2" (max)
        if (value) {
            hardware.uart57.write(2);
            this.underline = true;
        } else {
            hardware.uart57.write(0);
            this.underline = false;
        }
    }
    
    // toggle reverse mode
    function setReverse(value = true) {
        if (value) {
            this.modeByte = this.modeByte | 0x02;
            this.reverse = true;
        } else {
            this.modeByte = this.modeByte & 0xFD;
            this.reverse = false;
        }
        this.writeMode();
    }
    
    // toggle updown mode
    function setUpdown(value = true) {
        if (value) {
            this.modeByte = this.modeByte | 0x04;
            this.updown = true;
        } else {
            this.modeByte = this.modeByte & 0xFB;
            this.updown = false;
        }
        this.writeMode();
    }
    
    // toggle emphasized mode
    function setEmphasized(value = true) {
        if (value) {
            this.modeByte = this.modeByte | 0x08;
            this.emphasized = true;
        } else {
            this.modeByte = this.modeByte & 0xF7;
            this.emphasized = false;
        }
        this.writeMode();
    }
    
    // toggle double height mode
    function setDoubleHeight(value = true) {
        if (value) {
            this.modeByte = this.modeByte | 0x10;
            this.doubleHeight = true;
        } else {
            this.modeByte = this.modeByte & 0xEF;
            this.doubleHeight = false;
        }
        this.writeMode();
    }    
    
    // toggle double width mode
    function setDoubleWidth(value = true) {
        if (value) {
            this.modeByte = this.modeByte | 0x20;
            this.doubleWidth = true;
        } else {
            this.modeByte = this.modeByte & 0xDF;
            this.doubleWidth = false;
        }
        this.writeMode();
    }
    
    // toggle deleteLine mode
    function setDeleteLine(value = true) {
        if (value) {
            this.modeByte = this.modeByte | 0x40;
            this.deleteLine = true;
        } else {
            this.modeByte = this.modeByte & 0xBF;
            this.deleteLine = false;
        }
        this.writeMode();
    }

}

myPrinter <- printer();

function ei() {
    myPrinter.setJustify("center");
    myPrinter.setBold(true);
    myPrinter.print("electric imp");
    myPrinter.feed(1);
    myPrinter.reset();
}

// print the imp logo on startup
agent.send("logo", null);
imp.wakeup(12.0, ei);
// once this callback is done, we've printed the logo and "electric imp" and reset the printer

// Register some hooks for the agent to call, allowing the agent to push actions to the device
// the most obvious: print a buffer of data
agent.on("print", function(buffer) {
    server.log("Device: printing new buffer from agent: "+buffer);
    myPrinter.print(buffer);
});

// provides info on a bitmap to download and print
// params is an array [buffer length, width in px, height in px, starting offset]
agent.on("downloadImage", function(params) {
    // put the printer into bitmap image mode
    // store the info from the agent on how big this buffer is and where we are now
    myPrinter.imageDataLength = params[0];
    myPrinter.loadedDataLength = 0;
    myPrinter.imageWidth = params[1];
    myPrinter.imageHeight = params[2];
    // begin pulling data from the agent, which responds with "load"
    server.log(format("Device: Pulling %d byte buffer from agent in chunks of %d bytes", myPrinter.imageDataLength, CHUNK_SIZE));
    myPrinter.pull();
});

// load chunks of an image as pulled from agent
agent.on("imgData", function(buffer) {
    myPrinter.printImgRow(buffer);
    myPrinter.loadedDataLength += buffer.len();
    server.log("Loaded "+myPrinter.loadedDataLength+" bytes");
    // wait a moment - can't use imp.wakeup here due to a bug that causes variables to be freed prematurely
    imp.sleep(0.01);
    myPrinter.pull();
});

// allow the agent to load a buffer without printing
agent.on("load", function(buffer) {
    myPrinter.load(buffer);
});

agent.on("feed", function(lines) {
    myPrinter.feed(lines);
});

agent.on("bold", function(value) {
    myPrinter.setBold(value);
});

agent.on("underline", function(value) {
    myPrinter.setUnderline(value);
});

// allow the agent to clear the printer's mode and reset default settings
agent.on("reset", function(value) {
    myPrinter.reset();
});

agent.on("lineSpacing", function(dots) {
    myPrinter.setLineSpacing(dots);
});

agent.on("justify", function(value) {
    myPrinter.setJustify(value);
});

agent.on("reverse", function(value) {
    myPrinter.setReverse(value);
});

agent.on("updown", function(value) {
    myPrinter.setUpdown(value);
});

agent.on("emphasized", function(value) {
    myPrinter.setEmphasized(value);
});

agent.on("doubleHeight", function(value) {
    myPrinter.setDoubleHeight(value);
});

agent.on("doubleWidth", function(value) {
    myPrinter.setDoubleWidth(value);
});

agent.on("deleteLine", function(value) {
    myPrinter.setDeleteLine(value);
});