
const RFIDLOCKOUTTIME   = 2;

id <- "";

// Called when an RFID scan occurs
function rfidCallback(){
    local b = uart.read();
    // don't finish a read until the newline comes in 
    while(b > 0) {
        // Look for newline (ASCII 13)
        if (b == 13) {
            server.log("Read RFID: "+id);
            // clear the id variable for the next set of reads
            id = "";
            
            // disable the reader for a second to prevent double-reads
            uart.configure(2400, 8, PARITY_NONE, 1, NO_CTSRTS | NO_TX);
            imp.wakeup(RFIDLOCKOUTTIME, function() {
                uart.configure(2400, 8, PARITY_NONE, 1, NO_CTSRTS | NO_TX, rfidCallback);
            });

        } else if(b > 32) {
            // newline hasn't arrived; build the id string
            id += format("%c", b);
        }
        b = uart.read();
    }
}


uart <- hardware.uart12;
uart.configure(2400, 8, PARITY_NONE, 1, NO_CTSRTS | NO_TX, rfidCallback);