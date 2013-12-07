/* Electric Imp Light Timer Device Firmware (Quinn)
 * Tom Byrne
 * tom@electricimp.com
 * 12/6/13
 */

/* CONSTS AND GLOBALS --------------------------------------------------------*/

// PWM frequency in Hz
const pwm_f = 1000.0;

/* FUNCTION AND CLASS DEFINITIONS --------------------------------------------*/


/* AGENT CALLBACK HANDLERS --------------------------------------------------*/

agent.on("setColor", function(colorTuple) {
    local red = (colorTuple.r * 1.0) / (256.0);
    local grn = (colorTuple.g * 1.0) / (256.0);
    local blu = (colorTuple.b * 1.0) / (256.0);
    
    server.log(format("Setting new color: (r,g,b) %.2f,%.2f,%.2f",red,grn,blu));
    r1.write(red);
    r2.write(red);
    g1.write(grn);
    g2.write(grn);
    b1.write(blu);
    b2.write(blu);
});

/* RUNTIME BEGINS HERE -------------------------------------------------------*/


// Configure hardware
r1 <- hardware.pin1;
r2 <- hardware.pin7;
g1 <- hardware.pin8;
g2 <- hardware.pin9;
b1 <- hardware.pin2;
b2 <- hardware.pin5;

r1.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
r2.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
g1.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
g2.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
b1.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
b2.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);

imp.configure("Light Timer - Color",[],[]);