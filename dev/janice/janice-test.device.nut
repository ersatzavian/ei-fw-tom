/* Janice Sprinkler Controller Device Firmware
 * Tom Byrne
 * 12/18/13
 */
 
/* CONSTS and GLOBAL VARS ====================================================*/

const CHECK_TIME_INTERVAL = 60; // time between time sync checks (for testing the RTC)

// Byte to store current state of sprinkler channels
channelStates <- 0;

/* GLOBAL CLASS AND FUNCTION DEFINITIONS =====================================*/

/* General Base Class for SX150X I/O Expander Family
 * http://www.semtech.com/images/datasheet/sx150x_789.pdf
 */
class SX150x{
    //Private variables
    _i2c       = null;
    _addr      = null;
    _callbacks = null;

    //Pass in pre-configured I2C since it may be used by other devices
    constructor(i2c, address = 0x40) {
        _i2c  = i2c;
        _addr = address;  //8-bit address
        _callbacks = [];
    }

    function readReg(register) {
        local data = _i2c.read(_addr, format("%c", register), 1);
        if (data == null) {
            server.error("I2C Read Failure. Device: "+_addr+" Register: "+register);
            return -1;
        }
        return data[0];
    }
    
    function writeReg(register, data) {
        _i2c.write(_addr, format("%c%c", register, data));
    }
    
    function writeBit(register, bitn, level) {
        local value = readReg(register);
        value = (level == 0)?(value & ~(1<<bitn)):(value | (1<<bitn));
        writeReg(register, value);
    }
    
    function writeMasked(register, data, mask) {
        local value = readReg(register);
        value = (value & ~mask) | (data & mask);
        writeReg(register, value);
    }

    // set or clear a selected GPIO pin, 0-16
    function setPin(gpio, level) {
        writeBit(bank(gpio).REGDATA, gpio % 8, level ? 1 : 0);
    }

    // configure specified GPIO pin as input(0) or output(1)
    function setDir(gpio, output) {
        writeBit(bank(gpio).REGDIR, gpio % 8, output ? 0 : 1);
    }

    // enable or disable internal pull up resistor for specified GPIO
    function setPullUp(gpio, enable) {
        writeBit(bank(gpio).REGPULLUP, gpio % 8, enable ? 1 : 0);
    }
    
    // enable or disable internal pull down resistor for specified GPIO
    function setPullDn(gpio, enable) {
        writeBit(bank(gpio).REGPULLDN, gpio % 8, enable ? 1 : 0);
    }

    // configure whether specified GPIO will trigger an interrupt
    function setIrqMask(gpio, enable) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, enable ? 0 : 1);
    }

    // clear interrupt on specified GPIO
    function clearIrq(gpio) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, 1);
    }

    // get state of specified GPIO
    function getPin(gpio) {
        return ((readReg(bank(gpio).REGDATA) & (1<<(gpio%8))) ? 1 : 0);
    }

    //configure which callback should be called for each pin transition
    function setCallback(gpio, callback){
        _callbacks.insert(gpio,callback);
    }

    function callback(){
        local irq = getIrq();
        clearAllIrqs();
        for (local i = 0; i < 16; i++){
            if ( (irq & (1 << i)) && (typeof _callbacks[i] == "function")){
                _callbacks[i]();
            }
        }
    }
}

/* Class for the SX1505 8-channel GPIO Expander. */
class SX1505 extends SX150x{
    // I/O Expander internal registers
    BANK_A = {  REGDATA    = 0x00
                REGDIR     = 0x01
                REGPULLUP  = 0x02
                REGPULLDN  = 0x03
                REGINTMASK = 0x05
                REGSNSHI   = 0x06
                REGSNSLO   = 0x07
                REGINTSRC  = 0x08
            }

    constructor(i2c, address=0x20){
        base.constructor(i2c, address);
        _callbacks.resize(8,null);
        this.reset();
        this.clearAllIrqs();
    }
    
    //Write registers to default values
    function reset(){
        writeReg(BANK_A.REGDIR, 0xFF);
        writeReg(BANK_A.REGDATA, 0xFF);
        writeReg(BANK_A.REGPULLUP, 0x00);
        writeReg(BANK_A.REGPULLDN, 0x00);
        writeReg(BANK_A.REGINTMASK, 0xFF);
        writeReg(BANK_A.REGSNSHI, 0x00);
        writeReg(BANK_A.REGSNSLO, 0x00);
    }
    
    function bank(gpio){ return BANK_A; }

