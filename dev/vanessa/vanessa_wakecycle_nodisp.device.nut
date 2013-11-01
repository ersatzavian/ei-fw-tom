/* 
 * Vanessa Reference Design Wake-Cycle Test Firmware 
 * Display not written on wakes.
 * Tom Byrne
 * tom@electricimp.com
 * 10/23/2013
 */

/* GLOBAL CLASS AND FUNCTION DEFINITIONS ------------------------------------*/

function chkBat() {
    vbat_sns_en.write(1);
    local vbat = (vbat_sns.read()/65535.0) * hardware.voltage() * (6.9/4.7);
    vbat_sns_en.write(0);
    return vbat;
}

function chgStatusChanged() {
    if (chg_status.read()) {
        server.log("Battery Charging Stopped.");
    } else {
        server.log("Battery Charging Started.");
    }
}

/* REGISTER AGENT CALLBACKS -------------------------------------------------*/

/* RUNTIME BEGINS HERE ------------------------------------------------------*/
imp.configure("Vanessa Wake Cycler, No Display",[],[]);
imp.enableblinkup(true);

//server.log(imp.getsoftwareversion());

// Vanessa Reference Design Pin configuration
//ioexp_int_l     <- hardware.pin1;   // I/O Expander Alert (Active Low)
//spi             <- hardware.spi257;
//i2c             <- hardware.i2c89;
vbat_sns        <- hardware.pinA;   // Battery Voltage Sense (ADC)
vbat_sns.configure(ANALOG_IN);
vbat_sns_en     <- hardware.pinE;   // Battery Voltage Sense Enable
vbat_sns_en.configure(DIGITAL_OUT);
vbat_sns_en.write(0);

local datapoint = {"mac" : imp.getmacaddress(), "vbat" : format("%.2f",chkBat())};
agent.send("vbat",datapoint);

imp.onidle( function() {server.sleepfor(1);});