// April with brightness-controlled LED

hardware.pin9.configure(PWM_OUT, 1.0/500.0, 1.0);

class ledBrightness extends InputPort
{
    name = "LED Brightness"
    type = "number"
    
    function set(value) {
        // since pin 9 is configured for PWM, we can set the duty cycle with pin.write()
        // write a floating point number between 0.0 and 1.0, where 1.0 = 100% duty cycle
        server.log(value);
        hardware.pin9.write(1.0-value);
    }

}

server.log("Brightness Controller Started");
imp.configure("April Brightness Controller", [ ledBrightness() ], []);