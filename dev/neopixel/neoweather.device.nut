/* Weather Effects Driver for WS2812 "Neopixel" LED Driver
 * Copyright (C) 2014 Electric Imp, inc.
 * 
 * Uses SPI to emulate 1-wire
 * http://learn.adafruit.com/adafruit-neopixel-uberguide/advanced-coding
 *
 */
 
/* CONSTS AND GLOBALS --------------------------------------------------------*/

// constants for using SPI to emulate 1-wire
const ZERO      = 0xC0;
const ONE       = 0xF8;
const SPICLK    = 7500; // kHz

// This is used for timing testing only
us <- hardware.micros.bindenv(hardware);

/* This class requires the use of SPI257, which must be run at 7.5MHz 
 * to support neopixel timing. */
const SPICLK = 7500; // kHz

// This is used for timing testing only
us <- hardware.micros.bindenv(hardware);

class NeoPixels {
    
    // This class uses SPI to emulate the newpixels' one-wire protocol. 
    // This requires one byte per bit to send data at 7.5 MHz via SPI. 
    // These consts define the "waveform" to represent a zero or one 
    ZERO            = 0xC0;
    ONE             = 0xF8;
    BYTESPERPIXEL   = 24;
    
    // when instantiated, the neopixel class will fill this array with blobs to 
    // represent the waveforms to send the numbers 0 to 255. This allows the blobs to be
    // copied in directly, instead of being built for each pixel - which makes the class faster.
    bits            = null;
    // Like bits, this blob holds the waveform to send the color [0,0,0], to clear pixels faster
    clearblob       = blob(24);
    
    // private variables passed into the constructor
    spi             = null; // imp SPI interface (pre-configured)
    frameSize       = null; // number of pixels per frame
    frame           = null; // a blob to hold the current frame

    // _spi - A configured spi (MSB_FIRST, 7.5MHz)
    // _frameSize - Number of Pixels per frame
    constructor(_spi, _frameSize) {
        this.spi = _spi;
        this.frameSize = _frameSize;
        this.frame = blob(frameSize*27 + 1);
        
        // prepare the bits array and the clearblob blob
        initialize();
        
        clearFrame();
        writeFrame();
    }
    
    // fill the array of representative 1-wire waveforms. 
    // done by the constructor at instantiation.
    function initialize() {
        // fill the bits array first
        bits = array(256);
        for (local i = 0; i < 256; i++) {
            local valblob = blob(BYTESPERPIXEL / 3);
            valblob.writen((i & 0x80) ? ONE:ZERO,'b');
            valblob.writen((i & 0x40) ? ONE:ZERO,'b');
            valblob.writen((i & 0x20) ? ONE:ZERO,'b');
            valblob.writen((i & 0x10) ? ONE:ZERO,'b');
            valblob.writen((i & 0x08) ? ONE:ZERO,'b');
            valblob.writen((i & 0x04) ? ONE:ZERO,'b');
            valblob.writen((i & 0x02) ? ONE:ZERO,'b');
            valblob.writen((i & 0x01) ? ONE:ZERO,'b');
            bits[i] = valblob;
        }
        
        // now fill the clearblob
        for(local j = 0; j < 24; j++) {
            clearblob.writen(ZERO, 'b');
        }
        // must have a null at the end to drive MOSI low
        clearblob.writen(0x00,'b');
    }

    // sets a pixel in the frame buffer
    // but does not write it to the pixel strip
    // color is an array of the form [r, g, b]
    function writePixel(p, color) {
        frame.seek(p*BYTESPERPIXEL);
        // red and green are swapped for some reason, so swizzle them back 
        frame.writeblob(bits[color[1]]);
        frame.writeblob(bits[color[0]]);
        frame.writeblob(bits[color[2]]);    
    }
    
    // Clears the frame buffer
    // but does not write it to the pixel strip
    function clearFrame() {
        frame.seek(0);
        for (local p = 0; p < frameSize; p++) frame.writeblob(clearblob);
    }
    
    // writes the frame buffer to the pixel strip
    // ie - this function changes the pixel strip
    function writeFrame() {
        spi.write(frame);
    }
}

class NeoWeather extends NeoPixels {
    
    REFRESHPERIOD   = 0.05; // effects refresh 10 times per second
    NEWPIXELFACTOR  = 1000; // 1/100 pixels will show a new "drop" for a factor 1 effect
    LIGHTNINGFACTOR = 5000; // factor/5000 refreshes will yield lightning
    SCALE           = 100;  // NEWPIXELFACTOR / maximum "factor" value provided to an effect
                            // this class uses factor 0-10 to set intensity
    MAXNEWDROP      = 500;  // max percent chance a new drop will occur on an empty pixel
    MAXLIGHTNING    = 10;   // max percentage chance lightning will occur on an frame
    LTBRTSCALE      = 3.1;  // amount to scale lightning brightness with intensity factor
    DIMPIXELPERCENT = 0.8;  // percent of previous value to dim a pixel to when fading
    
