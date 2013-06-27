

const SSID = "yourssid";
const PASSWORD = "yourwpakey";
const THROTTLE_TIME = 5;
const SUCCESS_TIMEOUT = 10;

throttle_protection <- false;
finished <- false;

mac <- imp.getmacaddress();
impeeid <- hardware.getimpeeid();

bless_success <- false;

server.log(mac);
switch (mac) {
    case "fixtureimpsmacaddress":
        server.log("This is the factory imp with mac " + mac + " and factory test fixture impee ID" + impeeid + ". It will blinkup to SSID " + SSID);
        
        hardware.pin9.configure(DIGITAL_OUT);
        hardware.pin9.write(1);
        hardware.pin1.configure(DIGITAL_IN_PULLUP, function() {
            local buttonState = hardware.pin1.read();
            if (buttonState == 0 && !throttle_protection) {
                
                // Don't allow this to happen more than once per XXX seconds
                throttle_protection = true;
                imp.wakeup(THROTTLE_TIME, function() { throttle_protection = false })
                
                // Start the actual blinkup (which includes asking the server for a factory token)
                server.log("Starting factory blinkup.")
                server.factoryblinkup(SSID, PASSWORD, hardware.pin9, BLINKUP_FAST); 

            }
        })
        break;
        
    default:
        server.log("This is the impee to be tested and (maybe) blessed.");
        
        // Setup a timeout function which reports failure back to the factory process
        imp.wakeup(SUCCESS_TIMEOUT, function () {
            if (!throttle_protection) {
                
                // Don't allow this to happen more than once 
                throttle_protection = true;
                
                // Notify the server of the success and handle the response
                server.log("Testing timed out.")
                //server.bless(false, function(bless_success) {
                //    server.log("Blessing (negative) " + (bless_success ? "PASSED" : "FAILED") + " for impee " + impeeid + " and mac " + mac)
                //})
            }
        })

        hardware.pin9.configure(DIGITAL_OUT);
        hardware.pin9.write(0);

        // Setup a button handler to indicate that the factory tests where successful. 
        // There should probably be some code that actually does stuff (such as light up LEDs or play audio).
        hardware.pin1.configure(DIGITAL_IN_PULLUP, function() {
            // We have an push down or push up event
            local buttonState = hardware.pin1.read();
            if (buttonState == 0 && !throttle_protection) {
                
                // Don't allow this to happen more than once 
                throttle_protection = true;
                
                // Notify the server of the success and handle the response
                server.log("Testing passed.")
                hardware.pin9.write(1);
                
                server.bless(true, function(bless_success) {
                    server.log("Blessing " + (bless_success ? "PASSED" : "FAILED") + " for impee " + impeeid + " and mac " + mac)
                });
                imp.sleep(1);
                hardware.pin9.write(0);
            }
        });
}