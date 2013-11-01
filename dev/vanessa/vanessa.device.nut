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

/* 
 * Vanessa Reference Design Firmware
 * Tom Byrne
 * tom@electricimp.com
 * 10/21/2013
 */

// SPI Clock Rate in kHz
const SPICLK = 15000;
// I/O Expander 7-bit address
const IOEXP_ADDR = 0x20;

/* GLOBAL CLASS AND FUNCTION DEFINITIONS ------------------------------------*/

class epaper {
    /*
     * class to drive Pervasive Displays epaper display
     * see http://repaper.org
     */

    WIDTH           = null;
    HEIGHT          = null;
    PIXELS          = null;
    BYTESPERSCREEN  = null;

    stageTime       = null;

    spi             = null;
    epd_cs_l        = null;
    busy            = null;
    therm           = null;
    pwm             = null;
    rst_l           = null;
    pwr_en_l        = null;
    border          = null;
    discharge       = null;

    constructor(width, height, spi, epd_cs_l, busy, therm, pwm, rst_l, pwr_en_l, discharge, border) {
        // set display size parameters
        this.WIDTH = width;
        this.HEIGHT = height;
        this.PIXELS = this.WIDTH * this.HEIGHT;
        this.BYTESPERSCREEN = this.PIXELS / 4;
        this.stageTime = 480;

        // verify the display dimensions and quit if they're bogus
        switch (this.WIDTH) {
            case 128: // 1.44" screen check
                if (this.HEIGHT != 96) {
                    this.invalidDimensions();
                    return -1;
                }
                // otherwise, dimensions are valid
                break;
            case 200: // 2.0" screen check
                if (this.HEIGHT != 96) {
                    this.invalidDimensions();
                    return -1;
                }
                break;
            case 264:
                    this.stageTime = 630
                    if (this.HEIGHT != 176) {
                    this.invalidDimensions();
                    return -1;
                }
                break;
            default:
                this.invalidDimensions();
                return -1;
        }
        // dimensions OK

        // initialize the SPI bus
        // this is tricky since we're likely sharing it with the SPI flash. Need to use a clock speed that both
        // are ok with, or reconfigure the bus on every transaction
        // As it turns out, the ePaper display is content with 4 MHz to 12 MHz, all of which are ok with the flash
        // Furthermore, the display seems to work just fine at 15 MHz.
        this.spi = spi;
        server.log("Display Running at: " + this.spiOff() + " kHz");

        this.epd_cs_l = epd_cs_l;
        this.epd_cs_l.configure(DIGITAL_OUT);
        this.epd_cs_l.write(0);

        // initialize the other digital i/o needed by the display
        this.busy = busy;
        this.busy.configure(DIGITAL_IN);

        this.therm = therm;

        this.pwm = pwm;
        this.pwm.configure(PWM_OUT, 1/200000.0, 0.0);

        this.rst_l = rst_l;
        this.rst_l.configure(DIGITAL_OUT);
        this.rst_l.write(0);

        this.pwr_en_l = pwr_en_l;
        this.pwr_en_l.configure(DIGITAL_OUT);
        this.pwr_en_l.write(1);

        this.discharge = discharge;
        this.discharge.configure(DIGITAL_OUT);
        this.discharge.write(0);

        this.border = border;
        this.border.configure(DIGITAL_OUT);
        this.border.write(0);

        // must call this.start before operating on panel
    }

    function invalidDimensions() {
        server.error("Device: ePaper Display Constructor called with invalid dimensions.\n"+
            " Valid sizes:\n128 x 96 (1.44\")\n200 x 96 (2.0\")\n264 x 176 (2.7\")");
        return;
    }

    // enable SPI
    function spiOn() {
        local freq = this.spi.configure(CLOCK_IDLE_HIGH | MSB_FIRST | CLOCK_2ND_EDGE, SPICLK);
        this.spi.write("\x00");
        imp.sleep(0.00001);
        return freq;
    }

    // disable SPI
    function spiOff() {
        local freq = this.spi.configure(CLOCK_IDLE_LOW | MSB_FIRST | CLOCK_2ND_EDGE, SPICLK);
        this.spi.write("\x00");
        imp.sleep(0.00001);
        return freq;
    }

