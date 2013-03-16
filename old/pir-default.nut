// Battery powered motion sensor
server.log("PIR booted");

imp.setpowersave(true);

// slave address of TMP112 with ADD0 pulled LOW
local tmpAddr = 0x90;

local outMotion = OutputPort("Motion detector");
local outTemp = OutputPort("Temperature");
imp.configure("Motion & Temp Sensor", [], [outMotion, outTemp]);

function getTemp() {
    //Wait for sensor to be ready (26ms typical)
    imp.sleep(0.1);

    local result = hardware.i2c89.read(tmpAddr, "\x00", 2);
    
    if (result == null) {
        server.error("I2C Read Fail: Result == Null");
    } else if(result[0] == null) {
        server.error("I2C Read Fail: Result[0] == Null");
    } else if(result[1] == null) {
        server.error("I2C Read Fail: Result[1] == Null");
    } else {
        local temp = ((result[0] << 4) + (result[1] >> 4)) * 0.0625;
        //convert to fahrenheit
        temp = temp * 9.0 / 5.0 + 32.0;
        //output
        server.show(format("Temp: %.1f F", temp));
        outTemp.set(temp);
    }
        
    imp.wakeup(5, getTemp);
}

function motion() {
  local s = hardware.pin1.read();
  outMotion.set(s);
  server.show(s?"motion":"");
  hardware.pin7.write(s?1:0);
}

hardware.pin1.configure(DIGITAL_IN_PULLUP, motion);
hardware.pin7.configure(DIGITAL_OUT);
hardware.i2c89.configure(CLOCK_SPEED_100_KHZ);

getTemp();

//EOF