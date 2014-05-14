
const TONE = 440; // Hz
const BUFFERSIZE = 4096; // Bytes
const SAMPLERATE = 2000; // Hz
const TIME = 5; // seconds for which to run the DAC
const AMP = 32767; // raw amplitude; we'll scale the sine wave with this
OPTIONS <- AUDIO; // configuration options for the DAC
dac <- hardware.pin5;
amp_en <- hardware.pin2; // our amplifier has an enable pin
time <- 0; // starting time; x value for the sine function
incr_time <- (1.0 / SAMPLERATE); // each sample will represent this increment in time
freq <- (2.0 * PI * TONE); // convert our tone in Hz to radians per second
server.log(format("Time increment: %0.4f s",incr_time));
server.log(format("Angular frequency: %0.4f rad/s",freq));

function loadBuffer(buffer) {
    buffer.seek(0,'b');
    while (buffer.tell() < buffer.len()) {
        local val = ((AMP * math.sin(freq * time)) + AMP).tointeger();
        buffer.writen(val, 'w');
        time += incr_time;
    }
    return buffer;
}
function bufferEmpty(buffer) {
    if (!buffer) { 
        server.log("Buffer Underrun"); 
        return;
    }
    hardware.fixedfrequencydac.addbuffer(loadBuffer(buffer));
}

amp_en.configure(DIGITAL_OUT);
buffers <- [loadBuffer(blob(BUFFERSIZE)),
            loadBuffer(blob(BUFFERSIZE)),
            loadBuffer(blob(BUFFERSIZE))];
hardware.fixedfrequencydac.configure(dac, SAMPLERATE, buffers, bufferEmpty, OPTIONS);
hardware.fixedfrequencydac.start();
amp_en.write(1);

imp.wakeup(TIME, function() {
    amp_en.write(0);
    hardware.fixedfrequencydac.stop();
    server.log("Done.");
});