    // Write to EPD registers over SPI
    function writeEPD(index, ...) {
        this.epd_cs_l.write(1);                      // CS = 1
        imp.sleep(0.00001);
        this.epd_cs_l.write(0);                      // CS = 0
        imp.sleep(0.00001);
        this.spi.write(format("%c%c", 0x70, index)); // Write header, then register index
        imp.sleep(0.00001);
        this.epd_cs_l.write(1);                      // CS = 1
        imp.sleep(0.00001);
        this.epd_cs_l.write(0);                      // CS = 0
        this.spi.write(format("%c", 0x72));          // Write data header
        foreach (word in vargv) {
            this.spi.write(format("%c", word));     // then register data
        }
        imp.sleep(0.00001);
        this.epd_cs_l.write(1);                      // CS = 1
    }

    function start() {
        server.log("Powering On EPD.");

        /* POWER-ON SEQUENCE ------------------------------------------------*/

        // make sure SPI is low to avoid back-powering things through the SPI bus
        this.spiOn();

        // Make sure signals start unasserted (rest, panel-on, discharge, border, cs)
        this.rst_l.write(0);
        this.pwr_en_l.write(1);
        this.discharge.write(0);
        this.border.write(0);
        this.epd_cs_l.write(0);

        // Start PWM input
        this.pwm.write(0.5);

        // Let PWM toggle for 5ms
        imp.sleep(0.005);

        // Turn on panel power
        this.pwr_en_l.write(0);

        // let PWM toggle for 10 ms
        imp.sleep(0.010);

        this.rst_l.write(1);
        this.border.write(1);
        this.epd_cs_l.write(1);
        imp.sleep(0.005);

        // send reset pulse
        this.rst_l.write(0);
        imp.sleep(0.005);
        this.rst_l.write(1);
        imp.sleep(0.005);

        // Wait for screen to be ready
        while (busy.read()) {
            server.log("Waiting for COG Driver to Power On...");
            imp.sleep(0.005);
        }

        // Channel Select
        switch(this.WIDTH) {
            case 128:
                // 1.44" Display
                this.writeEPD(0x01,0x00,0x00,0x00,0x00,0x00,0x0F,0xFF,0x00);
                return;
            case 200:
                // 2" Display
                this.writeEPD(0x01,0x00,0x00,0x00,0x00,0x01,0xFF,0xE0,0x00);
                break;
            case 264:
                // 2.7" Display
                this.writeEPD(0x01,0x00,0x00,0x00,0x7F,0xFF,0xFE,0x00,0x00);
                break;
            default:
                server.error("Invalid Display Size");
                this.stop();
                return;
        }

        // DC/DC Frequency Setting
        this.writeEPD(0x06, 0xFF);

        // High Power Mode Oscillator Setting
        this.writeEPD(0x07, 0x9D);

        // Disable ADC
        this.writeEPD(0x08, 0x00);

        // Set Vcom level
        this.writeEPD(0x09, 0xD0, 0x00);

        // Gate and Source Voltage Level
        if (this.WIDTH == 264) {
            this.writeEPD(0x04, 0x00);
        } else {
            this.writeEPD(0x04, 0x03);
        }

        // delay for PWM
        imp.sleep(0.005);

        // Driver latch on ("cancel register noise")
        this.writeEPD(0x03, 0x01);

        // Driver latch off
        this.writeEPD(0x03, 0x00);

        // delay for PWM
        imp.sleep(0.005);

        // Start charge pump positive V (VGH & VDH on)
        this.writeEPD(0x05, 0x01);

        // last delay before stopping PWM
        imp.sleep(0.030);

        // Stop PWM
        this.pwm.write(0.0);

        // Start charge pump negative voltage
        this.writeEPD(0x05, 0x03);

        imp.sleep(0.030);

        // Set charge pump Vcom driver to ON
        this.writeEPD(0x05, 0x0F);

        imp.sleep(0.030);

        // "Output enable to disable" (docs grumble grumble)
        this.writeEPD(0x02, 0x24);

        server.log("COG Driver Initialized.");
    }


