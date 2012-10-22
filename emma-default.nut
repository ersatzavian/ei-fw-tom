/*
 * Emma Default "Firmware"
 * Emma - 8-digit x 17-segment 2.3" display for Electric Imp
 * Firmware includes scrolling for longer messages as well as
 * reading on-board digital Ambient Light Sensor with 20-second resolution
 * 
 * T. Buttner
 * 10/21/2012
 *
*/

server.log("Emma Started");

// Serial Interface to AS1110 Driver ICs
hardware.configure(SPI_257);
hardware.spi.configure(SIMPLEX_TX | LSB_FIRST | CLOCK_IDLE_LOW, 400);
// Byte Ordering:
// [digit 0 (left)][1][2][3][4][5][6][7 (right)][decimal point word]

// Configure oe_l and load as GPIO
hardware.pin2.configure(DIGITAL_OUT);
// pin 2 is pulled up inside the AS1110 driver, nominally disable
hardware.pin2.write(0);
hardware.pin1.configure(DIGITAL_OUT);
// pin 2 is pulled up inside the AS1110 driver, nominally disable
hardware.pin1.write(0);

// I2C Interface to TSL2561FN
hardware.configure(I2C_89);
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
local alsAddr = 0x52;

// number of bytes needed to write full display
local blobLen = 17;

// variable containing displayed string
local currentString = "I'M AN EMMA";
local needsUpdate = true;
// flag set when string has more than 8 printable characters
// this triggers message rotation
local overSizeString = false;
// current position in oversize string
local overSizeStringPos = 0;
// count in seconds for how long to hold a string on the right side of the display before looping
local holdRightCount = 0;

// push lux data every 30s
local luxUpdateCounter = 60;

// Output Port for ambient light sensor
local out_lux = OutputPort("outLux");

// hex translations of characters (upper case / alphanum only)
// LSB 
local hexTable= 
{
    ['0']=0x75AE,
    ['1']=0x0102,
    ['2']=0xE427,
    ['3']=0xA527,
    ['4']=0x8183,
    ['5']=0xA5A5,
    ['6']=0xE5A5,
    ['7']=0x102C,
    ['8']=0xE5A7,
    ['9']=0xA5A7,
    ['A']=0xC1A7,
    ['B']=0x2D37,
    ['C']=0x64A4,
    ['D']=0x2D36,
    ['E']=0xE4A5,
    ['F']=0xC0A5,
    ['G']=0x65A5,
    ['H']=0xC183,
    ['I']=0x2C34,
    ['J']=0x6506,
    ['K']=0xC288,
    ['L']=0x6480,
    ['M']=0x41CA,
    ['N']=0x43C2,
    ['O']=0x65A6,
    ['P']=0xC0A7,
    ['Q']=0x67A6,
    ['R']=0xC2A7,
    ['S']=0xA5A5,
    ['T']=0x0834,
    ['U']=0x6582,
    ['V']=0x5088,
    ['W']=0x6D82,
    ['X']=0x1248,
    ['Y']=0x0848,
    ['Z']=0x342C,
    [' ']=0x0000,
    // 39=apostrophe
    [39]=0x0008,
    ['$']=0xADB5,
    ['%']=0x9DB9,
    ['*']=0x9A59,
    ['-']=0x8001,
    ['+']=0x8811,
    ['<']=0x0208,
    ['>']=0x1040,
    ['\\']=0x0240,
    ['/']=0x1008,
    ['^']=0x1200,
    ['_']=0x2400
}

local function load() {
    imp.sleep(0.001);
    hardware.pin1.write(1);
    imp.sleep(0.001);
    hardware.pin1.write(0);
}

local function clear() {
    local outputVal = blob(blobLen);
    for (local i = 0; i < blobLen; i++) {
        outputVal.writen(0x00, 'b');
    }
    hardware.spi257.write(outputVal);
    load();
    server.log("Display Cleared");
}

local function encodeCharacter(inputChar, outputBlob) {
    //server.log(format("Encoding %c", inputChar));
    outputBlob.writen(hexTable[inputChar], 'w');
}

local function encodeDecimalPoint(position, decimalPointWord) {
    // lower byte of decimalPointWord addresses channels that are not used. 
    decimalPointWord = decimalPointWord | (0x1 << position+7);
    return decimalPointWord;
}

local function isPrintable(inputChar) {
    if (inputChar in hexTable) {
        return true;
    }
    return false;
}

local function startAls() {
    hardware.i2c89.write(alsAddr, "\x80\x03");
    // 400 ms required to integrate and complete conversion
}

local function readAls() {
    local reg0 = hardware.i2c89.read(alsAddr, "\xAC", 2);
    local reg1 = hardware.i2c89.read(alsAddr, "\xAE", 2);
    local lux = 0;
    if (reg0 == null || reg1 == null) {
        server.error("Lux conversion failed");
        return;
    }
    local channel0 = ((reg0[1] & 0xFF) << 8) | (reg0[0] & 0xFF);
    local channel1 = ((reg1[1] & 0xFF) << 8) | (reg1[0] & 0xFF);
    local ratio = channel1/channel0.tofloat();
    if (ratio <= 0.52) {
        lux = (0.0315 * channel0 - 0.0593 * channel0 * math.pow(ratio,1.4));
    } else if (0.52 < ratio <= 0.65) {
        lux = (0.0229 * channel0 - 0.0291 * channel1);
    } else if (0.65 < ratio <= 0.8) {
        lux = (0.0157 * channel0 - 0.0180 * channel1);
    } else if (0.80 < ratio <= 1.30) {
        lux = (0.00338 * channel0 - 0.00260 * channel1);
    } else {
        lux = 0;
    }
    server.show(format("%.2f lux", lux));
    out_lux.set(lux);
}

