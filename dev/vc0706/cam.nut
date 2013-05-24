/* Imp firmware for RadioShack Camera Shield
 Shield is Based on VC0706 Camera Module
 http://blog.radioshack.com/2013/01/radioshack-camera-shield-for-arduino-boards/
 
 T. Buttner
 5/10/13
*/

// size of data chunks to send agent. Large multiple of 8.
const CHUNK_SIZE = 8192;

// register with imp service
imp.configure("RS Camera",[],[]);

class camera {
    static VC0706_PROTOCOL_SIGN                =  0x56
    static VC0706_SERIAL_NUMBER                =  0x00

    static VC0706_COMMAND_RESET                =  0x26
    static VC0706_COMMAND_GEN_VERSION          =  0x11
    static VC0706_COMMAND_TV_OUT_CTRL          =  0x44
    static VC0706_COMMAND_OSD_ADD_CHAR         =  0x45
    static VC0706_COMMAND_DOWNSIZE_SIZE        =  0x53
    static VC0706_COMMAND_READ_FBUF            =  0x32
    static FBUF_CURRENT_FRAME                  =  0
    static FBUF_NEXT_FRAME                     =  0

    // 0x0A for UART Transfer ("MCU Mode")
    // 0x0F for SPI Transfer
    static FBUF_TRANSFER_MODE_UART             =  0x0A
    static FBUF_TRANSFER_MODE_SPI              =  0x0F

    static VC0706_COMMAND_FBUF_CTRL            =  0x36
    static VC0706_COMMAND_COMM_MOTION_CTRL     =  0x37
    static VC0706_COMMAND_COMM_MOTION_DETECTED =  0x39
    static VC0706_COMMAND_POWER_SAVE_CTRL      =  0x3E
    static VC0706_COMMAND_COLOR_CTRL           =  0x3C
    static VC0706_COMMAND_MOTION_CTRL          =  0x42

    static VC0706_COMMAND_WRITE_DATA           =  0x31
    static VC0706_COMMAND_GET_FBUF_LEN         =  0x34

    static READ_BLOCKSIZE                      =  56

    // Communication Parameters which may change during runtime
    UART_BAUD = 115200;
    
    // set by constructor
    uart = null;
    spi = null;
    cs_l = null;
    
    /**************************************************************************
     *
     * Constructor takes in a UART interface, initializes it, and resets the camera
     *
     *************************************************************************/
    constructor(uart,spi,cs_l) {
        this.uart = uart;
        this.uart.configure(UART_BAUD, 8, PARITY_NONE, 1, NO_CTSRTS);

        this.spi = spi;
        this.spi.configure(CLOCK_IDLE_HIGH,4000); // SPI Transfer becomes unreliable around 6MHz
        
        this.cs_l = cs_l;
        this.cs_l.configure(DIGITAL_OUT);
        this.cs_l.write(1);
        
        reset();
    }

