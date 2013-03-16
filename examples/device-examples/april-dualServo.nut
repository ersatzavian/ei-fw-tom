// April controlling Servos with PWM on pins 1 and 2

/*
 * input ports set position of servos 1 and 2, respectively
 *
 * T. Buttner 11/07/12
 *
 */
 
/* Pin Assignments
 * Pin 1 = PWM for servo 1
 * Pin 2 = PWM for servo 2
 */
 
// Configure hardware

// the servos used in this example have ~170 degrees of range. Each servo has three pins: power, ground, and pulse in
// The width of the pulse determines the position of the servo
// The servo expects a pulse every 20 to 30 ms
// 0.8 ms pulse -> fully counterclockwise
// 2.6 ms pulse -> fully clockwise
// set up PWM on both pins at a period of 20 ms, and initialize the duty cycle
hardware.pin1.configure(PWM_OUT, 0.02, 0.045);
hardware.pin2.configure(PWM_OUT, 0.02, 0.045);

server.log("Hardware Configured");

class Servo extends InputPort
{
    type = "float"
    pin = null
    
    // define a constructor so that we can construct seperate instances for servos 1 and 2
    constructor(name, pin) {
        // call through to the base (InputPort) constructor with the provided name
        base.constructor(name)
        this.pin = pin
        // no need to configure the pins as we've already done it at global scope
    }
    
    function set(value) {
        // since pin 1 is configured for PWM, we can set the duty cycle with pin.write()
        // write a floating point number between 0.0 and 1.0, where 1.0 = 100% duty cycle
        this.pin.write(0.04 + (value * 0.09));
        server.log(format("%s set to %.2f", name, value));
    }
}

// imp.configure registers us with the Imp Service
// The first parameter Sets the text shown on the top line of the node in the planner - i.e., what this node is
// The second parameter is a list of input ports in square brackets
// The third parameter is a list of output ports in square brackets
imp.configure("April Dual Servo Controller", [Servo("Pan", hardware.pin1), Servo("Tilt", hardware.pin2)], []);

//EOF