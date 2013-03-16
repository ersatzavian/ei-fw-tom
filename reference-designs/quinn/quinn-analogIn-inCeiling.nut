// 6-channel 5A PWM Driver (Float 0.0 to 1.0 In) with Paired Channels
 
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
hardware.pin1.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
hardware.pin2.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
hardware.pin5.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
hardware.pin7.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
hardware.pin8.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
hardware.pin9.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);

server.log("Hardware Configured");

class rgbInput extends InputPort
{
    name = "Analog Input"
    type = "float"
    
    function set(value) {
        // fully counterclockwise = red
        local red = 255.0 - (510.0) * value;
        if (red < 0.0) {
            red = 0.0;
        }
        server.log(format("%s Red set to %.2f", name, red));
        
        // 50% = green
        local green = 0.0;
        if (value < 0.5) {
            green = 255.0 - (510.0 * (0.5 - value));
        } else {
            green = 255.0 - (510.0 * (value - 0.5));
        }
        server.log(format("%s Green set to %.2f", name, green));

        // fully clockwise = blue
        local blue = 0.0;
        if (value <= 0.5) {
            blue = 0.0;
        } else {
            blue = 510.0 * (value-0.5);
        }
        server.log(format("%s Blue set to %.2f,", name, blue));
        
        // now write values to pins
        hardware.pin1.write(red);
        hardware.pin7.write(red);
        hardware.pin9.write(green);
        hardware.pin8.write(green);
        hardware.pin2.write(blue);
        hardware.pin5.write(blue);
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
imp.configure("Quinn", [rgbInput(), switchInput() ], []);

//EOF