    // Power off COG Driver
    function stop() {
        server.log("Powering Down EPD");

        // Write a dummy frame and dummy line
        local dummyScreen = blob(BYTESPERSCREEN);
        for (local i = 0; i < BYTESPERSCREEN; i++) {
            dummyScreen.writen(0x55,'b');
        }
        this.drawScreen(dummyScreen);
        dummyScreen.seek(0,'b');
        this.writeLine(0x7fff,dummyScreen.readblob(BYTESPERSCREEN/HEIGHT));

        imp.sleep(0.025);

        // set BORDER low for 30 ms
        this.border.write(0);
        imp.sleep(0.030);
        this.border.write(1);

        // latch reset on
        this.writeEPD(0x03, 0x01);

        //output enable off
        this.writeEPD(0x02, 0x05);

        // VCOM power off
        this.writeEPD(0x05, 0x0e);

        // power off negative charge pump
        this.writeEPD(0x05, 0x02);

        // discharge
        writeEPD(0x04, 0x0c);

        imp.sleep(0.120);

        // all charge pumps off
        this.writeEPD(0x05, 0x00);

        // turn off oscillator
        this.writeEPD(0x07, 0x0d);

        // discharge internal - 1 (?)
        this.writeEPD(0x04, 0x50);

        imp.sleep(0.040);

        // discharge internal - 2 (??)
        this.writeEPD(0x04, 0xA0);

        imp.sleep(0.040);

        // discharge internal - 3 (???)
        this.writeEPD(0x04, 0x00);

        // turn off all power and set all inputs low
        this.rst_l.write(0);
        this.pwr_en_l.write(1);
        this.border.write(0);

        // ensure MOSI is low before CS Low
        this.spiOff();
        imp.sleep(0.00001);
        this.epd_cs_l.write(0);

        // send discharge pulse
        server.log("Discharging Rails");
        this.discharge.write(1);
        imp.sleep(0.15);
        this.discharge.write(0);

        server.log("Display Powered Down.");
    }

    // draw a line on the screen
    function writeLine(line, data) {

        local line_data = blob((this.WIDTH / 4) + (this.HEIGHT / 4));

        line_data.writen(0x72, 'b');

        // Even pixels
        for (local i = 0; i < (this.WIDTH / 8); i++) {
            line_data.writen(data[i],'b');
        }

        // Scan Lines
        for (local j = 0; j < (this.HEIGHT / 4); j++) {
            if (line / 4 == j) {
                line_data.writen((0xC0 >> (2 * (line & 0x03))), 'b');
            } else {
                line_data.writen(0x00,'b');
            }
        }

        // Odd Pixels
        for (local k = (this.WIDTH / 8); k < (this.WIDTH / 4); k++) {
            line_data.writen(data[k], 'b');
        }

        // null byte to end each line
        line_data.writen(0x00,'b');

        // read from start of line
        line_data.seek(0,'b');

        // Set charge pump voltage levels
        if (this.WIDTH == 264) {
            this.writeEPD(0x04, 0x00);
        } else {
            this.writeEPD(0x04, 0x03);
        }

        // Send index "0x0A" and keep CS asserted
        this.epd_cs_l.write(0);                      // CS = 0
        imp.sleep(0.00001);
        this.spi.write(format("%c%c", 0x70, 0x0A));  // Write header, then register index
        imp.sleep(0.00001);
        this.epd_cs_l.write(1);                      // CS = 1
        imp.sleep(0.00001);
        this.epd_cs_l.write(0);                      // CS = 0

        this.spi.write(line_data);
        imp.sleep(0.00001);
        this.epd_cs_l.write(1);

        // Turn on output enable
        this.writeEPD(0x02, 0x2F);
    }

    // draw the full screen
    function drawScreen(screenData) {
        screenData.seek(0,'b');
        local length = BYTESPERSCREEN/HEIGHT;
        while (!screenData.eos()) {
            this.writeLine(screenData.tell()/length, screenData.readblob(length));
        }
    }

    // repet drawing for the temperature compensated stage time
    function drawScreenCompensated(screenData) {
        local stageTime = this.stageTime * this.temperatureToFactor(this.getTemp());
        local start_time = hardware.millis();
        while (stageTime > 0) {
            this.drawScreen(screenData);
            stageTime = stageTime - (hardware.millis() - start_time);
        }
    }

