// 6-channel 5A PWM Driver (Float 0.0 to 1.0 In)
 
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
local redDuty1 = 256.0;
local bluDuty1 = 256.0;
local grnDuty1 = 256.0;
local redDuty2 = 256.0;
local bluDuty2 = 256.0;
local grnDuty2 = 256.0;

// Configure hardware
hardware.pin1.configure(PWM_OUT, 1.0/pwm_f, redDuty1, 256);
hardware.pin2.configure(PWM_OUT, 1.0/pwm_f, grnDuty1, 256);
hardware.pin5.configure(PWM_OUT, 1.0/pwm_f, grnDuty2, 256);
hardware.pin7.configure(PWM_OUT, 1.0/pwm_f, redDuty2, 256);
hardware.pin8.configure(PWM_OUT, 1.0/pwm_f, bluDuty2, 256);
hardware.pin9.configure(PWM_OUT, 1.0/pwm_f, bluDuty1, 256);

server.log("Hardware Configured");

function setDuty() {
    hardware.pin1.write(redDuty1);
    hardware.pin7.write(redDuty2);
    hardware.pin2.write(grnDuty1);
    hardware.pin5.write(grnDuty2);
    hardware.pin8.write(bluDuty2);
    hardware.pin9.write(bluDuty1);
    
    imp.wakeup(0.25, setDuty);
}

class rgbInput1 extends InputPort
{
    name = "RGB Input 1"
    type = "color"
    
    function set(value) {
        // fully counterclockwise = red
        redDuty1 = 255.0 - (510.0) * value;
        if (redDuty1 < 0.0) {
            redDuty1 = 0.0;
        }
        server.log(format("Red 1 set to %.2f", redDuty1));
        
        // 50% = green
        if (value < 0.5) {
            grnDuty1 = 255.0 - (510.0 * (0.5 - value));
        } else {
            grnDuty1 = 255.0 - (510.0 * (value - 0.5));
        }
        server.log(format("Green 1 set to %.2f", grnDuty1));

        // fully clockwise = blue
        if (value <= 0.5) {
            bluDuty1 = 0.0;
        } else {
            bluDuty1 = 510.0 * (value-0.5);
        }
        server.log(format("Blue 1 set to %.2f,", bluDuty1));
        
    }
}

class rgbInput2 extends InputPort
{
    name = "RGB Input 2"
    type = "color"
    
    function set(value) {
        // fully counterclockwise = red
        redDuty2 = 255.0 - (510.0) * value;
        if (redDuty2 < 0.0) {
            redDuty2 = 0.0;
        }
        server.log(format("Red 2 set to %.2f", redDuty2));
        
        // 50% = green
        if (value < 0.5) {
            grnDuty2 = 255.0 - (510.0 * (0.5 - value));
        } else {
            grnDuty2 = 255.0 - (510.0 * (value - 0.5));
        }
        server.log(format("Green 2 set to %.2f", grnDuty2));

        // fully clockwise = blue
        if (value <= 0.5) {
            bluDuty2 = 0.0;
        } else {
            bluDuty2 = 510.0 * (value - 0.5);
        }
        server.log(format("Blue 2 set to %.2f,", bluDuty2));
        
    }
}

server.log("Quinn Started");
imp.configure("Quinn", [ rgbInput1(), rgbInput2() ], []);

setDuty();
//EOF