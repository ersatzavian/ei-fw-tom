/* Turkey Probe Calibration Device Firmware
 * Tom Byrne
 * 11/22/13
 */
 
/* CONSTS and GLOBAL VARS ====================================================*/
const INTERVAL = 30; // log temp data every 30 seconds
 
/* GLOBAL CLASS AND FUNCTION DEFINITIONS =====================================*/

function getTemp() {
    imp.wakeup(INTERVAL, getTemp);

    local vin = hardware.voltage();
    vtherm_en_l.write(0);
    imp.sleep(0.01);
    local vtherm_raw = vin * ((1.0 * vtherm.read()) / 65535.0);
    vtherm_en_l.write(1);
    local datapoint = {"mac":mac, "vin":vin, "vtherm":vtherm_raw};
    agent.send("data",datapoint);
}

/* AGENT EVENT HANDLERS ======================================================*/
agent.on("sleep", function(val) {
    // go to sleepfor max sleep time (1 day minus 5 seconds)
    server.sleepfor(86395);
});
 
/* RUNTIME BEGINS HERE =======================================================*/
imp.configure("Turkey Probe",[],[]);
imp.enableblinkup(true);
imp.setpowersave(true);

mac <- imp.getmacaddress();

wake        <- hardware.pin1;
wake.configure(DIGITAL_IN_WAKEUP);
vtherm_en_l   <- hardware.pin8;
vtherm_en_l.configure(DIGITAL_OUT);
vtherm_en_l.write(1);
vtherm      <- hardware.pin9;
vtherm.configure(ANALOG_IN);

getTemp();