    // convert a temperature in Celcius to scale factor
    function temperatureToFactor(temperature) {
        if (temperature <= -10) {
            return 17.0;
        } else if (temperature <= -5) {
            return 12.0;
        } else if (temperature <= 5) {
            return 8.0;
        } else if (temperature <= 10) {
            return 4.0;
        } else if (temperature <= 15) {
            return 3.0;
        } else if (temperature <= 20) {
            return 2.0;
        } else if (temperature <= 40) {
            return 1.0;
        }
        return 0.7;
    }

    /*
     * fill the screen with a fixed value
     *
     * takes in a one byte value to fill the screen
     */
    function fillScreen(fillValue) {
        local screenData = blob(BYTESPERSCREEN);
        for (local i = 0; i < BYTESPERSCREEN; i++) {
            screenData.writen(fillValue, 'b');
        }
        this.drawScreenCompensated(screenData);
    }

    // clear display
    function clear() {
        // We don't know what's on the screen, so just clear it
        // draw the screen white first
        server.log("Clearing Screen");
        this.fillScreen(0xAA);
        // draw the screen black
        this.fillScreen(0xFF);
        // draw the screen white again
        this.fillScreen(0xAA);
    }

    /*
     * Pervasive Displays breakout includes Seiko S-5813A/5814A Series Analog Temp Sensor
     * http://datasheet.sii-ic.com/en/temperature_sensor/S5813A_5814A_E.pdf
     *
     *  -30C -> 2.582V
     *  +30C -> 1.940V
     * +100C -> 1.145V
     */
    /*
    function getTemp() {
        local rawTemp = 0;
        local rawVdda = 0;
        // Take 10 readings and average for accuracy
        for (local i = 0; i < 10; i++) {
            rawTemp += this.tempsense.read();
            rawVdda += hardware.voltage();
        }
        local vdda = (rawVdda / 10.0);
        // temp sensor has resistive divider on output
        // Rhigh = 26.7k
        // Rlow = 17.8k
        // Vout = Vsense / (17.8 / (26.7+17.8)) = Vsense * 2.5
        local vsense = ((rawTemp / 10.0) * (vdda / 65535.0)) * 2.5;
        local temp = ((vsense  - 1.145) / -0.01104) + 100;
        return temp;
     }
    */
    /*
     * Vanessa board includes on-board thermistor.
     * pass in a thermistor object to the constructor.
     * getTemp() returns current temp in celsius
     */
    function getTemp() {
        return therm.read_c();
    }
}

class SX1505 {
    
    i2cPort = null;
    i2cAddress = null;
    alertpin = null;
    // callback functions {pin,callback}
    callbacks = {};
    
    // I/O Expander internal registers
    REGDATA     = 0x00;
    REGDIR      = 0x01;
    REGPULLUP   = 0x02;
    REGPULLDN   = 0x03;
    REGINTMASK  = 0x05;
    REGSNSHI    = 0x06;
    REGSNSLO    = 0x07;
    REGINTSRC   = 0x08;
    REGEVNTSTS  = 0x09;
    REGPLDMODE  = 0x10;
    REGPLDTBL0  = 0x11;
    REGPLDTBL1  = 0x12;
    REGPLDTBL2  = 0x13;
    REGPLDTBL3  = 0x14;
    REGPLDTBL4  = 0x15;
    
    function decode_callback() {
        //server.log("Decoding Callback");
        if (!alertpin.read()) {
            local irqPinMask = this.readReg(REGINTSRC);
            /*
            server.log(format("REGINTSRC:  0x%02x",irqPinMask));
            server.log(format("REGDATA:    0x%02x",this.readReg(REGDATA)));
            server.log(format("REGDIR:     0x%02x",this.readReg(REGDIR)));
            server.log(format("REGPULLUP:  0x%02x",this.readReg(REGPULLUP)));
            server.log(format("REGPULLDN:  0x%02x",this.readReg(REGPULLDN)));
            server.log(format("REGINTMASK: 0x%02x",this.readReg(REGINTMASK)));
            server.log(format("REGSNSHI:   0x%02x",this.readReg(REGSNSHI)));
            server.log(format("REGSNSLO:   0x%02x",this.readReg(REGSNSLO)));
            server.log(format("REGEVNTSTTS:0x%02x",this.readReg(REGEVNTSTS)));
            */
            clearAllIrqs();
            callbacks[irqPinMask]();   
        }
    }
    