    // configure whether edges trigger an interrupt for specified GPIO
    function setIrqEdges( gpio, rising, falling) {
        local mask = 0x03 << ((gpio & 3) << 1);
        local data = (2*falling + rising) << ((gpio & 3) << 1);
        writeMasked(gpio >= 4 ? BANK_A.REGSNSHI : BANK_A.REGSNSLO, data, mask);
    }

    function clearAllIrqs() {
        writeReg(BANK_A.REGINTSRC,0xff);
    }
    
    function getIrq(){
        return (readReg(BANK_A.REGINTSRC) & 0xFF);
    }
}

/* GPIO class for using GPIO pins on an I/O expander as if they were imp pins */
class ExpGPIO{
    _expander = null;  //Instance of an Expander class
    _gpio     = null;  //Pin number of this GPIO pin
    
    constructor(expander, gpio) {
        _expander = expander;
        _gpio     = gpio;
    }
    
    //Optional initial state (defaults to 0 just like the imp)
    function configure(mode, callback_initialstate = null) {
        // set the pin direction and configure the internal pullup resistor, if applicable
        if (mode == DIGITAL_OUT) {
            _expander.setDir(_gpio,1);
            _expander.setPullUp(_gpio,0);
            if(callback_initialstate != null){
                _expander.setPin(_gpio, callback_initialstate);    
            }else{
                _expander.setPin(_gpio, 0);
            }
            
            return this;
        }
            
        if (mode == DIGITAL_IN) {
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,0);
        } else if (mode == DIGITAL_IN_PULLUP) {
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,1);
        }
        
        // configure the pin to throw an interrupt, if necessary
        if (typeof callback_initialstate == "function") {
            _expander.setIrqMask(_gpio,1);
            _expander.setIrqEdges(_gpio,1,1);
            _expander.setCallback(_gpio, callback_initialstate.bindenv(this));
        } else {
            _expander.setIrqMask(_gpio,0);
            _expander.setIrqEdges(_gpio,0,0);
            _expander.setCallback(_gpio,null);
        }
        
        return this;
    }
    
    function write(state) { _expander.setPin(_gpio,state); }
    
    function read() { return _expander.getPin(_gpio); }
}

/* I2C Display Module */
class st7036{
    _i2c  = null;
    _addr = null;
    
    constructor(i2c, addr = 0x78){
        _i2c  = i2c;
        _addr = addr;
        //This magical line came straight from the datasheet code example
        // 0x38 = 2-lines, Single Height, Instruction 00 = ??
        // 0x39 = 2-lines, Single Height, Instruction 01 = Bias Set
        // 0x14 = Bias Set = 1/4 Bias
        // 0x78 = 
        _i2c.write(_addr, format("%c%c%c%c%c%c%c%c%c%c", 0x00, 0x38, 0x39, 0x14, 0x78, 0x5E, 0x6D, 0x0C, 0x01, 0x06));
    }
    
    function write(str){
        _i2c.write(0x78, format("%c%s", 0x40,str));
    }
    
}

/* Real-Time Clock/Calendar
 * PCF8563
 * http://www.nxp.com/documents/data_sheet/PCF8563.pdf
 */
const CTRL_REG_1        = 0x00;
const CTRL_REG_2        = 0x01;
const VL_SEC_REG        = 0x02;
const MINS_REG          = 0x03;
const HOURS_REG         = 0x04;
const DAYS_REG          = 0x05;
const WKDAY_REG         = 0x06;
const CNTRY_MONTHS_REG  = 0x07;
const YEARS_REG         = 0x08;
const MINS_ALARM_REG    = 0x09;
const HOURS_ALARM_REG   = 0x0A;
const DAY_ALARM_REG     = 0x0B;
const WKDAY_ALARM_REG   = 0x0C;
const CLKOUT_CTRL_REG   = 0x0D;
const TIMER_CTRL_REG    = 0x0E;
const TIMER_REG         = 0x0F;
class pcf8563 {
    _i2c = null;
    _addr = null;
    
    constructor(i2c, addr = 0xA2) {
        _i2c = i2c;
        _addr = addr;
    }
    
    function readReg(register) {
        local data = _i2c.read(_addr, format("%c", register), 1);
        if (data == null) {
            server.error(format("I2C Read Failure. Device: 0x%02x Register: 0x%02x",_addr,register));
            return -1;
        }
        return data[0];
    }
    
    function writeReg(register,data) {
        _i2c.write(_addr, format("%c%c",register,data));
    }
    
    function clkGood() {
        if (0x80 & readReg(VL_SEC_REG)) {
            return 0;
        }
        return 1;
    }
    
    function clearVL() {
        local data = 0x7F & readReg(VL_SEC_REG);
        this.writeReg(VL_SEC_REG, data);
    }
    
