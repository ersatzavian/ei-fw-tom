// 6-channel 5A PWM Driver
 
/* Pin Assignments according to silkscreen
 * Pin 1 = Red 1
 * Pin 2 = Blue 1
 * Pin 5 = Blue 2
 * Pin 7 = Red 2
 * Pin 8 = Green 2
 * Pin 9 = Green 1 
 */
 
/* Note: Green and Blue are switched on the LED strips we purchased
 * blue and green have therefore been switched below:
 * Pin 2 = Green 1
 * Pin 5 = Green 2
 * Pin 8 = Blue 1
 * Pin 9 = Blue 2
 */

// initialize some handy values
// PWM frequency in Hz
local pwm_f = 500.0;
// initial duty cycle for each channel (all on to start)
local redDuty = 1.0;
local bluDuty = 1.0;
local grnDuty = 1.0;

// Configure hardware
hardware.pin1.configure(PWM_OUT, 1.0/pwm_f, redDuty);
hardware.pin2.configure(PWM_OUT, 1.0/pwm_f, grnDuty);
hardware.pin5.configure(PWM_OUT, 1.0/pwm_f, grnDuty);
hardware.pin7.configure(PWM_OUT, 1.0/pwm_f, redDuty);
hardware.pin8.configure(PWM_OUT, 1.0/pwm_f, bluDuty);
hardware.pin9.configure(PWM_OUT, 1.0/pwm_f, bluDuty);

server.log("Hardware Configured");

function setDuty() {
    hardware.pin1.write(redDuty);
    hardware.pin7.write(redDuty);
    hardware.pin2.write(grnDuty);
    hardware.pin5.write(grnDuty);
    hardware.pin8.write(bluDuty);
    hardware.pin9.write(bluDuty);
    
    //imp.wakeup(0.25, setDuty);
}

class rgbInput extends InputPort
{
    name = "RGB Input"
    type = "color"
    
    function set(value) {
        local red = value[0].tointeger();
        local blu = value[1].tointeger();
        local grn = value[2].tointeger();
        /*
        server.log(format("Red: %d",red));
        server.log(format("Green: %d",grn));
        server.log(format("Blue: %d", blu));
        */
        redDuty = red*(1.0/255.0);
        grnDuty = grn*(1.0/255.0);
        bluDuty = blu*(1.0/255.0);
        
        setDuty();
    }

}

server.log("Quinn Started");
imp.configure("Quinn", [ rgbInput() ], []);

setDuty();
//EOF