    constructor(port, address, alertpin) {
        try {
            i2cPort = port;
            i2cPort.configure(CLOCK_SPEED_100_KHZ);
            this.alertpin = alertpin;
        } catch (err) {
            server.error("Error configuring I2C for I/O Expander: "+err);
        }
        
        // 7-bit addressing
        i2cAddress = address << 1;
        
        // configure alert pin to figure out which callback needs to be called
        if (alertpin) {
            alertpin.configure(DIGITAL_IN_PULLUP,decode_callback.bindenv(this));
        }
        
        // clear all IRQs just in case
        clearAllIrqs();
    }
    
    function readReg(register) {
        local data = i2cPort.read(i2cAddress, format("%c", register), 1);
        if (data == null) {
            server.error("I2C Read Failure");
            return -1;
        }
        return data[0];
    }
    
    function writeReg(register, data) {
        i2cPort.write(i2cAddress, format("%c%c", register, data));
    }
    
    function writeBit(register, bitn, level) {
        //server.log("made it to writebit");
        local value = readReg(register);
        //server.log(format("writebit got 0x%x",value));
        value = (level == 0)?(value & ~(1<<bitn)):(value | (1<<bitn));
        //server.log(format("writing back 0x%x",value));
        writeReg(register, value);
    }
    
    function writeMasked(register, data, mask) {
        local value = readReg(register);
        value = (value & ~mask) | (data & mask);
        writeReg(register, value);
    }
    // set or clear a selected GPIO pin, 0-15
    function setPin(gpio, level) {
        writeBit(REGDATA, gpio, level ? 1 : 0);
    }
    // configure specified GPIO pin as input(0) or output(1)
    function setDir(gpio, output) {
        //server.log("made it to setDir");
        writeBit(REGDIR, gpio, output ? 0 : 1);
    }
    // enable or disable internal pull up resistor for specified GPIO
    function setPullUp(gpio, enable) {
        //server.log("made it to setPullUp");
        writeBit(REGPULLUP, gpio, enable ? 0 : 1);
    }
    // configure whether specified GPIO will trigger an interrupt
    function setIrqMask(gpio, enable) {
        writeBit(REGINTMASK, gpio, enable ? 0 : 1);
    }
    // configure whether edges trigger an interrupt for specified GPIO
    function setIrqEdges( gpio, rising, falling) {
        local mask = 0x03 << ((gpio & 3) << 1);
        local data = (2*falling + rising) << ((gpio & 3) << 1);
        writeMasked(gpio >= 4 ? REGSNSHI : REGSNSLO, data, mask);
    }
    // clear interrupt on specified GPIO
    function clearIrq(gpio) {
        writeBit(REGINTMASK, gpio, 1);
    }
    function clearAllIrqs() {
        writeReg(REGINTSRC,0xff);
    }
    
    // get state of specified GPIO
    function getPin(gpio) {
        return ((readReg(REGDATA) & (1<<gpio)) ? 1 : 0);
    }
}

class expGpio extends SX1505 {
    
    // pin number of this GPIO pin
    gpio = null;
    // imp pin to throw interrupt on, if configured
    alertpin = null;
    
    constructor(port, address, gpio, alertpin = null) {
        base.constructor(port, address, alertpin);
        this.gpio = gpio;
    }
    
    function configure(mode, callback = null) {
        // set the pin direction and configure the internal pullup resistor, if applicable
        if (mode == DIGITAL_OUT) {
            base.setDir(gpio,1);
            base.setPullUp(gpio,0);
        } else if (mode == DIGITAL_IN) {
            base.setDir(gpio,0);
            base.setPullUp(gpio,0);
            //server.log("GPIO Expander Pin "+gpio+" Configured");
        } else if (mode == DIGITAL_IN_PULLUP) {
            base.setDir(gpio,0);
            base.setPullUp(gpio,1);
        }
        
        // configure the pin to throw an interrupt, if necessary
        if (callback) {
            base.setIrqMask(gpio,1);
            base.setIrqEdges(gpio,1,1);
            
            // add this callback to the base's callbacks table
            base.callbacks[(0xff & (0x01 << gpio))] <- callback;
            //server.log("GPIO Expander Callback added to table");
        } else {
            base.setIrqMask(gpio,0);
            base.setIrqEdges(gpio,0,0);
        }
    }
    
