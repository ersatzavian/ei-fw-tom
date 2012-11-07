// 6-channel 5A PWM Driver (RGB In)
 
/* Pin Assignments according to silkscreen
 * Pin 1 = Red 1
 * Pin 2 = Blue 1
 * Pin 5 = Blue 2
 * Pin 7 = Red 2
 * Pin 8 = Green 2
 * Pin 9 = Green 1 
 */

// initialize some handy values
// PWM frequency in Hz
local pwm_f = 500.0;

// Configure hardware
hardware.pin1.configure(PWM_OUT, 1.0/pwm_f, 1.0);
hardware.pin2.configure(PWM_OUT, 1.0/pwm_f, 1.0);
hardware.pin5.configure(PWM_OUT, 1.0/pwm_f, 1.0);
hardware.pin7.configure(PWM_OUT, 1.0/pwm_f, 1.0);
hardware.pin8.configure(PWM_OUT, 1.0/pwm_f, 1.0);
hardware.pin9.configure(PWM_OUT, 1.0/pwm_f, 1.0);

server.log("Hardware Configured");

class rgbInput extends InputPort
{
    type = "color"
    redPin = null
    grnPin = null
    bluPin = null
    
    constructor(name, redPin, grnPin, bluPin) {
        base.constructor(name)
        this.redPin = redPin
        this.grnPin = grnPin
        this.bluPin = bluPin
    }
    
    function set(value) {
        local red = value[0].tointeger();
        local blue = value[1].tointeger();
        local green = value[2].tointeger();
        
        this.redPin.write(red*(1.0/255.0));
        this.grnPin.write(green*(1.0/255.0));
        this.bluPin.write(blue*(1.0/255.0));
    }
}

class switchInput extends InputPort
{
    name = "Switch Input"
    type = "On/Off"
    
    function set(value) {
        if (value == 0) {
            hardware.pin1.write(0.0);
            hardware.pin2.write(0.0);
            hardware.pin5.write(0.0);
            hardware.pin7.write(0.0);
            hardware.pin8.write(0.0);
            hardware.pin9.write(0.0);
        }
    }
}

server.log("Quinn Started");
local ch1 = rgbInput("Channel 1", hardware.pin1, hardware.pin9, hardware.pin2);
local ch2 = rgbInput("Channel 2", hardware.pin7, hardware.pin8, hardware.pin5);
imp.configure("Quinn", [ ch1, ch2, switchInput() ], []);

//EOF