    function sec() {
        local data = readReg(VL_SEC_REG)
        return (((data & 0x70) >> 4) * 10 + (data & 0x0F));
    }
    
    function min() {
        local data = readReg(MINS_REG);
        return (((data & 0x70) >> 4) * 10 + (data & 0x0F));
    }
    
    function hour() {
        local data = readReg(HOURS_REG);
        return (((data & 0x30) >> 4) * 10 + (data & 0x0F));
    }
    
    function day() {
        local data = readReg(DAYS_REG);
        return (((data & 0x30) >> 4) * 10 + (data & 0x0F));
    }
    
    function weekday() {
        return (readReg(WKDAY_REG) & 0x07);
    }
    
    function month() {
        local data = readReg(CNTRY_MONTHS_REG);
        return (((data & 0x10) >> 4) * 10 + (data & 0x0F));
    }
    
    function year() {
        local data = readReg(YEARS_REG);
        return (((data & 0xF0) >> 4) * 10 + (data & 0x0F));
    }
    
    function sync(setTime = null) {
        local now = date();
        if (setTime) { now = setTime; };
        local secStr = format("%02d",now.sec);
        local minStr = format("%02d",now.min);
        local hourStr = format("%02d",now.hour);
        local dayStr = format("%02d",now.day);
        local monStr = format("%02d",now.month+1);
        local yearStr = format("%02d",now.year).slice(2,4);
        local wkdayStr = format("%d",now.wday);
        
        this.writeReg(VL_SEC_REG,       (((secStr[0] & 0x07) << 4) + (secStr[1] & 0x0F)));
        this.writeReg(MINS_REG,         (((minStr[0] & 0x07) << 4) + (minStr[1] & 0x0F)));
        this.writeReg(HOURS_REG,        (((hourStr[0] & 0x03) << 4) + (hourStr[1] & 0x0F)));
        this.writeReg(DAYS_REG,         (((dayStr[0] & 0x03) << 4) + (dayStr[1] & 0x0F)));
        this.writeReg(CNTRY_MONTHS_REG, (((monStr[0] & 0x01) << 4) + (monStr[1] & 0x0F)));
        this.writeReg(YEARS_REG,        (((yearStr[0] & 0x0F) << 4) + (yearStr[1] & 0x0F)));
        this.writeReg(WKDAY_REG,        (secStr[0] & 0x07));
    }
}

/* I2C EEPROM
 * CAT24C Family
 * http://www.onsemi.com/pub_link/Collateral/CAT24C02-D.PDF
 */
const PAGE_LEN = 16;        // page length in bytes
const WRITE_TIME = 0.005;   // max write cycle time in seconds
class cat24c {
    _i2c = null;
    _addr = null;
    
    constructor(i2c, addr=0xA0) {
        _i2c = i2c;
        _addr = addr;
    }
    
    function read(len, offset) {
        // "Selective Read" by preceding the read with a "dummy write" of just the offset (no data)
        _i2c.write(_addr, format("%c",offset));
    
        local data = _i2c.read(_addr, "", len);
        if (data == null) {
            server.error(format("I2C Read Failure. Device: 0x%02x Register: 0x%02x",_addr,offset));
            return -1;
        }
        return data;
    }
    
    function write(data, offset) {
        local dataIndex = 0;
        
        while(dataIndex < data.len()) {
            // chunk of data we will send per I2C write. Can be up to 1 page long.
            local chunk = format("%c",offset);
            // check if this is the first page, and if we'll hit the boundary
            local leftOnPage = PAGE_LEN - (offset % PAGE_LEN);
            // set the chunk length equal to the space left on the page
            local chunkLen = leftOnPage;
            // check if this is the last page we need to write, and adjust the chunk size if it is
            if ((data.len() - dataIndex) < leftOnPage) { chunkLen = (data.len() - dataIndex); }
            // now fill the chunk with a slice of data and write it
            for (local chunkIndex = 0; chunkIndex < chunkLen; chunkIndex++) {
                chunk += format("%c",data[dataIndex++]);  
            }
            _i2c.write(_addr, chunk);
            offset += chunkLen;
            // write takes a finite (and rather long) amount of time. Subsequent writes
            // before the write cycle is completed fail silently. You must wait.
            imp.sleep(WRITE_TIME);
        }
    }
}
 
/* Test the PWM Beeper */
function testBeeper() {
    beeper.write(0.2);
    imp.sleep(0.5);
    beeper.write(0.0);
}

/* Rain Sensor Handler */
function rainStateChanged() {
    server.log("Rain Sensor: "+rain_sns_l.read());
}