    function write(state) {
        base.setPin(gpio,state);
    }
    
    function read() {
        return base.getPin(gpio);
    }
}

class thermistor {

        // thermistor constants are shown on your thermistor datasheet
        // beta value (for the temp range your device will operate in)
        b_therm                 = null;
        t0_therm                 = null;
        // nominal resistance of the thermistor at room temperature
        r0_therm                = null;

        // analog input pin
        p_therm                 = null;
        points_per_read         = null;

        high_side_therm         = null;

        constructor(pin, b, t0, r, points = 10, _high_side_therm = true) {
                this.p_therm = pin;
                this.p_therm.configure(ANALOG_IN);

                // force all of these values to floats in case they come in as integers
                this.b_therm = b * 1.0;
                this.t0_therm = t0 * 1.0;
                this.r0_therm = r * 1.0;
                this.points_per_read = points * 1.0;

                this.high_side_therm = _high_side_therm;
        }

        // read thermistor in Kelvin
        function read() {
                local vdda_raw = 0;
                local vtherm_raw = 0;
                for (local i = 0; i < points_per_read; i++) {
                        vdda_raw += hardware.voltage();
                        vtherm_raw += p_therm.read();
                }
                local vdda = (vdda_raw / points_per_read);
                local v_therm = (vtherm_raw / points_per_read) * (vdda / 65535.0);
                local r_therm = 0;        
                if (high_side_therm) {
                        r_therm = (vdda - v_therm) * (r0_therm / v_therm);
                } else {
                        r_therm = r0_therm / ((vdda / v_therm) - 1);
                }

                local ln_therm = math.log(r0_therm / r_therm);
                local t_therm = (t0_therm * b_therm) / (b_therm - t0_therm * ln_therm);
                return t_therm;
        }

        // read thermistor in Celsius
        function read_c() {
                return this.read() - 273.15;
        }

        // read thermistor in Fahrenheit
        function read_f() {
                local temp = this.read() - 273.15;
                return (temp * 9.0 / 5.0 + 32.0);
        }
}

function chkBat() {
    vbat_sns_en.write(1);
    local vbat = (vbat_sns.read()/65535.0) * hardware.voltage() * (6.9/4.7);
    vbat_sns_en.write(0);
    return vbat;
}

function chkBtn1() {
    server.log("Button 1 State: "+btn1.read());
}

function chkBtn2() {
    server.log("Button 2 State: "+btn2.read());
}

function chgStatusChanged() {
    if (chg_status.read()) {
        server.log("Battery Charging Stopped.");
    } else {
        server.log("Battery Charging Started.");
    }
}

/* REGISTER AGENT CALLBACKS -------------------------------------------------*/
agent.on("start", function(data) {
    display.start();
});

agent.on("stop", function(data) {
    display.stop();
});

agent.on("wht", function(data) {
    display.fillScreen(0xAA);
});

agent.on("blk", function(data) {
    display.fillScreen(0xFF);
});

agent.on("newImgStart", function(data) {
    //server.log("Device got new image start.");
    display.start();
    // agent sends the inverted version of the current image first
    display.drawScreenCompensated(data);
    // white out the screen second
    display.fillScreen(0xAA);
    // signal we're ready for the new image data, sent inverted first
    //server.log("Device Ready for new image inverted.");
    agent.send("readyForNewImgInv",0);
});

agent.on("newImgInv", function(data) {
    //server.log("Device got new image inverted.");
    display.drawScreenCompensated(data);
    //server.log("Device ready for new image normal.");
    agent.send("readyForNewImgNorm",0);
});

agent.on("newImgNorm", function(data) {
    //server.log("Device got new image normal.");
    display.drawScreenCompensated(data);
    display.stop();
    server.log("Done Drawing New Image.");
})

agent.on("clear", function(val) {
    server.log("Force-clearing screen.");
    display.start();
    display.clear();
    display.stop();
});

/* The device requests its own parameters from the agent upon startup.
 * This handler finishes initializing the device when the agent responds with these parameters.
 */
