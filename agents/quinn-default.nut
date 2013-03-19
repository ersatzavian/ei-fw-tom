// 6-channel 5A PWM Driver (RGB In)

// initialize some handy values
// PWM frequency in Hz
local pwm_f = 500.0;

// Configure hardware
// red pins (on most RGB tape)
hardware.pin1.configure(PWM_OUT, 1.0/pwm_f, 1.0);
hardware.pin7.configure(PWM_OUT, 1.0/pwm_f, 1.0);
// green pins (on most RGB tape)
hardware.pin8.configure(PWM_OUT, 1.0/pwm_f, 1.0);
hardware.pin9.configure(PWM_OUT, 1.0/pwm_f, 1.0);
// blue pins (on most RGB tape)
hardware.pin2.configure(PWM_OUT, 1.0/pwm_f, 1.0);
hardware.pin5.configure(PWM_OUT, 1.0/pwm_f, 1.0);


imp.configure("Quinn Financier", [], []);

agent.on("update", function(value) {
    if (value.len() != 3) {
        server.error("Device Received Invalid Color Update");
    } else {
        local red = value[0].tointeger();
        local green = value[1].tointeger();
        local blue = value[2].tointeger();
        
        hardware.pin1.write(red*(1.0/255.0));
        hardware.pin7.write(red*(1.0/255.0));
        hardware.pin8.write(green*(1.0/255.0));
        hardware.pin9.write(green*(1.0/255.0));
        hardware.pin2.write(blue*(1.0/255.0));
        hardware.pin5.write(blue*(1.0/255.0));
    }
});