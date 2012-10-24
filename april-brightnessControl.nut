// April with potentiometer and brightness-controlled LED

/* output port sends float from 0 to 1 showing potentiometer position
 * input port drives LED brightness
 *
 * T. Buttner 10/23/12
 */
 
/* Pin Assignments
 * Pin 9 = LED sink (configure for PWM)
 * Pin 8 = potentiometer wiper
 */
 
// Configure hardware

// pin 9 sinks current from the LED. When we set this pin low the LED will turn on.
// We can control apparent brightness by varying the duty cycle of a square wave sent to this pin (pulse-width modulation)
// Configure for PWM on pin 9. First parameter = pin mode
// Second parameter = period of PWM signal in seconds. Period = 1/frequency. 
// Third parameter = duty cycle. Floating-point number between 0.0 and 1.0, where 1.0 is on 100% duty cycle
// Note that we start with the LED off
hardware.pin9.configure(PWM_OUT, 1.0/500.0, 1.0);

// pin 8 is an analog input (we read the voltage on the pin with an ADC)
// analog inputs read a value between 0 (for 0 V) and 65,535 (16-bit ADC) for the imp's supply voltage, which should be 3.3V
hardware.pin8.configure(ANALOG_IN);
// you can read the imp's input voltage at any time with:
local voltage = hardware.voltage();
server.log(format("Running at %.2f V", voltage));
// we don't need to measure this because we've hooked the potentiometer up to the imp supply voltage

server.log("Hardware Configured");

// create an output port to output the signal from our pushbutton switch
local out_pot = OutputPort("potentiometer");

function checkPot() {
    local potValue = (hardware.pin8.read()) / 65535.0;
    // note that we divide by 65535.0 to get a value between 0.0 and 1.0
    server.show(potValue);
    out_pot.set(potValue);
    
    // schedule us to wake up and run this function again.
    // first parameter: time in seconds til next wakeup. Use a floating-point number (i.e. "1.0")
    // second parameter: name of the function to run when we wake back up
    imp.wakeup(0.5, checkPot);
}

class ledBrightness extends InputPort
{
    name = "LED Brightness"
    type = "number"
    
    function set(value) {
        // since pin 9 is configured for PWM, we can set the duty cycle with pin.write()
        // write a floating point number between 0.0 and 1.0, where 1.0 = 100% duty cycle
        hardware.pin9.write(1.0-value);
    }

}

server.log("April Remote Brightness Controller Started");
// imp.configure registers us with the Imp Service
// The first parameter Sets the text shown on the top line of the node in the planner - i.e., what this node is
// The second parameter is a list of input ports in square brackets
// The third parameter is a list of output ports in square brackets
imp.configure("April Brightness Controller", [ ledBrightness() ], [out_pot]);

// call our checkPot function from above
// note that at the end of checkPot, we use imp.wakeup to schedule the next run of the checkSwitch function
// this is a common structure in imp software - set up a function to periodically take care of business, and have it schedule its own next run
checkPot();

//EOF