agent.on("params_res", function(res) {
    /*
     * display dimensions
     *
     * Standard sizes from repaper.org:
     * 1.44" = 128 x 96  px
     * 2.0"  = 200 x 96  px
     * 2.7"  = 264 x 176 px
     */
    
    // ePaper(WIDTH, HEIGHT, SPI_IFC, EPD_CS_L, BUSY, THERMISTOR_OBJ, PWM, RESET, PANEL_ON, DISCHARGE, BORDER)
    display <- epaper(res.width, res.height, hardware.spi257, epd_cs_l, epd_busy, therm,
        pwm, epd_rst_l, epd_pwr_en_l, epd_discharge, epd_border);

    server.log("Device Started, free memory: " + imp.getmemoryfree());
    server.log("Display is " + display.WIDTH + " x " + display.HEIGHT + " px (" + display.BYTESPERSCREEN + " bytes).");
    // temp sensor requires panel to be powered on
    display.start();
    imp.sleep(0.5);
    server.log(format("Temperature: %.2f C", display.getTemp()));
    // power the panel back off
    display.stop();
    server.log("Ready.");
});


/* RUNTIME BEGINS HERE ------------------------------------------------------*/
imp.configure("Vanessa Epaper Display",[],[]);
imp.enableblinkup(false);
imp.setpowersave(true);

// Vanessa Reference Design Pin configuration
ioexp_int_l     <- hardware.pin1;   // I/O Expander Alert (Active Low)
spi             <- hardware.spi257;
// MISO         <- hardware.pin2;   // SPI interface
// SCLK         <- hardware.pin5;   // SPI interface
epd_busy        <- hardware.pin6;   // Busy input
// MOSI         <- hardware.pin7;   // SPI interface
i2c             <- hardware.i2c89;
// SCL          <- hardware.pin8;   // I2C CLOCK
// SDA          <- hardware.pin9;   // I2C DATA
vbat_sns        <- hardware.pinA;   // Battery Voltage Sense (ADC)
vbat_sns.configure(ANALOG_IN);
temp_sns        <- hardware.pinB;   // Temperature Sense (ADC)
pwm             <- hardware.pinC;   // PWM Output for EPD (200kHz, 50% duty cycle)
epd_cs_l        <- hardware.pinD;   // EPD Chip Select (Active Low)
vbat_sns_en     <- hardware.pinE;   // Battery Voltage Sense Enable
vbat_sns_en.configure(DIGITAL_OUT);
vbat_sns_en.write(0);

// Vanessa includes an 8-channel I2C I/O Expander (SX1505)
ioexp <- SX1505(i2c,IOEXP_ADDR,ioexp_int_l);    // instantiate I/O Expander

epd_pwr_en_l    <- expGpio(i2c, IOEXP_ADDR, 0);     // EPD Panel Power Enable Low (GPIO 0)
epd_rst_l       <- expGpio(i2c, IOEXP_ADDR, 1);     // EPD Reset Low (GPIO 1)
epd_discharge   <- expGpio(i2c, IOEXP_ADDR, 2);     // EPD Discharge Line (GPIO 2)
epd_border      <- expGpio(i2c, IOEXP_ADDR, 3);     // EPD Border CTRL Line (GPIO 3)

// Two buttons also on GPIO Expander
btn1            <- expGpio(i2c, IOEXP_ADDR, 4);     // User Button 1 (GPIO 4)
btn1.configure(DIGITAL_IN, chkBtn1);
btn2            <- expGpio(i2c, IOEXP_ADDR, 5);     // User Button 2 (GPIO 5)
btn2.configure(DIGITAL_IN, chkBtn2);

// Battery Charge Status on GPIO Expander
chg_status      <- expGpio(i2c, IOEXP_ADDR, 6);     // BQ25060 Battery Management IC sets this line low when charging
chg_status.configure(DIGITAL_IN, chgStatusChanged);

// Flash CS_L on GPIO Expander
flash_cs_l      <- expGpio(i2c, IOEXP_ADDR, 7);     // Flash Chip Select Low (GPIO 7)

// Construct a thermistor object to be passed the epaper constructor
therm           <- thermistor(temp_sns,3340, 298, 10000);

// log the battery voltage at startup
server.log(format("Battery Voltage: %.2f V",chkBat()));

// ask the agent to remind us what we are so we can finish initialization.
agent.send("params_req",0);