    /**************************************************************************
     *
     * Re-initialize Camera
     *
     *************************************************************************/
    function reset() {
        local tx_buffer = blob(4);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_RESET,'b');
        tx_buffer.writen(0x00, 'b');
        uart.write(tx_buffer);
        uart.flush();
    }

    /**************************************************************************
     *
     * Get firmware version from Camera
     *
     *************************************************************************/
    function get_version() {
        local tx_buffer = blob(4);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_GEN_VERSION,'b');
        tx_buffer.writen(0x00,'b');
        uart.write(tx_buffer);
        uart.flush();
    }

    /**************************************************************************
     *
     * Stop or Start Camera's TV Output (not pinned out in HW)
     *
     * Input:   val (boolean)
     *              0 to stop TV Output
     *              1 to start TV Output
     *
     *************************************************************************/
    function set_tv_out(val) {
        local tx_buffer = blob(5);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_TV_OUT_CTRL,'b');
        tx_buffer.writen(0x01,'b');

        if (val) {
            tx_buffer.writen(1,'b');
        } else {
            tx_buffer.writen(0,'b');
        }
        
        uart.write(tx_buffer);
        uart.flush();
    }

    /**************************************************************************
     *
     * Adds OSD Characters to Channels (Channel 1)
     * 
     * Input:   column (integer)
     *          row (integer)
     *          osd_str (string)
     *              string to display, max 14 characters
     *
     *************************************************************************/
    function set_osd_str(col, row, osd_str) {
        local osd_str_len = osd_str.len();
        if (osd_str_len > 14) {
            osd_str_len = 14;
        }

        col = col & 0x0f;
        row = row & 0x0f;
        local col_row = ((col << 4) | row);

        local tx_buffer = blob(osd_str_len+6);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_OSD_ADD_CHAR,'b');
        tx_buffer.writen(osd_str_len+2,'b');
        tx_buffer.writen(osd_str_len,'b');
        tx_buffer.writen(col_row,'b');

        for (local i = 0; i < osd_str_len; i++) {
            tx_buffer.writen(osd_str[i],'b');
        }

        uart.write(tx_buffer);
        uart.flush();
    }
    /**************************************************************************
     *
     * Control Width and Height Downsize Parameters
     *
     * Input: scale_width (integer, 0 to 2)
     *             0 -> 1:1
     *             1 -> 1:2
     *             2 -> 1:4
     *        scale_height (integer, 0 to 2)
     *             0 -> 1:1
     *             1 -> 1:2
     *             2 -> 1:4 
     *
     *************************************************************************/
    function set_w_h_downsize(scale_width, scale_height) {
        if (scale_width > 2) {
            scale_width = 2;
        }
        if (scale_height > scale_width) {
            scale_height = scale_width;
        }

        local scale = ((scale_height << 2) | scale_width);

        local tx_buffer = blob(5);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_DOWNSIZE_SIZE,'b');
        tx_buffer.writen(0x01,'b');
        tx_buffer.writen(scale,'b');

        uart.write(tx_buffer);
        uart.flush();
    }

    /**************************************************************************
     *
     * Read image data from frame buffer
     *
     * Input: buffer_address (4 bytes)
     *        buffer_length  (4 bytes)
     *
     * No output or return value; send command, then call read_buffer 
     *
     *************************************************************************/
    function read_frame_buffer(buffer_address, buffer_len) {
        local tx_buffer = blob(16);

        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_READ_FBUF,'b');
        tx_buffer.writen(0x0C,'b');
        tx_buffer.writen(FBUF_CURRENT_FRAME,'b');
        tx_buffer.writen(FBUF_TRANSFER_MODE_UART,'b');
        
        // starting address
        tx_buffer.writen((buffer_address >> 24), 'b');
        tx_buffer.writen((buffer_address >> 16), 'b');
        tx_buffer.writen((buffer_address >> 8), 'b');
        tx_buffer.writen((buffer_address & 0xFF), 'b');

        // data length
        tx_buffer.writen((buffer_len >> 24), 'b');
        tx_buffer.writen((buffer_len >> 16), 'b');
        tx_buffer.writen((buffer_len >> 8), 'b');
        tx_buffer.writen((buffer_len & 0xFF), 'b');

        // delay time
        tx_buffer.writen(0x00,'b');
        tx_buffer.writen(0x0A,'b');

        uart.write(tx_buffer);
        uart.flush();
    }

    /**************************************************************************
     *
     * Write frame buffer control register
     *
     * Input: val (1 byte)
     *              0 -> stop current frame
     *              1 -> stop next frame
     *              2 -> step frame
     *              3 -> resume frame
     *
     *************************************************************************/
    function ctrl_frame_buffer(val) {
        if (val > 3) {
            val = 3;
        }

        local tx_buffer = blob(5);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_FBUF_CTRL,'b');
        tx_buffer.writen(0x01,'b');
        tx_buffer.writen(val,'b');

        uart.write(tx_buffer);
        uart.flush();
    }

    /**************************************************************************
     *
     * Enable/disable motion monitoring over UART interface
     *
     * Input: val (1 byte)
     *              0 -> stop motion monitoring over UART
     *              1 -> start motion monitoring over UART
     *
     *************************************************************************/
    function set_motion_detect(val) {
        local tx_buffer = blob(5);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_COMM_MOTION_CTRL,'b');
        if (val) {
            tx_buffer.writen(0x01,'b');
        } else {
            tx_buffer.writen(0x00,'b');
        }

        uart.write(tx_buffer);
        uart.flush();
    }

    /**************************************************************************
     *
     * Enable/disable motion monitoring
     *
     * Input: val (1 byte)
     *              0 -> disable motion monitoring
     *              1 -> enbale motion monitoring
     *
     *************************************************************************/
    function set_motion_detect_en(val) {
        local tx_buffer = blob(7);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_MOTION_CTRL,'b');
        tx_buffer.writen(0x03,'b');
        tx_buffer.writen(0x00,'b');
        tx_buffer.writen(0x01,'b');
        if (val) {
            tx_buffer.writen(0x01,'b');
        } else {
            tx_buffer.writen(0x00,'b');
        }

        uart.write(tx_buffer);
        uart.flush();
    }

    /**************************************************************************
     *
     * Get byte lengths in frame buffer
     *
     * Input: type (1 byte)
     *              0 -> current frame buffer
     *              1 -> next frame buffer
     *
     *************************************************************************/
    function get_frame_buffer_len(type) {
        local tx_buffer = blob(5);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_GET_FBUF_LEN,'b');
        tx_buffer.writen(0x01,'b');
        if (type) {
            tx_buffer.writen(0x01,'b');
        } else {
            tx_buffer.writen(0x00,'b');
        }

        uart.write(tx_buffer);
        uart.flush();
    }

    /**************************************************************************
     *
     * Enable/disable uart power save
     * Used to stop current frame for read
     *
     * Input: val (boolean)
     *              0 -> disable powersave (resume)
     *              1 -> enable powersave (pause)
     *
     *************************************************************************/
    function set_powersave(val) {
        local tx_buffer = blob(7);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_POWER_SAVE_CTRL,'b');
        tx_buffer.writen(0x03,'b');
        // power save control mode
        tx_buffer.writen(0x00,'b');
        // control by UART
        tx_buffer.writen(0x01,'b');
        // power save mode
        if (val) {
            tx_buffer.writen(0x01,'b');
        } else {
            tx_buffer.writen(0x00,'b');
        }

        uart.write(tx_buffer);
        uart.flush();
    }

    /**************************************************************************
     *
     * Select between black/white and color capture
     *
     * Input: show_mode (integer 0-2)
     *              0 -> auto mode 
     *              1 -> color mode
     *              2 -> black and white mode
     *
     *************************************************************************/
    function set_uart_color_ctrl(show_mode) {
        local tx_buffer = blob(6);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_COLOR_CTRL,'b');
        tx_buffer.writen(0x02,'b');
        // control by UART
        tx_buffer.writen(0x01,'b');
        // automatically step black-white and color
        if (show_mode > 2) {
            show_mode = 2;
        }
        tx_buffer.writen(show_mode,'b');

        uart.write(tx_buffer);
        uart.flush();
    }

    /**************************************************************************
     *
     * set JPEG compression ratio
     *
     * Input: ratio (integer, 13 - 63)
     *
     *************************************************************************/
    function set_compression_ratio(ratio) {
        if (ratio > 63) {
            ratio = 63;
        }
        if (ratio < 13) {
            ratio = 13;
        }
        local vc_comp_ratio = ((ratio - 13) * 4) + 53; // math lol

        local tx_buffer = blob(9);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_WRITE_DATA,'b');
        tx_buffer.writen(0x05,'b');
        // chip register
        tx_buffer.writen(0x01,'b');
        // bytes ready to write
        tx_buffer.writen(0x01,'b');
        // register address
        tx_buffer.writen(0x12,'b');
        tx_buffer.writen(0x04,'b');
        tx_buffer.writen(vc_comp_ratio,'b');

        uart.write(tx_buffer);
        uart.flush();
    }

    /* Wrapper functions for more readability */
    function camera_resume() {
        ctrl_frame_buffer(3);
    }

    function camera_pause() {
        ctrl_frame_buffer(0);
    }

    function set_size_160x120() {
        local tx_buffer = blob(9);

        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_WRITE_DATA,'b');
        tx_buffer.writen(0x05,'b');
        tx_buffer.writen(0x04,'b');
        tx_buffer.writen(0x01,'b');
        tx_buffer.writen(0x00,'b');
        tx_buffer.writen(0x19,'b');
        tx_buffer.writen(0x22,'b');

        uart.write(tx_buffer);
        uart.flush();
    }

    function set_size_640x480() {
        local tx_buffer = blob(9);

        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_WRITE_DATA,'b');
        tx_buffer.writen(0x05,'b');
        tx_buffer.writen(0x04,'b');
        tx_buffer.writen(0x01,'b');
        tx_buffer.writen(0x00,'b');
        tx_buffer.writen(0x19,'b');
        tx_buffer.writen(0x00,'b');
        
        uart.write(tx_buffer);
        uart.flush();
    }
     

    /**************************************************************************
     *
     * Configure something interesting involving motion capture. 
     * Appears to actually just be a generic command to write to SOC register
     * Use with some caution
     *
     * Input: addr (2 bytes)
     *        data (4 bytes)
     *
     *************************************************************************/
     function set_motion_windows(addr, data) {
        local tx_buffer = blob(12);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_WRITE_DATA,'b');
        tx_buffer.writen(0x08,'b');
        tx_buffer.writen(0x01,'b');
        tx_buffer.writen(0x04,'b');
        tx_buffer.writen((addr >> 8),'b');
        tx_buffer.writen((addr & 0xFF),'b');
        tx_buffer.writen((data >> 24),'b');
        tx_buffer.writen((data >> 16),'b');
        tx_buffer.writen((data >> 8),'b');
        tx_buffer.writen((data & 0xFF),'b');

        uart.write(tx_buffer);
        uart.flush();
     }

    /**************************************************************************
    * 
    * Read JPEG data from camera via SPI
    * 
    * Input: size (integer)
    *           bytes to read via SPI
    *
    **************************************************************************/
    function read_jpeg_spi(size) {
        local num_chunks = math.ceil(size.tofloat()/CHUNK_SIZE).tointeger();
        agent.send("jpeg_start",size);

        // request entire buffer from camera via SPI
        local tx_buffer = blob(16);
        tx_buffer.writen(VC0706_PROTOCOL_SIGN,'b');
        tx_buffer.writen(VC0706_SERIAL_NUMBER,'b');
        tx_buffer.writen(VC0706_COMMAND_READ_FBUF,'b');
        tx_buffer.writen(0x0C,'b');
        tx_buffer.writen(0x00,'b');
        tx_buffer.writen(0xFF,'b');
        while (!tx_buffer.eos()) {
            tx_buffer.writen(0x00,'b');
        }
        uart.write(tx_buffer);
        uart.flush();

        // assert chip select for the spi interface
        cs_l.write(0);

        // camera sends 0x30 for no apparent reason, so get rid of it
        spi.writeread("\xff");

        for(local i = 0; i < num_chunks; i++) {
            local startingAddress = i*CHUNK_SIZE;
            local buf = spi.readblob(CHUNK_SIZE);
            agent.send("jpeg_chunk", [startingAddress, buf]);
        }

        cs_l.write(1);
        
        agent.send("jpeg_end", 1);
    }

    /**************************************************************************
     *
     * Enable/disable motion monitoring over UART interface
     *
     * Input: val (1 byte)
     *              0 -> stop motion monitoring over UART
     *              1 -> start motion monitoring over UART
     *
     *************************************************************************/
    function capture_photo() {
    
        camera_resume();
        imp.sleep(0.01);
        camera_pause();

        // clear RX buffer
        while (uart.read() != -1) {
            uart.read();
        }

        imp.sleep(0.005);

        get_frame_buffer_len(0);
        imp.sleep(0.01);

        local sizeBuf = read_buffer_uart(9);
        local jpegSize = sizeBuf[0] * 256 + sizeBuf[1];

        server.log(format("Captured JPEG (%d bytes)",jpegSize));

        read_jpeg_spi(jpegSize);

        server.log("Device: done sending image");
    }

    /**************************************************************************
     *
     * Read a buffer from the camera module via UART
     *
     * Input:
     *
     *************************************************************************/
    function read_buffer_uart(nBytes) {
        local rx_buffer = blob(nBytes);

        local data = uart.read()
        //server.log(format("Got: 0x%02x",data));
        while ((data != -1) && (rx_buffer.tell() < nBytes)) {
            rx_buffer.writen(data,'b');
            data = uart.read();
            server.log(format("Got: 0x%02x",data));
        }
        if (rx_buffer[0] != 0x76) {
            server.error(format("Device got invalid return message: 0x%02x",rx_buffer[0]));
        }
        if (rx_buffer[1] != VC0706_SERIAL_NUMBER) {
            server.error(format("Message returned with invalid serial number: 0x%02x",rx_buffer[1]));
        }

        return rx_buffer;
    }
}

myCamera <- camera(hardware.uart1289,hardware.spi257,hardware.pin1);
server.log("Camera Ready.");

agent.on("take_picture", function(val) {
    myCamera.capture_photo();
});
