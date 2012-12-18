
cal rxLEDToggle = 1;  // These variables keep track of rx/tx LED toggling status
local txLEDToggle = 1;

// impeeIn will override the InputPort class. 
// Whenever data is received to the impee, we'll jump into the set(c) function defined within
class impeeIn extends InputPort
{
    name = "UART Out";
    type = "string";
    
    // This function takes whatever character was sent to the impee
    // and sends it out over the UART5/7. We'll also toggle the txLed
    function set(c)
    {
        hardware.uart57.write(c);
        toggleRxLED();
    }
}

local impeeInput = impeeIn();  // assign impeeIn class to the impeeInput
local impeeOutput = OutputPort("UART In", "string");  // set impeeOutput as a string

function initUart()
{
    hardware.configure(UART_57);    // Using UART on pins 5 and 7
    hardware.uart57.configure(19200, 8, PARITY_NONE, 1, NO_CTSRTS); // 19200 baud worked well, no parity, 1 stop bit, 8 data bits
}

function initLEDs()
{
    // LEDs are on pins 8 and 9 on the imp Shield
    // They're both active low, so writing the pin a 1 will turn the LED off
    hardware.pin8.configure(DIGITAL_OUT_OD_PULLUP);
    hardware.pin9.configure(DIGITAL_OUT_OD_PULLUP);
    hardware.pin8.write(1);
    hardware.pin9.write(1);
}

// This function turns an LED on/off quickly on pin 9.
// It first turns the LED on, then calls itself again in 50ms to turn the LED off
function toggleTxLED()
{
    txLEDToggle = txLEDToggle?0:1;    // toggle the txLEDtoggle variable
    if (!txLEDToggle)
    {
        imp.wakeup(0.05, toggleTxLED.bindenv(this)); // if we're turning the LED on, set a timer to call this function again (to turn the LED off)
    }
    hardware.pin9.write(txLEDToggle);  // TX LED is on pin 8 (active-low)
}

// This function turns an LED on/off quickly on pin 8.
// It first turns the LED on, then calls itself again in 50ms to turn the LED off
function toggleRxLED()
{
    rxLEDToggle = rxLEDToggle?0:1;    // toggle the rxLEDtoggle variable
    if (!rxLEDToggle)
    {
        imp.wakeup(0.05, toggleRxLED.bindenv(this)); // if we're turning the LED on, set a timer to call this function again (to turn the LED off)
    }
    hardware.pin8.write(rxLEDToggle);   // RX LED is on pin 8 (active-low)
}

// This is our UART polling function. We'll call it once at the beginning of the program,
// then it calls itself every 10us. If there is data in the UART57 buffer, this will read
// as much of it as it can, and send it out of the impee's outputPort.
function pollUart()
{
    imp.wakeup(0.00001, pollUart.bindenv(this));    // schedule the next poll in 10us
    
    local byte = hardware.uart57.read();    // read the UART buffer
    // This will return -1 if there is no data to be read.
    while (byte != -1)  // otherwise, we keep reading until there is no data to be read.
    {
        //  server.log(format("%c", byte)); // send the character out to the server log. Optional, great for debugging
        impeeOutput.set(byte);  // send the valid character out the impee's outputPort
        byte = hardware.uart57.read();  // read from the UART buffer again (not sure if it's a valid character yet)
        toggleTxLED();  // Toggle the TX LED
    }
}

// This is where our program actually starts! Previous stuff was all function and variable declaration.
// This'll configure our impee. It's name is "UartCrossAir", and it has both an input and output to be connected:
imp.configure("UartCrossAir", [impeeInput], [impeeOutput]);
initUart(); // Initialize the UART, called just once
initLEDs(); // Initialize the LEDs, called just once
pollUart(); // start the UART polling, this function continues to call itself
// From here, two main functions are at play:
//      1. We'll be calling pollUart every 10us. If data is sent from the UART, we'll send out out of the impee.
//      2. If data is sent into the impee, we'll jump into the set function in the InputPort.
//
// The end
