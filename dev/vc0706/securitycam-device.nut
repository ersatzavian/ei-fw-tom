const CHUNK_SIZE = 8192; // integer multiple of 8

// Need to do this just once to configure ATSHA
server.log("Impee ID: "+hardware.getimpeeid());
agent.send("id",hardware.getimpeeid());
hardware.configureimpee({forceupgrade = 0});

uart <- hardware.uart1289;
spi <- hardware.spi257;
cs_l <- hardware.pin1;

// radio shack shields boot at 115200 baud
// adafruit board boots at 38400
uart.configure(38400, 8, PARITY_NONE, 1, NO_CTSRTS);
spi.configure(0, 4000); // starts to break up at 6MHz
cs_l.configure(DIGITAL_OUT)
cs_l.write(1)

const CAMERA_COMMAND_RESET     = 0x26
const CAMERA_COMMAND_READ_DATA = 0x30

function uart_read_blocking(nBytes) {
    local bytesRead = 0;
    local buf = blob(nBytes);
    local start = hardware.millis();
    while((bytesRead < nBytes))  {
        local b = uart.read();
        if(b >= 0) {
            buf[bytesRead] = b;
            bytesRead += 1;
        }
    }
    return buf;
}

function camera_response(response) {
    //server.log("Blocking Read from UART");
    local readback = uart_read_blocking(response.len());
    foreach(i, val in readback) {
        if(response[i] != val) {
            local failString = "Incorrect response";
            foreach(i, val in readback) {
                failString += format(" %02x", val);
            }
            throw failString;
        }
    }
}
function camera_command(request, response) {
    while(uart.read() >= 0) {
        // flush the read buffer
    }
    //server.log("Sending Camera Request via UART");
    uart.write(request);
    uart.flush();
    camera_response(response);
}

function camera_reset() {
    camera_command("\x56\x00\x26\x00", "\x76\x00\x26\x00");
//    uart.configure(38400, 8, PARITY_NONE, 1, NO_CTSRTS);
}

function camera_readjpeg(size) {
    local num_chunks = math.ceil(size.tofloat()/CHUNK_SIZE).tointeger();
    agent.send("jpeg_start", size);

    // Ask to read it all
    camera_command(
            format("\x56\x00\x32\x0C\x00\x0F\x00\x00\x00\x00\x00\x00%c%c\x00\x00", size/256, size%256),
            "\x76\x00\x32\x00\x00"
        );

    cs_l.write(0);
        
    // Dummy byte, because it sends us 0x30 for no good reason
    spi.writeread("\xff");
    
    for(local i = 0; i < num_chunks; i++) {
        local startingAddress = i*CHUNK_SIZE;
        local buf = spi.readblob(CHUNK_SIZE);
        agent.send("jpeg_chunk", [startingAddress, buf]);
    }

    cs_l.write(1);
        
    agent.send("jpeg_end", 1);

    // After data transfer it sends response again, check we got it....or we could just ignore
    camera_response("\x76\x00\x32\x00\x00");        
}

function camera_stop() {
    camera_command("\x56\x00\x36\x01\x00", "\x76\x00\x36\x00\x00");
    server.log("Camera Stopped.");
}

function camera_resume() {
    camera_command("\x56\x00\x36\x01\x02", "\x76\x00\x36\x00\x00");
    server.log("Camera Resumed");
}

function camera_takepicture() {
    // get length
    camera_command("\x56\x00\x34\x01\x00", "\x76\x00\x34\x00\x04\x00\x00");
    local sizeBuf = uart_read_blocking(2);
    local jpegSize = sizeBuf[0] * 256 + sizeBuf[1];
    server.log("Captured JPEG: "+jpegSize);
    return jpegSize;
}

function camera_set_compressionratio(ratio) {
    camera_command(format("\x56\x00\x31\x05\x01\x01\x12\x04%c", ratio), "\x76\x00\x31\x00\x00");
    server.log("Camera Compression Ratio set to "+ratio);
}

function camera_set_size_160x120() {
    camera_command("\x56\x00\x31\x05\x04\x01\x00\x19\x22", "\x76\x00\x31\x00\x00");
    server.log("Image Size set to 160x120");
}
function camera_set_size_640x480() {
    camera_command("\x56\x00\x31\x05\x04\x01\x00\x19\x00", "\x76\x00\x31\x00\x00");
    server.log("Image Size set to 640x480");
}

agent.on("take_picture", function(v) {
    //server.log("Agent Requested Picture");
    local t = hardware.millis();
    camera_stop(); // stop capture
    local imageSize = camera_takepicture();
    camera_readjpeg(imageSize);
    server.log("Device: Photo captured & sent in "+ (hardware.millis()-t)+ " ms");
    camera_resume(); // resume capture
});

function camera_upgrade_baudrate() {
    camera_command("\x56\x00\x24\x03\x01\x0D\xA6", "\x76\x00\x24\x00\x00"); // set baud rate to 115200
    uart.configure(115200, 8, PARITY_NONE, 1, NO_CTSRTS);
}

function camera_read_data(device_type, bytes, address) {
    uart.write(format("\x56\x00\x30\x04%c%c%c%c", device_type, bytes, address/256, address%256));
    uart.flush();
    local packet_header = uart_read_blocking(5);
    local payload = uart_read_blocking(bytes);
    return payload;
}

imp.configure("Camera", [], []);

//camera_reset();
//imp.sleep(0.5);
//camera_set_size_640x480();
//camera_upgrade_baudrate();
server.log("Camera Ready");