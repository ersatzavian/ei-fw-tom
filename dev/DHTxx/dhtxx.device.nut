// Class for DHT11/DHT22 Temp/Humidity Sensor
// Uses SPI to emulate proprietary one-wire protocol

const SPICLK            = 937.5;
const STARTTIME_LOW     = 0.001000;    // 1 ms low time for start
const STARTTIME_HIGH    = 0.000020;  // 20 us min high time for start
const STARTTIME_SENSOR  = 0.000080;  // 80 us low / 80 us high "ACK" from sensor on START
const MARKTIME          = 0.000050;  // 50 us low pulse between 0 or 1 marks
const ZERO              = 0.000026; // 26 us high for "0"
const ONE               = 0.000075;  // 70 us high for "1"

function parse(hexblob) {
    local laststate     = 0;
    local lastbitidx    = 0;
    
    local gotack        = false;
    local rawidx        = 0;
    local result        = blob(5); // 2-byte humidity, 2-byte temp, 1-byte checksum

    local humid         = 0;
    local temp          = 0;
    
    // iterate through each bit of each byte of the returned signal
    for (local byte = 0; byte < hexblob.len(); byte++) {
        for (local bit = 7; bit >= 0; bit--) {
            
            local thisbit = (hexblob[byte] & (0x01 << bit)) ? 1:0;
            
            if (thisbit != laststate) {
                if (thisbit) {
                    // low-to-high transition; watch to see how long it is high
                    laststate = 1;
                    lastbitidx = (8 * byte) + (7 - bit);
                } else {
                    // high-to-low transition;
                    laststate = 0;
                    local idx = (8 * byte) + (7 - bit);
                    local hightime = (idx - lastbitidx) * bittime;
                    
                    // we now have one valid bit of info. Figure out what symbol it is.
                    local resultbyte = (rawidx / 8);
                    local resultbit =  7 - (rawidx % 8);
                    //server.log(format("bit %d of byte %d",resultbit, resultbyte));
                    if (hightime < ZERO) {
                        // this is a zero
                        if (gotack) {
                            // don't record any data before the ACK is seen
                            result[resultbyte] = result[resultbyte] & ~(0x01 << resultbit);
                            rawidx++;
                        }
                    } else if (hightime < ONE) {
                        // this is a one
                        if (gotack) {
                            result[resultbyte] = result[resultbyte] | (0x01 << resultbit);
                            rawidx++;
                        }
                    } else {
                        // this is a START ACK
                        gotack = true;
                    }
                }
            }
        }
    }
    
    //server.log(format("parsed: 0x %02x%02x %02x%02x %02x",result[0],result[1],result[2],result[3],result[4]));
    
    humid = (result[0] * 1.0) + (result[1] / 1000.0);
    temp = (result[2] * 1.0) + (result[3] / 1000.0);
    if (((result[0] + result[1] + result[2] + result[3]) & 0xff) != result[4]) {
        server.log("Checksum Error");
        return {"rh":0,"temp":0};
    } else {
        server.log(format("Relative Humidity: %0.1f",humid)+" %");
        server.log(format("Temperature: %0.1f C",temp));a
        return {"rh":humid,"temp":temp};
    }
}

function read() {
    local bloblen = start_low_bytes + start_high_bytes + (40 * (mark_bytes + one_bytes));
    local startblob = blob(bloblen);
    for (local i = 0; i < start_low_bytes; i++) {
        startblob.writen(0x00,'b');
    }
    for (local j = start_low_bytes; j < bloblen; j++) {
        startblob.writen(0xff,'b');
    }
    
    //server.log(format("Sending %d bytes", startblob.len()));
    local result = spi.writeread(startblob);
    local resultstr = "";
    for (local k = 0; k < result.len(); k++) {
        resultstr += format("%02x",result[k]);
    }
    //server.log(format("Read %d bytes: %s",resultstr.len()/2, resultstr));
    parse(result);
}

spi         <- hardware.spi257;
clkspeed    <- spi.configure(MSB_FIRST, SPICLK);
bittime     <- 1.0 / (clkspeed * 1000);
bytetime    <- 8.0 * bittime;

start_low_bits  <- STARTTIME_LOW / bittime;
start_low_bytes <- (start_low_bits / 8);
start_high_bits <- STARTTIME_HIGH / bittime;
start_high_bytes <- (start_high_bits / 8);
start_ack_bits  <- STARTTIME_SENSOR / bittime;
start_ack_bytes <- (start_ack_bits / 8);
mark_bits       <- MARKTIME / bittime;
mark_bytes      <- (mark_bits / 8);
zero_bits       <- ZERO / bittime;
zero_bytes      <- (zero_bits / 8);
one_bits        <- ONE / bittime;
one_bytes       <- (one_bits / 8);

server.log(format("SPI running at %d kHz (%0.6f us per bit / %0.6f us per byte)",clkspeed,
    bittime * 1000000.0, bytetime * 1000000.0));
//server.log(format("Start: %d low / %d high (%d / %d)",start_low_bits,start_high_bits,start_low_bytes,start_high_bytes));
//server.log(format("Start ACK: %d low / %d high (%d)",start_ack_bits,start_ack_bits,start_ack_bytes));
//server.log(format("Pulse: %d (%d)",mark_bits, mark_bytes));
//server.log(format("Zero: %d (%d)",zero_bits,zero_bytes));
//server.log(format("One: %d (%d)",one_bits,one_bytes));

read();
