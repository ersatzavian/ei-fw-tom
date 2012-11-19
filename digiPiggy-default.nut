// firmware for Digi-Piggy coin counting bank
// Reports most recent coin, total contents
// Input port for resetting the bank

// T. Buttner, 11/19/2012

/* How to read the coin detector
 *  This bank did not provide us a simple serial-out or other ordinary method of detecting coins
 *  Instead, we have to poll a series of switches, measure maximum displacement, and figure out the coin ourselves.
 *    
 *  There are 7 possible switch positions:
 *  A - switch at rest (imp asleep)
 *  B - $0.10
 *  C - $0.01
 *  D - $0.05
 *  E - $0.25
 *  F - $1.00
 *  G - $0.50
 *  
 *  The truth table: note that "7" or "8" here means "driven by 7" or "driven by 9"
 *  
 *                              Pin
 *  Switch state    |   1       2       5
 *  -----------------------------------------
 *      A           |   0       0       1
 *      B           |   1       0       1
 *      C           |   1       0       0
 *      D           |   1       0       7
 *      E           |   1       0       9
 *      F           |   9       0       1
 *      G           |   1       9       1
 *      
*/

local out_lastCoin = OutputPort("Last Coin Value");
local out_total = OutputPort("Total Value");

// debug outputs
local out_position = OutputPort("Current Switch Position");

function checkPosition() {
    hardware.pin9.write(0);
    local pin1_9Lo = hardware.pin1.read();
    local pin2_9Lo = hardware.pin2.read();
    local pin5_9Lo = hardware.pin5.read();
    
    hardware.pin9.write(1);
    local pin1_9Hi = hardware.pin1.read();
    local pin2_9Hi = hardware.pin2.read();
    local pin5_9Hi = hardware.pin5.read();
    
    hardware.pin7.write(0);
    local pin5_7Lo = hardware.pin5.read();
    
    hardware.pin7.write(1);
    local pin5_7Hi = hardware.pin5.read();
    
    /*
    server.log(format("pin1, 9 low: %d", pin1_9Lo));
    server.log(format("pin1, 9 high: %d", pin1_9Hi));
    server.log(format("pin2, 9 low: %d", pin2_9Lo));
    server.log(format("pin2, 9 high: %d", pin2_9Hi));
    server.log(format("Pin5, 9 low: %d", pin5_9Lo));
    server.log(format("Pin5, 9 high: %d", pin5_9Hi));
    */
    
    if (!pin1_9Lo && !pin1_9Hi) {
        // if pin 1 is low for both states of pin 9, we're at rest state
        return 0;
    }
    if (pin1_9Lo != pin1_9Hi) {
        // if pin 1 is being driven by pin 9, we're at position 5
        // include the pin2 check so that we don't trip over state transitions as the switch moves
        return 5;
    }
    // if position is not 0 or 5, we can ignore pin 1
    if (pin2_9Lo != pin2_9Hi) {
        // if pin 2 is being driven by pin 9, we're at position 6
        return 6;
    }
    // if position is not 6, we can ignore pin 2
    if (pin5_7Lo != pin5_7Hi) {
        // if pin 5 is being driven by pin 7, we're at position 3
        return 3;
    }
    if (pin5_9Lo != pin5_9Hi) {
        return 4;
    }
    // we've now eliminated all the imp-driven combinations. We can check either pin 5 variable
    // for the remaining two positions
    if (pin5_9Lo == 0) {
        // if pin 5 is always high and we are not at any of the previous positions, we're at position 2
        return 2;
    }
    // we could test for pin 5 to be always low here, but we're at position 1 by process of elimination
    // this has the additional benefit of not being a spurious output that will throw off the max
    return 1;
    
}

function getMaxPosition() {
    local maxPosition = 0;
    local lastPosition = 0;
    local position = -1;
    
    while (position != 0) {
        position = checkPosition();
        // only grab a position value if it is repeated
        // this prevents us from catching transitions between states
        if (position == lastPosition) {
            server.log(format("Position = %d", position));
            if (position > maxPosition) {
                maxPosition = position;
            }            
        }
        lastPosition = position;
    }
    return maxPosition;
}

function getCoin() {
    server.log("Triggered, finding new coin");
    
    local position = getMaxPosition();
    server.log(format("max position was %d", position));
    local newCoin = 0.0;
    
    if (position == 1) {
        newCoin = 0.10;
    }
    if (position == 2) {
        newCoin = 0.01;
    }
    if (position == 3) {
        newCoin = 0.05;
    }
    if (position == 4) {
        newCoin = 0.25;
    }
    if (position == 5) {
        newCoin = 1.00;
    }
    if (position == 6) {
        newCoin = 0.50;
    }
    
    if (newCoin > 0.0) {
        out_lastCoin.set(newCoin);
        server.show(format("Added $%1.2f",newCoin)); 
    }
    
    // store the total in nonvolatile memory so we can go back to sleep
    if (("nv" in getroottable()) && ("coinTotal" in nv)) {
        nv.coinTotal += newCoin;
    } else {
        nv <- {coinTotal = newCoin};
    }
    server.show(format("Total = $%1.2f", nv.coinTotal));
    out_total.set(nv.coinTotal);
    
}

// coin-detection inputs
// pin 1 is pulled down internally with a strong pullup externally
hardware.pin1.configure(DIGITAL_IN_WAKEUP, getCoin);
hardware.pin2.configure(DIGITAL_IN_PULLDOWN);
hardware.pin5.configure(DIGITAL_IN_PULLUP);

// pins 7 and 9 are used to try and drive the input pins high or low to test for connection
hardware.pin7.configure(DIGITAL_OUT);
hardware.pin9.configure(DIGITAL_OUT);
hardware.pin7.write(1);
hardware.pin9.write(1);

// lid open input
hardware.pin8.configure(DIGITAL_IN_PULLDOWN);
server.log("Hardware Configured");

imp.configure("Digi-Piggy", [], [out_position, out_lastCoin, out_total]);