    /* default color values */
    RED     = [16,0,0];
    GREEN   = [0,16,0];
    BLUE    = [0,0,16];
    YELLOW  = [8,8,0];
    CYAN    = [0,8,8];
    MAGENTA = [8,0,8];
    ORANGE  = [16,8,0];
    WHITE   = [7,8,8];
    
    // an array of [r,g,b] arrays to describe the next frame to be displayed
    pixelvalues = [];
    wakehandle = 0; // keep track of the next imp.wakeup handle, so we can cancel if changing effects
    
    constructor(_spi, _frameSize) {
        base.constructor(_spi, _frameSize);
        pixelvalues = [];
        for (local x = 0; x < _frameSize; x++) { pixelvalues.push([0,0,0]); }
    }

    /* Stop all effects from displaying and blank out all the pixels.
     * Input: (none)
     * Return: (none)
     */
    function stop() {
        // cancel any previous effect currently running
        imp.cancelwakeup(wakehandle);
        dialvalues = array(_frameSize, [0,0,0]);
        draw();
    }
    
    /* Blue and Purple fading dots effect.
     * Factor is 1 to 10 and scales the number of new raindrops per refresh.
     */
    function rain(factor) {
        local NUMCOLORS = 2;
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
 
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {rain(factor)}.bindenv(this));
        