function get8Printables(inputString, startIndex) {
    local count = 0;
    local i = 0;
    for (i = startIndex; i < inputString.len(); i++) {
        if (isPrintable(inputString[i])) {
            count++;
        }
        //server.log(format("%d:%c", i, inputString[i]));
        if (count == 8) {
            // grab period-at-end-of-sentence special case
            if (i+1 < inputString.len()) {
                if (inputString[i+1] == '.') {
                    return i+1;
                }
            }
            return i;
        }
    }
    server.log(format("get8Printables: couldn't find 8 printable chars after index %d", startIndex));
    return i-1;
}

// windows oversize strings, removes non-printable characters, pads short strings
function prepString(inputString) {
    local inputLen = inputString.len();
    local position = 0;
    local printableLen = 0;
    
    // mechanism to hold display at right side when looping
    if (holdRightCount != 0) {
        needsUpdate = false;
        holdRightCount--;
        return "";
    } else {
        needsUpdate = true;
    }

    // count printable characters, handle nonprintables
    while (position < inputLen) {
        if (inputString[position] == '.') {
            position++;
            continue;
        } 
        // it wasn't a decimal point. Replace NPCs and count.
        if (!isPrintable(inputString[position])) {
           inputString[postion] = ' ';
        }
        position++;
        printableLen++;
    }
    
    // handle over-size strings
    if (printableLen > 8) {
        overSizeString = true;
        local endSliceIndex = get8Printables(inputString, overSizeStringPos);
        server.log(format("prepared string:%s", inputString.slice(overSizeStringPos, endSliceIndex+1)));
        local returnString = inputString.slice(overSizeStringPos, endSliceIndex+1);
        
        // catch end-of-string condition and hold at right side
        if ((endSliceIndex + 1) == inputLen) {
            // loop back to left edge of line if we hit the right edge
            overSizeStringPos = 0;
            // pause before printing the beginning of the string again
            holdRightCount = 20;
        } else {
            overSizeStringPos++;
        }
        return returnString;
    } else {
        // otherwise the string is less than the display length and should be right-justified
        overSizeString = false;
        // pad the left side of the string
        for (local i = 0; i < (8-printableLen); i++) {
            inputString = " "+inputString;
        }
        return inputString;
    }
    
}

// actual set-display-to-current-stored-string function
function setDisplay() {
    // prepare string for printing (deal with periods and non-printables, window for display)
    local displayString = prepString(currentString);
    
    if (needsUpdate) {        
        local inputPosition = 0;
        local outputPosition = 0;
        local outputBlob = blob(blobLen);
        local inputLen = displayString.len();
        local decimalPointWord = 0x0000;
            
        // pad in dummy value of decimal point word. We will re-write this after encoding
        outputBlob.writen(0x0000, 'w');
            
        while (inputPosition < inputLen) {
            local inputChar = displayString[inputPosition];
            if (inputChar == '.') {
                // don't advance the output position counter on decimal point
                decimalPointWord = encodeDecimalPoint(outputPosition, decimalPointWord);
            } else {
                encodeCharacter(inputChar, outputBlob);
                outputPosition++;
            }
        inputPosition++;
        }
        // add the decimal point word, fully populated
        // return blob write pointer to beginning of the blob and write in decimal point word
        outputBlob.seek(0,'b');
        outputBlob.writen(decimalPointWord, 'w');
        // send the blob to the display
        hardware.spi257.write(outputBlob);
        load();
        if (overSizeString) {
            needsUpdate = true;
        } else {
            needsUpdate = false;
        }
    }
    // read the ALS, since it should be ready by now
    if (luxUpdateCounter == 0) {
        readAls();
        luxUpdateCounter = 30;
    } else {
        luxUpdateCounter--;
    }
    // start the next ALS conversion
    startAls();
    
    // schedule next check for .5 seconds from now
    imp.wakeup(0.2, setDisplay);
}

class displayInput extends InputPort
{
    name = "8-Char Input"
    type = "string"
    
    // we prepare the string for printing here
    function set(inputString) {
        inputString = inputString.tostring();
        inputString = inputString.toupper();
        server.log(format("Received %s",inputString));        
        currentString = inputString;
        // set the update flag and wait for display to update
        server.log("Setting needsUpdate flag");
        needsUpdate = true;
        
        // reset other flags that will be determined when prepping string
        overSizeString = false;
        overSizeStringPos = 0;
    }
}

// Time mm:ss
imp.configure("Emma 8-Char Display", [displayInput()], [out_lux]);
clear();
startAls();
setDisplay();

// Emergency use only - recover from erroring imp not in planner case
//imp.configure("Help me", [], []);
