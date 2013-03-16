// Sample code for Sam @ Sears

/* Example Goals
1. Demonstrate how to configure pins as 
    a. Digital Output
    b. Digital Input
    c. Analog Input
    
2. Demonstrate how to act on hardware and software events:
    a. Change in digital input pin state
    b. Input value to software input port
    
3. Demonstrate how to output a value:
    a. to an output port, to send to another node or out via HTTP OUT
    b. to a pin (digital output)
    
4. Configure the imp with the imp service - you need this part!
*/

/* Step 1: configuring hardware -----------------------------------------------------------------------------------------------------
    Pins can be configured to do just about anything. 
    Any pin can be a digital input or output, or an analog input, or a PWM output
    Pins 1 and 5 can be an analog output
    Pin groups can also do I2C, SPI, UART
    See http://devwiki.electricimp.com/doku.php?id=imppinmux
*/

/* here we configure pin one as a digital input with an internal pullup
    pins can also be configured as pulled down, or without pullup or pulldown
    see http://devwiki.electricimp.com/doku.php?id=electricimpapi#pin_class */
hardware.pin1.configure(DIGITAL_IN_PULLUP);

/* here we configure pin 2 as a digital input, and we add a callback function
    this function will be called any time the pin's state changes */
hardware.pin2.configure(DIGITAL_IN_PULLDOWN, pin2Changed);

/* here we configure pin 7 as a digital output
    be aware! The imp can source or sink ONLY 4 mA PER PIN */
hardware.pin7.configure(DIGITAL_OUT);

/* here's how to configure a pin as an analog input, so we can read it with our 16-bit DAC */
hardware.pin5.configure(ANALOG_IN);

/* we can read that pin and get a value between 0 and 65535, where 65535 corresponds to the imp's supply voltage
    to get the imp supply voltage, we can use the hardware.voltage() function: */
local impVoltage = hardware.voltage();
local pin5ValueRaw = hardware.pin5.read();
// now we can calculate the actual voltage on pin 5:
local pin5Voltage = impVoltage * (pin5ValueRaw / 65535.0);
// note that we divide by "65535.0" with the ".0" added to force the result to be a float

server.log("Hardware Configured");


/* Step 2: acting on events -----------------------------------------------------------------------------------------------
    a. create an output port to output data from this imp into the planner
    b. write a function to serve as the callback for changes to pin 2's state (pin2Changed, from earlier)
    c. create an input port, with a "set" function that will be called when data is received
    
    Step 3 is also included, as we show how to write to pins and ports in response to hardware and software events
*/

// let's make a software output port:
// the argument we provide to the OutputPort constructor is the name of the port
local planner_out = OutputPort("planner output");
// now we can send data out into the plan with the .set() method:
planner_out.set("Hello!");
// we can also show data on this node in the plan with server.show:
server.show("Hello!");

// now let's make a function that will be automatically called when pin 2 changes (high to low or low to high)
local function pin2Changed() {
    // we can read the value of the pin very easily
    local pin2Value = hardware.pin2.read();
    // let's show the value of the pin on the planner
    server.show(format("Pin 2 value is %d", pin2Value));
    // we can also output the value to our output port
    planner_out.set(pin2Value);
    // and we can set our digital output on this event, or do just about anything else you can think of
    hardware.pin7.write(pin2Value);
}


// let's make an input port that can act on software input events
class myInput extends InputPort {
    // these members set the properties shown in the planner when you connect nodes
    name = "Input Port 1"
    type = "number"
    
    // and we'll create a set method that will be called with the value provided to the input port
    function set(value) {
        server.show(format("Received %s on Input Port 1", value));
        // you could also set pins in hardware here, or send data to an output port, or just about anything
    }
}

/* Step 4: Register with the imp service ------------------------------------------------------------------------------
    This is how we tell the imp service what this imp is doing, what its inputs are, and what its outputs are
*/

server.log("Imp Example Started");
// imp.configure registers us with the Imp Service
// The first parameter Sets the text shown on the top line of the node in the planner - i.e., what this node is
// The second parameter is a list of input ports in square brackets
// The third parameter is a list of output ports in square brackets
imp.configure("Imp Example", [ myInput() ], [planner_out]);