        local newdrop = 0;
        local threshold = (factor * SCALE);
        if (threshold < NUMCOLORS) { threshold = NUMCOLORS; }
        if (threshold > MAXNEWDROP) { threshold = MAXNEWDROP; }
        local next = false;
        clearFrame();
        for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
            // if there's any color data in this pixel, fade it down 
            next = false;
            if (pixelvalues[pixel][0]) { pixelvalues[pixel][0] = math.floor(pixelvalues[pixel][0] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][1]) { pixelvalues[pixel][1] = math.floor(pixelvalues[pixel][1] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][2]) { pixelvalues[pixel][2] = math.floor(pixelvalues[pixel][2] * DIMPIXELPERCENT); next = true;}
            // skip random number generation if we just dimmed
            if (!next) {
                newdrop = math.rand() % NEWPIXELFACTOR;
                if (newdrop <= threshold) {
                    switch (newdrop % NUMCOLORS) {
                        case 0:
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = BLUE[channel];
                            }
                            break;
                        default: 
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = MAGENTA[channel];
                            }
                            break;
                    }
                }
            }
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
    }
    
    /* White fading dots effect.
     * Factor is 1 to 10 and scales the number of new raindrops per refresh.
     */
    function snow(factor) {
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
 
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {snow(factor)}.bindenv(this));
        
        local newdrop = 0;
        local threshold = (factor * SCALE);
        if (threshold < NUMCOLORS) { threshold = NUMCOLORS; }
        if (threshold > MAXNEWDROP) { threshold = MAXNEWDROP; }
        local next = false;
        clearFrame();
        for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
            // if there's any color data in this pixel, fade it down 
            next = false;
            if (pixelvalues[pixel][0]) { pixelvalues[pixel][0] = math.floor(pixelvalues[pixel][0] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][1]) { pixelvalues[pixel][1] = math.floor(pixelvalues[pixel][1] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][2]) { pixelvalues[pixel][2] = math.floor(pixelvalues[pixel][2] * DIMPIXELPERCENT); next = true;}
            // skip random number generation if we just dimmed
            if (!next) {
                newdrop = math.rand() % NEWPIXELFACTOR;
                if (newdrop <= threshold) {
                    for (local channel = 0; channel < 3; channel++) {
                        pixelvalues[pixel][channel] = WHITE[channel];
                    }
                }
            }
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
    }
    
    /* Blue and White fading dots effect.
     * Factor is 1 to 10 and scales the number of new raindrops per refresh.
     */
    function hail(factor) {
        local NUMCOLORS = 3; // colors used in this effect
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
 
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {hail(factor)}.bindenv(this));
        
        local newdrop = 0;
        local threshold = (factor * SCALE);
        if (threshold < NUMCOLORS) { threshold = NUMCOLORS; }
        if (threshold > MAXNEWDROP) { threshold = MAXNEWDROP; }
        local next = false;
        clearFrame();
        for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
            // if there's any color data in this pixel, fade it down 
            next = false;
            if (pixelvalues[pixel][0]) { pixelvalues[pixel][0] = math.floor(pixelvalues[pixel][0] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][1]) { pixelvalues[pixel][1] = math.floor(pixelvalues[pixel][1] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][2]) { pixelvalues[pixel][2] = math.floor(pixelvalues[pixel][2] * DIMPIXELPERCENT); next = true;}
            // skip random number generation if we just dimmed
            if (!next) {
                newdrop = math.rand() % NEWPIXELFACTOR;
                if (newdrop <= threshold) {
                    switch (newdrop % NUMCOLORS) {
                        case 0: 
                            //server.log("cyan");
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = CYAN[channel];
                            }
                            break;
                        case 1: 
                            //server.log("magenta");
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = MAGENTA[channel];
                            }
                            break;
                        default: 
                            //server.log("white");
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = WHITE[channel];
                            }
                            break;
                    }
                }
            }
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
    }
    
    /* Blue and Purple fading dots effect with yellow "lightning strikes".
     * Factor is 0 to 10 and scales the number of new raindrops per refresh, 
     * as well as frequency of lightning.
     */
    function thunder(factor) {
        local NUMCOLORS = 2;
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
 
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {thunder(factor)}.bindenv(this));
        
        local newdrop = 0;
        local threshold = (factor * SCALE);
        if (threshold < NUMCOLORS) { threshold = NUMCOLORS; }
        if (threshold > MAXNEWDROP) { threshold = MAXNEWDROP; }
        //server.log(threshold);
        
        local lightningthreshold = factor;
        if (lightningthreshold > MAXLIGHTNING) { threshold = MAXLIGHTNING; }
        
        local lightningcheck = math.rand() % LIGHTNINGFACTOR;
        local next = false;
        clearFrame();
        if (lightningcheck <= lightningthreshold) {
            local lightningbrightness = math.floor(factor * LTBRTSCALE);
            for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
                for (local channel = 0; channel < 3; channel++) {
                    pixelvalues[pixel][channel] = lightningbrightness * YELLOW[channel];
                }
            }
        } else {
            for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
                //server.log(pixel);
                // if there's any color data in this pixel, fade it down 
                next = false;
                if (pixelvalues[pixel][0]) { pixelvalues[pixel][0] = math.floor(pixelvalues[pixel][0] * DIMPIXELPERCENT); next = true;}
                if (pixelvalues[pixel][1]) { pixelvalues[pixel][1] = math.floor(pixelvalues[pixel][1] * DIMPIXELPERCENT); next = true;}
                if (pixelvalues[pixel][2]) { pixelvalues[pixel][2] = math.floor(pixelvalues[pixel][2] * DIMPIXELPERCENT); next = true;}
                // skip random number generation if we just dimmed
                if (!next) {
                    newdrop = math.rand() % NEWPIXELFACTOR;
                    if (newdrop <= threshold) {
                        switch (newdrop % NUMCOLORS) {
                            case 0:
                                for (local channel = 0; channel < 3; channel++) {
                                    pixelvalues[pixel][channel] = BLUE[channel];
                                }
                                break;
                            default: 
                                for (local channel = 0; channel < 3; channel++) {
                                    pixelvalues[pixel][channel] = MAGENTA[channel];
                                }
                                break;
                        }
                    }
                }
                writePixel(pixel, pixelvalues[pixel]);
            }
        }
        writeFrame();
    }
    
    function ice(factor) {
    }
    
    function mist(factor) {
    }
    
    function fog(factor) {
    }
    
    function temp(val, factor) {
    }
}

/* AGENT CALLBACKS -----------------------------------------------------------*/

agent.on("seteffect", function(val) {
    try {
        cond = val.conditions;
        temp = val.temperature;
    } catch (err) {
        server.error("Invalid Request from Agent: "+err);
        return;
    }
    
    if (cond == "drizzle") {
        display.rain(1);
    } else if (cond == "rain") {
        display.rain(2);
    } else if (cond == "snow") {
        display.snow(1);
    } else if (cond == "ice") {
        display.ice(1);
    } else if (cond == "hail") {
        display.hail(1);
    } else if (cond == "mist") {
        display.mist(1);
    } else if (cond == "fog") {
        display.fog(1);
    } else if (cond == "thunderstorm") {
        display.thunder(2);
    } else if (cond == "clear") {
        display.temp(temp, 4);    
    } else if (cond == "mostlycloudy") {
        display.temp(temp, 3); 
    } else if (cond == "partlycloudy") {
        display.temp(temp, 2);
    } else {
        display.temp(temp, 1);
    }
});

/* RUNTIME BEGINS HERE -------------------------------------------------------*/

// The number of pixels in your chain
const NUMPIXELS = 64;

spi <- hardware.spi257;
spi.configure(MSB_FIRST, SPICLK);
display <- NeoWeather(spi, NUMPIXELS);

server.log("ready.");
display.rain(4);
server.log("effect started.");
