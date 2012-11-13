// April with 2-axis joystick and switch

/* 
 * switch output port sends true/false
 * out_X port sends 0 to 1 showing x axis position
 * out_Y port sends 0 to 1 showing y axis position
 *
 * T. Buttner 11/12/12
 */
 
/* Pin Assignments
 * Pin 1 = Y-axis potentiometer wiper
 * Pin 2 = X-axis potentiometer wiper
 * Pin 5 = Pushbutton. Driven Low when pressed.
 */
 
// Configure hardware

hardware.pin1.configure(ANALOG_IN);
hardware.pin2.configure(ANALOG_IN);
// configuring the button with an internal pullup ensures that the line will be driven high unless the button is pressed
hardware.pin5.configure(DIGITAL_IN_PULLUP);

server.log("Hardware Configured");

// create an output port to output the signal from our pushbutton switch
local out_X = OutputPort("X axis");
local out_Y = OutputPort("Y axis");
local out_button = OutputPort("Button");

// we use some globals here to create a "dead band"; by not sending every single value regardless of
// whether the joystick has moved, we cut down on spurious network traffic. Since we're sending less on average,
// this also lets us set the refresh rate on imp.wakeup a little faster
local lastRawValueX = 0;
local lastRawValueY = 0;
local lastButtonState = 2;

// we use this counter to begin sending a string of updates after one reading
// "different enough" from the previous triggers an update. This smooths out the response.
local updateCounter = 0;

function checkInput() {
    
    // grab the raw values (from 0 to 65535) from the ADC on each pin
    local rawValueX = hardware.pin2.read();
    local rawValueY = hardware.pin1.read();
    
    // check to see if we're outside the "dead band". If so, set the counter so that we'll keep updating smoothly 
    // for 1 second (we wake every 0.05 seconds, so 20*0.05 = 1.0)
    if ((math.abs(rawValueX - lastRawValueX) > 100) || (math.abs(rawValueY - lastRawValueY) > 100)) {
        updateCounter = 20;
        lastRawValueX = rawValueX;
        lastRawValueY = rawValueY;
    }

    // check to see if we've recently left the "dead band" and therefore need to serve some updates
    if (updateCounter > 0) {
        // convert the ADC value to a floating point number between 0.0 and 1.0
        out_X.set(rawValueX / 65535.0);
        out_Y.set(rawValueY / 65535.0);
        updateCounter--;
        server.log(format("%.2f, %.2f", (rawValueX/65535.0), (rawValueY/65535.0)));
    }
        
    // check the state of the joystick button. If pressed, the line will be driven low
    local buttonState = hardware.pin5.read();
    // note that we also don't constantly update this value; we only report changes in state
    if (buttonState != lastButtonState) {
        lastButtonState = buttonState;
        if (buttonState == 0) {
            out_button.set(1);
            server.log("Button Pressed");
        } else {
            out_button.set(0);
            server.log("Button Released");
        }        
    }
    
    // schedule the imp to wake up in 3 ms and re-check everything, sending updates if necessary
    imp.wakeup(0.05, checkInput);
}

server.log("April Joystick Started");

// register this imp with the imp service. The first field will be displayed on the imp node in the planner. 
// the second field is a list of input ports (we have none)
// the third field is a list of output ports
imp.configure("April Joystick", [], [out_X, out_Y, out_button]);

// call our function for the first time; this will schedule itself to repeat at the end of the function via imp.wakeup
checkInput();

//EOF