/* Set Sprinkler Channel States */
function setChannel(channel, state) {
    if ((channel < 0) || channel > 8) return;
    if (state) {
        channelStates = channelStates | (0x01 << channel);
    } else {
        channelStates = channelStates & ~(0x01 << channel);
    }
    
    // dispable the output and write the data out to the shift register
    sr_output_en_l.write(1);
    spi.write(format("%c",channelStates));
    
    // pulse the SRCLK line to load the data into the output stage
    sr_load.write(0);
    sr_load.write(1);
    sr_load.write(0);
    
    // enable the output
    sr_output_en_l.write(0);
}

function allOff() {
    channelStates = 0x00;
    
    // dispable the output and write the data out to the shift register
    sr_output_en_l.write(1);
    spi.write(format("%c",channelStates));
    
    // pulse the SRCLK line to load the data into the output stage
    sr_load.write(0);
    sr_load.write(1);
    sr_load.write(0);
    
    // enable the output
    sr_output_en_l.write(0);   
}

function checkTime() {
    imp.wakeup(CHECK_TIME_INTERVAL, checkTime);
    
    local now = date();
    
    server.log(format("RTC Clock Integrity: %x",rtc.clkGood()));
    
    server.log(format("Current Time %02d:%02d:%02d, %02d/%02d/%02d",now.hour,
            now.min,now.sec,now.month+1,now.day,now.year));
    
    server.log(format("RTC Set to %02d:%02d:%02d, %02d/%02d/%02d",rtc.hour(),
        rtc.min(),rtc.sec(),rtc.month(),rtc.day(),rtc.year()));
}

/* AGENT EVENT HANDLERS ======================================================*/
 
/* RUNTIME BEGINS HERE =======================================================*/ 
 
server.log("Software Version: "+imp.getsoftwareversion());
server.log("Free Memory:"+imp.getmemoryfree());
imp.configure("Janice Test", [],[]);
imp.enableblinkup(true);

//Initialize the I2C bus
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);

//Initialize IO expanders
ioexp_int_l <- hardware.pinB; 
disp_ioexp  <- SX1505(i2c,0x42);  //Display Board 8-Channel IO expander

//Imp Pin configuration
beeper          <- hardware.pin1;
disp_reset_l    <- hardware.pin2;
sr_output_en_l  <- hardware.pin6;
sr_load         <- hardware.pinA;
disp_brightness <- hardware.pinC;
rain_sns_l      <- hardware.pinD;
spi             <- hardware.spi257;

beeper.configure(PWM_OUT, 1.0/1000, 0.0);
disp_brightness.configure(PWM_OUT, 1.0/1000, 0.3);

rain_sns_l.configure(DIGITAL_IN_PULLUP, rainStateChanged);
spi.configure(SIMPLEX_TX | MSB_FIRST | CLOCK_IDLE_HIGH, 4000);
sr_output_en_l.configure(DIGITAL_OUT);
sr_output_en_l.write(1);
sr_load.configure(DIGITAL_OUT);
sr_load.write(0);

// Clear the sprinkler channels
allOff();

//Configure the Display
//disp <- st7036(i2c);
//disp.write(" Impee Janice");

//Configure IOs on the Display Expander
/*
btn_up     <- ExpGPIO(disp_ioexp, 0).configure(DIGITAL_IN_PULLUP, function(){server.log("Btn Up:"+this.read())});
btn_left   <- ExpGPIO(disp_ioexp, 1).configure(DIGITAL_IN_PULLUP, function(){server.log("Btn Left:"+this.read())});
btn_enter  <- ExpGPIO(disp_ioexp, 2).configure(DIGITAL_IN_PULLUP, function(){server.log("Btn Enter:"+this.read())});
btn_right  <- ExpGPIO(disp_ioexp, 3).configure(DIGITAL_IN_PULLUP, function(){server.log("Btn Right:"+this.read())});
btn_down   <- ExpGPIO(disp_ioexp, 4).configure(DIGITAL_IN_PULLUP, function(){server.log("Btn Down:"+this.read())});
disp_rst_l <- ExpGPIO(disp_ioexp, 5).configure(DIGITAL_OUT, 1);
*/

// Initialize I2C Devices
// Configure the RTC
rtc <-  pcf8563(i2c);
//rtc.sync();

// Configure the EEPROM
eeprom <- cat24c(i2c);

//Initialize the interrupt Pin
ioexp_int_l.configure(DIGITAL_IN_PULLUP, function(){ disp_ioexp.callback(); });

// Test the RTC
checkTime();