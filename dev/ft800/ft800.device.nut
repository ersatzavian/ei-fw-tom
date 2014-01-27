/* Pin out -
Imp pin -> FT800 pin
      2 -> MISO
      5 -> SCLK
      7 -> MOSI
      8 -> CS
      9 -> PD
*/

const RAM_CMD              = 1081344;
const RAM_DL               = 1048576;
const RAM_G                = 0;
const RAM_PAL              = 1056768;
const RAM_REG              = 1057792;

const FIFO_SIZE            = 4092;

const OPT_CENTER           = 1536;
const OPT_CENTERX          = 512;
const OPT_CENTERY          = 1024;

const FT_GPU_EXTERNAL_OSC  = 0x44;
const FT_GPU_PLL_48M       = 0x62;
const FT_GPU_CORE_RESET    = 0x68;
const FT_GPU_ACTIVE_M      = 0;

/* Definitions used for FT800 co processor command buffer */
const FT_DL_SIZE           = 8192;  //8KB Display List buffer size
const FT_CMD_FIFO_SIZE     = 8192;  //4KB coprocessor Fifo size
const FT_CMD_SIZE          = 4;     //4 byte per coprocessor command of EVE

const REG_ANALOG           = 1058104;
const REG_ANA_COMP         = 1058160;
const REG_CLOCK            = 1057800;
const REG_CMD_DL           = 1058028;
const REG_CMD_READ         = 1058020;
const REG_CMD_WRITE        = 1058024;
const REG_CPURESET         = 1057820;
const REG_CRC              = 1058152;
const REG_CSPREAD          = 1057892;
const REG_CYA0             = 1058000;
const REG_CYA1             = 1058004;
const REG_CYA_TOUCH        = 1058100;
const REG_DATESTAMP        = 1058108;
const REG_DITHER           = 1057884;
const REG_DLSWAP           = 1057872;
const REG_FRAMES           = 1057796;
const REG_FREQUENCY        = 1057804;
const REG_GPIO             = 1057936;
const REG_GPIO_DIR         = 1057932;
const REG_HCYCLE           = 1057832;
const REG_HOFFSET          = 1057836;
const REG_HSIZE            = 1057840;
const REG_HSYNC0           = 1057844;
const REG_HSYNC1           = 1057848;
const REG_ID               = 1057792;
const REG_INT_EN           = 1057948;
const REG_INT_FLAGS        = 1057944;
const REG_INT_MASK         = 1057952;
const REG_MACRO_0          = 1057992;
const REG_MACRO_1          = 1057996;
const REG_OUTBITS          = 1057880;
const REG_PCLK             = 1057900;
const REG_PCLK_POL         = 1057896;
const REG_PLAY             = 1057928;
const REG_PLAYBACK_FORMAT  = 1057972;
const REG_PLAYBACK_FREQ    = 1057968;
const REG_PLAYBACK_LENGTH  = 1057960;
const REG_PLAYBACK_LOOP    = 1057976;
const REG_PLAYBACK_PLAY    = 1057980;
const REG_PLAYBACK_READPTR = 1057964;
const REG_PLAYBACK_START   = 1057956;
const REG_PWM_DUTY         = 1057988;
const REG_PWM_HZ           = 1057984;
const REG_RENDERMODE       = 1057808;
const REG_ROMSUB_SEL       = 1058016;
const REG_ROTATE           = 1057876;
const REG_SNAPSHOT         = 1057816;
const REG_SNAPY            = 1057812;
const REG_SOUND            = 1057924;
const REG_SWIZZLE          = 1057888;
const REG_TAG              = 1057912;
const REG_TAG_X            = 1057904;
const REG_TAG_Y            = 1057908;
const REG_TAP_CRC          = 1057824;
const REG_TAP_MASK         = 1057828;
const REG_TOUCH_ADC_MODE   = 1058036;
const REG_TOUCH_CHARGE     = 1058040;
const REG_TOUCH_DIRECT_XY  = 1058164;
const REG_TOUCH_DIRECT_Z1Z2= 1058168;
const REG_TOUCH_MODE       = 1058032;
const REG_TOUCH_OVERSAMPLE = 1058048;
const REG_TOUCH_RAW_XY     = 1058056;
const REG_TOUCH_RZ         = 1058060;
const REG_TOUCH_RZTHRESH   = 1058052;
const REG_TOUCH_SCREEN_XY  = 1058064;
const REG_TOUCH_SETTLE     = 1058044;
const REG_TOUCH_TAG        = 1058072;
const REG_TOUCH_TAG_XY     = 1058068;
const REG_TOUCH_TRANSFORM_A= 1058076;
const REG_TOUCH_TRANSFORM_B= 1058080;
const REG_TOUCH_TRANSFORM_C= 1058084;
const REG_TOUCH_TRANSFORM_D= 1058088;
const REG_TOUCH_TRANSFORM_E= 1058092;
const REG_TOUCH_TRANSFORM_F= 1058096;
const REG_TRACKER          = 1085440;
const REG_TRIM             = 1058156;
const REG_VCYCLE           = 1057852;
const REG_VOFFSET          = 1057856;
const REG_VOL_PB           = 1057916;
const REG_VOL_SOUND        = 1057920;
const REG_VSIZE            = 1057860;
const REG_VSYNC0           = 1057864;
const REG_VSYNC1           = 1057868;

const DECR                 = 4;
const DECR_WRAP            = 7;
const DLSWAP_DONE          = 0;
const DLSWAP_FRAME         = 2;
const DLSWAP_LINE          = 1;
const DST_ALPHA            = 3;
const EDGE_STRIP_A         = 7;
const EDGE_STRIP_B         = 8;
const EDGE_STRIP_L         = 6;
const EDGE_STRIP_R         = 5;
const EQUAL                = 5;
const GEQUAL               = 4;
const GREATER              = 3;
const HANDLE               = 0x5000000;
const INCR                 = 3;
const INCR_WRAP            = 6;
const INT_CMDEMPTY         = 32;
const INT_CMDFLAG          = 64;
const INT_CONVCOMPLETE     = 128;
const INT_PLAYBACK         = 16;
const INT_SOUND            = 8;
const INT_SWAP             = 1;
const INT_TAG              = 4;
const INT_TOUCH            = 2;
const INVERT               = 5;

const CMDBUF_SIZE          = 4096;
const CMD_APPEND           = 4294967070;
const CMD_BGCOLOR          = 4294967049;
const CMD_BITMAP_TRANSFORM = 4294967073;
const CMD_BUTTON           = 4294967053;
const CMD_CALIBRATE        = 4294967061;
const CMD_CLOCK            = 4294967060;
const CMD_COLDSTART        = 4294967090;
const CMD_CRC              = 4294967043;
const CMD_DIAL             = 4294967085;
const CMD_DLSTART          = 4294967040; // 0xffff ff00
const CMD_EXECUTE          = 4294967047;
const CMD_FGCOLOR          = 4294967050;
const CMD_GAUGE            = 4294967059;
const CMD_GETMATRIX        = 4294967091;
const CMD_GETPOINT         = 4294967048;
const CMD_GETPROPS         = 4294967077;
const CMD_GETPTR           = 4294967075;
const CMD_GRADCOLOR        = 4294967092;
const CMD_GRADIENT         = 4294967051;
const CMD_HAMMERAUX        = 4294967044;
const CMD_IDCT             = 4294967046;
const CMD_INFLATE          = 4294967074;
const CMD_INTERRUPT        = 4294967042;
const CMD_KEYS             = 4294967054;
const CMD_LOADIDENTITY     = 4294967078;
const CMD_LOADIMAGE        = 4294967076; // 0xffff ff24
const CMD_LOGO             = 4294967089; // 0xffff ff31
const CMD_MARCH            = 4294967045;
const CMD_MEMCPY           = 4294967069;
const CMD_MEMCRC           = 4294967064;
const CMD_MEMSET           = 4294967067;
const CMD_MEMWRITE         = 4294967066;
const CMD_MEMZERO          = 4294967068;
const CMD_NUMBER           = 4294967086;
const CMD_PROGRESS         = 4294967055;
const CMD_REGREAD          = 4294967065;
const CMD_ROTATE           = 4294967081;
const CMD_SCALE            = 4294967080;
const CMD_SCREENSAVER      = 4294967087;
const CMD_SCROLLBAR        = 4294967057;
const CMD_SETFONT          = 4294967083;
const CMD_SETMATRIX        = 4294967082;
const CMD_SKETCH           = 4294967088;
const CMD_SLIDER           = 4294967056;
const CMD_SNAPSHOT         = 4294967071;
const CMD_SPINNER          = 4294967062;
const CMD_STOP             = 4294967063;
const CMD_SWAP             = 4294967041;
const CMD_TEXT             = 4294967052;
const CMD_TOGGLE           = 4294967058;
const CMD_TOUCH_TRANSFORM  = 4294967072;
const CMD_TRACK            = 4294967084;
const CMD_TRANSLATE        = 4294967079;

const KEEP                 = 1;
const L1                   = 1;
const L4                   = 2;
const L8                   = 3;
const LEQUAL               = 2;
const LESS                 = 1;
const LINEAR_SAMPLES       = 0;
const LINES                = 3;
const LINE_STRIP           = 4;
const NEAREST              = 0;
const NEVER                = 0;
const NOTEQUAL             = 6;
const ONE                  = 1;
const ONE_MINUS_DST_ALPHA  = 5;
const ONE_MINUS_SRC_ALPHA  = 4;
const OPT_CENTER           = 1536;
const OPT_CENTERX          = 512;
const OPT_CENTERY          = 1024;
const OPT_FLAT             = 256;
const OPT_MONO             = 1;
const OPT_NOBACK           = 4096;
const OPT_NODL             = 2;
const OPT_NOHANDS          = 49152;
const OPT_NOHM             = 16384;
const OPT_NOPOINTER        = 16384;
const OPT_NOSECS           = 32768;
const OPT_NOTICKS          = 8192;
const OPT_RIGHTX           = 2048;
const OPT_SIGNED           = 256;
const PALETTED             = 8;
const FTPOINTS             = 2;
const RECTS                = 9;

const REPEAT               = 1;
const REPLACE              = 2;
const RGB332               = 4;
const RGB565               = 7;
const SRC_ALPHA            = 2;
const TEXT8X8              = 9;
const TEXTVGA              = 10;
const TOUCHMODE_CONTINUOUS = 3;
const TOUCHMODE_FRAME      = 2;
const TOUCHMODE_OFF        = 0;
const TOUCHMODE_ONESHOT    = 1;
const ULAW_SAMPLES         = 1;
const ZERO                 = 0;

const ADC_DIFFERENTIAL     = 1;
const ADC_SINGLE_ENDED     = 0;
const ADPCM_SAMPLES        = 2;
const ALWAYS               = 7;
const ARGB1555             = 0;
const ARGB2                = 5;
const ARGB4                = 6;
const BARGRAPH             = 11;
const BILINEAR             = 1;
const BITMAPS              = 1;
const BORDER               = 0;

// Configurable Screen Settings
const FT_DispWidth         = 480;
const FT_DispHeight        = 272;
const FT_DispHCycle        = 548;
const FT_DispHOffset       = 43;
const FT_DispHSync0        = 0;
const FT_DispHSync1        = 41;
const FT_DispVCycle        = 292;
const FT_DispVOffset       = 12;
const FT_DispVSync0        = 0;
const FT_DispVSync1        = 10;
const FT_DispPCLK          = 5;
const FT_DispSwizzle       = 0;
const FT_DispPCLKPol       = 1;

/*
    function end() {
        return (33<<24);
    }
*/

class ft800 {
    dl_ptr          = 0;
    cp_ptr          = 0;
    freespace       = 0;
    debug           = 0;
    
    spi             = null;
    cs_l            = null;
    pd_l            = null;
    int             = null;
    
    constructor(_spi, _cs_l, _pd_l, _int) {
        this.spi    = _spi;
        this.cs_l   = _cs_l;
        this.pd_l   = _pd_l;
        this.int    = _int;
        
        dl_ptr      = 0;
        cp_ptr      = 0;
        freespace   = FIFO_SIZE;
    }
    
    /* Specify default color for the screen when the color buffer is cleared
     * red: integer value, 0-255
     * green: integer value, 0-255
     * blue: integer value, 0-255
     */
    function clear_color_rgb(red,green,blue) {
        return (2<<24)|(((red)&255)<<16)|(((green)&255)<<8)|(((blue)&255)<<0);
    }

    function color_rgb(red,green,blue) {
        return (4<<24)|(((red)&255)<<16)|(((green)&255)<<8)|(((blue)&255)<<0);
    }

    function color_a(alpha) {
        return (16<<24)|(((alpha)&255)<<0);
    }

    /* Clear Command with three parameters
     * C: Clear color buffer    (bool)
     * S: Clear stencil buffer  (bool)
     * T: Clear tag buffer      (bool)
     */
    function clear_cst(c, s, t) {
        return (38<<24)|(((c)&1)<<2)|(((s)&1)<<1)|(((t)&1)<<0);
    }

    function line_width(width) {
        return (14<<24)|(((width)&4095)<<0);
    }

    function begin(prim) {
        return (31<<24)|((prim & 15)<<0);
    }
    
    function bitmaphandle(handle) {
        return (5<<24)|((handle & 15)<<0);
    }

    function vertex2f(x, y) {
        return (1<<30)|(((x)&32767)<<15)|(((y)&32767)<<0);
    }
    
    function vertex2ii(x, y, handle=0, cell=0) {
        return (2<<30)|(((x)&511)<<21)|(((y)&511)<<12)|(((handle)&31)<<7)|(((cell)&127)<<0);
    }
    
    function point_size(size) {
        return (13<<24)|(((size)&8191)<<0);
    }
    
    function scissor_xy(x, y) {
        return ((27<<24)|(((x)&511)<<9) | (((y)&511)<<0));
    }

    function scissor_size(width, height) {
        return ((28<<24)|(((width)&1023)<<10)|(((height)&1023)<<0));
    }
    
    function bitmap_source(addr) {
        return (1<<24)|(((addr)&1048575)<<0);
    }
    function bitmap_layout(format, linestride, height) {
        return (7<<24)|(((format)&31)<<19)|(((linestride)&1023)<<9)|(((height)&511)<<0);
    }
    
    function bitmap_size(filter, wrapx, wrapy, width, height) {
        return (8<<24)|(((filter)&1)<<20)|(((wrapx)&1)<<19)|(((wrapy)&1)<<18)|(((width)&511)<<9)|(((height)&511)<<0);
    }
    
    function bitmap_transform_a(a) {
        return (21<<24)|(((a)&131071)<<0);
    }
    
    function bitmap_transform_e(e) {
        return (25<<24)|(((e)&131071)<<0);
    }

    function blend_func(src, dst) {
        return (11<<24)|(((src)&7)<<3)|(((dst)&7)<<0);
    }

    function gpu_host_cmd(cmd) {
        this.cs_l.write(0);
        this.spi.write(format("%c%c%c",cmd,0,0));
        this.cs_l.write(1);
    }
    
    function power_down(callback) {
        this.pd_l.write(0);
        imp.wakeup(0.5, callback);
    }

    function power_up(callback) {
        this.pd_l.write(1);
        imp.wakeup(0.2, callback);
    }

    function init() {
        gpu_host_cmd(FT_GPU_EXTERNAL_OSC);
        // TO-DO: get rid of imp.sleep because it's synchronous and icky.
        imp.sleep(0.2);
        
        gpu_host_cmd(FT_GPU_PLL_48M);
        imp.sleep(0.2);
        
        gpu_host_cmd(FT_GPU_CORE_RESET);
        gpu_host_cmd(FT_GPU_ACTIVE_M);
        
        // wait for the GPU to report init complete
        local timeout = 500000; // time in us
        local start = hardware.micros();
        local chip_id = gpu_read_mem(REG_ID, 1);
        while (chip_id[0] != 0x7C) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for GPU init to finish");
                return 1;
            }
            chip_id = gpu_read_mem(REG_ID, 1);
            //server.log(format("0x%02x", chip_id[0]));
        }
    }

    function config() {
        gpu_write_mem16(REG_HCYCLE, FT_DispHCycle);
        gpu_write_mem16(REG_HOFFSET, FT_DispHOffset);
        gpu_write_mem16(REG_HSYNC0, FT_DispHSync0);
        gpu_write_mem16(REG_HSYNC1, FT_DispHSync1);
        gpu_write_mem16(REG_VCYCLE, FT_DispVCycle);
        gpu_write_mem16(REG_VOFFSET, FT_DispVOffset);
        gpu_write_mem16(REG_VSYNC0, FT_DispVSync0);
        gpu_write_mem16(REG_VSYNC1, FT_DispVSync1);
        gpu_write_mem8(REG_SWIZZLE, FT_DispSwizzle);
        gpu_write_mem8(REG_PCLK_POL, FT_DispPCLKPol);
        gpu_write_mem8(REG_PCLK, FT_DispPCLK);
        gpu_write_mem16(REG_HSIZE, FT_DispWidth);
        gpu_write_mem16(REG_VSIZE, FT_DispHeight);
    
        /*Set DISP_EN to 1*/
        //local reg_gpio_dir = gpu_read_mem(REG_GPIO_DIR, 1);
        //server.log("REG_GPIO_DIR: " + reg_gpio_dir[0]);
        // This seems to control the audio
        //gpu_write_mem8(REG_GPIO_DIR, 0x83); // | reg_gpio_dir[0].tointeger());
        local reg_gpio = gpu_read_mem(REG_GPIO, 1);
        //server.log("REG_GPIO: " + reg_gpio[0]);
        gpu_write_mem8(REG_GPIO, 0x83 | reg_gpio[0].tointeger());
        
        /* Touch configuration - configure the resistance value to 1200 - this value is specific to customer requirement and derived by experiment */
        gpu_write_mem16(REG_TOUCH_RZTHRESH, 1200);
        //server.log("wrote config");
    }

    /* TODO: determine if this function needs to actually perform stringification and remove if not */
    function gpu_write_mem(addr, byte_array) {
        gpu_write_start(addr);
        foreach (i, byte in byte_array) {
            this.spi.write(format("%c",byte));
        }
        cs_l.write(1);
    }
    
    function gpu_write_blob(addr, data) {
        gpu_write_start(addr);
        this.spi.write(data);
        cs_l.write(1);
    }
    
    function gpu_write_start(addr) {
        local startStr = format("%c%c%c",(0x80 | (addr >> 16)),
            ((addr >> 8) & 0xff),(addr & 0xff));
        this.cs_l.write(0);
        this.spi.write(startStr);
    }
    
    function gpu_write_mem8(addr, byte) {
        gpu_write_start(addr);
        this.spi.write(format("%c",byte));
        this.cs_l.write(1);
    }
    
    function gpu_write_mem16(addr, int) {
        local writeStr = format("%c%c",(int & 0xff),((int >> 8) & 0xff));
        gpu_write_start(addr);
        this.spi.write(writeStr);
        this.cs_l.write(1);
    }

    function gpu_write_mem32(addr, int) {
        local writeStr = format("%c%c%c%c",(int & 0xff),((int >> 8) & 0xff),
            ((int >> 16) & 0xff),((int >> 24) & 0xff));
        gpu_write_start(addr);
        this.spi.write(writeStr);
        this.cs_l.write(1);
    }

    function gpu_read_mem(addr, len) {
        local writeStr = format("%c%c%c%c",((addr >> 16) & 0xff),((addr >> 8) & 0xff),(addr & 0xff),0);
        cs_l.write(0);
        this.spi.write(writeStr);
        local ret = this.spi.readblob(len);
        this.cs_l.write(1);
        
        return ret;
    }

    function gpu_dlswap(swap_type) {
        gpu_write_mem8(REG_DLSWAP, swap_type);
        
        local timeout = 50000; // time in us
        local start = hardware.micros();
        local swap_done = gpu_read_mem(REG_DLSWAP, 1);
        while (swap_done[0] != DLSWAP_DONE) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for display list swap.");
                return 1;
            }
            swap_done = gpu_read_mem(REG_DLSWAP, 1);
        }
    }
    
    /* Load a bitmap into general memory. Does not use the coprocessor. 
     * This command requires some information be parsed from the bitmap header. 
     * Input:
     *      bitmap_header: a table with parameters from the bitmap header:
     *          format: FT800 BMP Format code (e.g. ARGB1555)
     *          stride: linestride (4 * ((bmpheader.width * (bmpheader.bitsperpx / 8) + 3) / 4);)
     *          width: bitmap width
     *          height: bitmap height
     *          bitsperpx: bits per pixel (color depth)
     *      bitmap_data: the pixel field of the bitmap file, as a blob
     *      bitmap handle: bitmap handle to associate with this data (0-15)
     */
    function gpu_load_bmp(bitmap_header, bitmap_data, offset_x, offset_y) {
        // dump the bitmap data in graphics memory
        gpu_write_blob(RAM_G, bitmap_data);

        // start writing a display list
        dl_ptr = RAM_DL;
        gpu_write_start(RAM_DL);
        
        gpu_write_mem32(clear_color_rgb(0,0,0));  // Black the screen out
        dl_ptr += 4;
        gpu_write_mem32(clear_cst(1, 1, 1)); // clear the selected area
        dl_ptr += 4;
        gpu_write_me32(color_rgb(255,255,255));
        dl_ptr += 4;
        
        gpu_write_mem32(bitmap_source(RAM_G)); // specify the bmp source location
        dl_ptr += 4;
        gpu_write_mem32(bitmap_layout(bitmap_header.format, bitmap_header.stride, bitmap_header.height));
        dl_ptr += 4;
        //gpu_write_ram32(bitmap_layout(ARGB1555, bitmap_header.stride, bitmap_header.height));
        gpu_write_mem32(bitmap_size(NEAREST, BORDER, BORDER, bitmap_header.width, bitmap_header.height));
        dl_ptr += 4;
        gpu_write_mem32(begin(BITMAPS)); // start drawing bitmap objects
        dl_ptr += 4;
        gpu_write_mem32(vertex2ii(offset_x, offset_y, 0, RAM_G)); // place this object
        dl_ptr += 4;
        gpu_write_mem32(0); // end of display list
        dl_ptr += 4;
    
        gpu_dlswap(DLSWAP_FRAME); // swap to this display list on next draw
    }
    
    function set_rotation(val) {
        this.cs_l.write(1);
        if (val) {
            gpu_write_mem8(REG_ROTATE, 0x01);
        } else {
            gpu_write_mem8(REG_ROTATE, 0x00);
        }
        this.cs_l.write(1);
    } 

    /* Initiate a SPI transaction with the address pointer set to the current 
     * position in the coprocessor command FIFO.
     */
    function cp_stream() {
        this.cs_l.write(1);
        gpu_write_start(RAM_CMD + (cp_ptr & FIFO_SIZE));
    }
    
    function cp_start() {
        cp_stream();
        cp_send_cmd(CMD_DLSTART);
    }

    /* End a SPI transaction with the coprocessor by moving the FIFO write pointer.
     */
    function cp_swap() {
        cp_send_cmd(CMD_SWAP);
        cp_send_cmd(0);
        cp_send_cmd(CMD_DLSTART);
        cp_getfree(4);
        this.cs_l.write(1);
    }

    /* Get the current position of the coprocessor's read pointer in the command 
     * FIFO. This is used to determine the amount of free space in the FIFO and 
     * the coprocessor's progress when processing a stream of new commands. 
     */
    function cp_rdptr() {
        // release the chip select so we can select a new memory offset with gpu_read_mem
        this.cs_l.write(1);
        // gpu_read_mem sets the chip select on its own to start the transaction
        local rdpointerraw = gpu_read_mem(REG_CMD_READ, 2);
        // gpu_read_mem releases the chip select on its own to end the transaction
        local rdptr = ((rdpointerraw[1] << 8) + rdpointerraw[0]) & (FIFO_SIZE + 3);
        return rdptr;
        // Don't restart the "stream" here, because this is called from inside cp_getfree
        // cp_getfree will restart the stream when it sees the read pointer in the right place
    }
    
    /* Set the command write pointer and wait for the coprocessor to process all or
     * part of the coprocessor command FIFO. 
     */ 
    function cp_getfree(n) {
        // Wrap around at the command FIFO boundary
        cp_ptr = cp_ptr & 0xfff;
        // End the current SPI Transaction
        this.cs_l.write(1);
        // Set the write pointer register to the current position of the write pointer
        this.cs_l.write(0);
        gpu_write_mem16(REG_CMD_WRITE, cp_ptr);
        this.cs_l.write(1);
        // Wait for the coprocessor to process enough of the current buffer for 
        // us to have n bytes free for new commands.
        local fullness = 0;
        local timeout = 500000;
        local start = hardware.micros();
        do {
            // TO-DO: if coprocessor writes "0xFFF" to REG_CMD_READ, it has had a fault.
            // reset the coprocessor in this case. 
            fullness = (cp_ptr - cp_rdptr()) & (FIFO_SIZE - 1);
            freespace = FIFO_SIZE - fullness;
            if ((hardware.micros() - start) > timeout) {
                server.error("Timed out waiting for Coprocessor");
                return 1;
            }
        } while (freespace < n);
    }
    
    /* Write general commands to the coprocessor command FIFO.
     * This function assumes a SPI transaction is already initiated, see
     * cp_stream() to see how a transaction is initiated. 
     * 
     * This command ensures there's room in the command FIFO for the command, 
     * then copies the command into the FIFO. 
     * 
     * After a stream of commands is copied into the FIFO, call cp_getfree(4) to
     * set the command pointer and start the coprocessor working on the new command
     * stream. 
     * 
     * Coprocessor commands must be 4-byte aligned.
     */
    function cp_send_cmd(cmd) {
        if (freespace < 4) {
            cp_getfree(4);
            cp_stream();
        }
        local writeStr = format("%c%c%c%c",(cmd & 0xff),((cmd >> 8) & 0xff),
            ((cmd >> 16) & 0xff),((cmd >> 24) & 0xff));
        this.spi.write(writeStr);
        cp_ptr += 4;
        freespace -= 4;
    }

    /* Write a blob into the coprocessor command FIFO. 
     * This command assumes a SPI transaction has already been initiated with 
     * cp_stream().
     *
     * Note that coprocessor commands must be four-byte aligned.
     *
     * This method uses cp_getfree() to wrap around the beginning of the circular
     * command buffer, if necessary. 
     */
    function cp_send_blob(myblob) {
        //server.log(freespace+" bytes free in FIFO");
        if (freespace < myblob.len()) {
            cp_getfree(myblob.len());
            cp_stream();
        }
        this.spi.write(myblob);
        cp_ptr += myblob.len();
        freespace -= myblob.len();
    }
    
    /* Write a string into the coprocessor command FIFO.
     * This pads the string so that it is four-byte aligned (all coprocessor 
     * commands are four-byte aligned).
     */
    function cp_send_string(string) {
        // Coprocessor commands must be four-byte aligned.
        local padding = "";
        switch (string.len() % 4) {
            case 1:
                padding = "000";
                break;
            case 2:
                padding = "00";
                break;
            case 3:
                padding = "0";
                break;
        }
        // Make sure the coprocessor buffer has room in it for the string
        if (freespace < string.len()) {
            cp_getfree(string.len());
        }
        local rawStr = "";
        // Copy the string directly into the coprocessor command buffer
        foreach (char in (string + padding)) {
            rawStr += format("%c",char);
            cp_ptr += 1;
        }
        this.spi.write(rawStr);
    }

    /* Send CMD_TEXT to the coprocessor.
     * Input:
     *      x: x-coordinate of the text base in pixels (top-left corner of text by default)
     *      y: y-coordinate of the text base in pixels
     *      font: handle of preset font to use, integer 0-31
     *      options: OR together any of the following options:
     *          OPT_CENTERX: center text horizontally
     *          OPT_CENTERY: center text vertically
     *          OPT_CENTER: center text both vertically and horizontally
     *          OPT_RIGHTX: right-justify text (value of OPT_RIGHTX is 2048).
     *      string: 
     * Return: (None)
     */
    function cp_cmd_text(x, y, font, options, string) {
        cp_send_cmd(CMD_TEXT);
        cp_send_cmd(((y << 16) | (x & 0xffff)));
        cp_send_cmd(((options << 16) | font));
        cp_send_string(string + "\0");
    }
    
    /* Clear the screen to a specified RGB color through the coprocessor.
     * This command sets the default color of the screen when nothing is drawn on it,
     * then uses CMD_SWAP to redraw the screen on the next draw.
     * Input: 
     *      r: red value (0-255)
     *      g: green value (0-255)
     *      b: blue value (0-255)
     * Return: (None)
     */
    function cp_clear_to(r,g,b) {
        // Start a transaction with the coprocessor
        cp_stream();
        cp_send_cmd(clear_color_rgb(r,g,b));
        // clear the color, stencil, and tag buffers
        cp_send_cmd(clear_cst(1, 1, 1));
        cp_swap();
    }

    /* Set the bitmap handle
     * This allows us to perform graphics operations on this handle, treating it as a sprite
     * Input:
     *      handle (integer, 0 to 14)
     * Return: (None)
     */
    function cp_set_bmphandle(handle) {
        server.log(format("Setting current bitmap handle to %d",handle));
        cp_stream();
        cp_send_cmd(bitmaphandle(handle));
        // Don't flush the command buffer; leave the display list open so we can finish writing it.
        this.cs_l.write(1);
    }

    /* Decompress a JPEG image into RAM via the coprocessor and associate it with a bitmap handle.
     * The JPEG data is written straight into the command buffer as the coprocessor processes it.
     * The image can then be drawn to the screen by writing the associated bitmap handle into
     * a display list. 
     *
     * CMD_LOADIMAGE appends commands to display list memory by default to set the 
     * source, layout, and size of the resulting bitmap. OPT_NODL prevents this.
     * 
     * Input: 
     *      jpg_data: a binary blob of JPEG data, including the JPEG header.
     *      dest_offset: memory offset to unpack the image into.
     *          Set dest_offset to "-1" to tell the coprocessor to unload the image data 
     *          directly after the last image in RAM
     *      options: any of the following:
     *          OPT_RGB565: (default) loaded bitmap will be in RGB565 format
     *          OPT_MONO:   loaded bitmap will be in monochrome L8 format
     *          OPT_NODL:   prevent appending display list commands. Can be OR'd with
     *                      either of the above commands.
     * Return: (None)
     */
    function cp_load_jpg(jpg_data, dest_offset, handle, options = 0, posx = 0, posy = 0) {
        server.log(format("Unpacking %d bytes of JPEG data into 0x%02x with handle %d, at (%d,%d)",jpg_data.len(),dest_offset, handle, posx, posy));
        
        // begin writing into the CMD buffer
        cp_stream();
        cp_send_cmd(bitmaphandle(handle));
        cp_send_cmd(CMD_LOADIMAGE);
        cp_send_cmd(0);
        cp_send_cmd(options);
        /*copy JPEG data straight into the CMD buffer in chunks (4096 bytes of CMD memory)*/
        local BLOCKSIZE = 2048;
        for (local i = 0; i < jpg_data.len(); i += BLOCKSIZE) {
            // cp_send_blob automatically makes sure we have free space for the block
            cp_send_blob(jpg_data.readblob(BLOCKSIZE));
        }
        
        // This is a copy of cp_draw
        //cp_stream();
        //cp_send_cmd(CMD_DLSTART);
        /*
        cp_send_cmd(clear_color_rgb(255, 255, 255));
        cp_send_cmd(clear_cst(1,1,1));
        cp_send_cmd(begin(BITMAPS));
        cp_send_cmd(vertex2ii(posx,posy,handle,0));
        cp_send_cmd(CMD_SWAP);
        // flush the coprocessor command buffer and finish the transaction
        */
        server.log("Done unpacking JPEG.");
    }
    
    /* Use the coprocessor to draw a specified bitmap handle at a specified offset.
     * Requres that the source and layout of the bitmap have already been set in display list memory. 
     * Input:
     *      handle: bitmap handle (0 to 14)
     *      source: location of image in memory 
     *      offset_x: x-coordinate of the image base (top left corner)
     *      offset_y: y-coordinate of the image base
     * Return: (None)
     */
    function cp_draw(handle,offset_x,offset_y) {
        server.log(format("Drawing Handle %d at (%d,%d)",handle,offset_x,offset_y));
        cp_stream();
        cp_send_cmd(begin(BITMAPS));
        cp_send_cmd(vertex2ii(offset_x,offset_y,handle,0));
        cp_swap();
        server.log("Done drawing.");
    }

    function cp_text(string) {
        cp_stream();
        cp_send_cmd(clear_color_rgb(255, 255, 255));
        cp_send_cmd(clear_cst(1, 1, 1));
        cp_send_cmd(color_rgb(0x80, 0x80, 0x00));
        cp_cmd_text(FT_DispWidth/2, FT_DispHeight/2, 31, OPT_CENTERX, string);
    }
}

function disp_int_handler() {
    server.log("Display Interrupt Received!");
}

/* AGENT CALLBACKS -----------------------------------------------------------*/

agent.on("text", function(str) {
    server.log("Got text: "+str);
    display.demo_text(str);
    display.check_pointers();
});

agent.on("clear", function(req) {
    display.cp_clear_to(0,0,0);
});

agent.on("bmp", function(req) {
    server.log(format("Got BMP, %d bytes. Drawing at %d, %d",req.bmpdata.len(),req.xoffset,req.yoffset));
    display.gpu_load_bmp(req.bmpheader, req.bmpdata, req.xoffset, req.yoffset);
});

posX <- 0;
posY <- 0;
dest_offset <- 0;
handle <- 0;
options <- 0;

agent.on("jpg", function(req) {
    display.cp_load_jpg(req.jpgdata,dest_offset,handle,options,posX,posY);
    //display.cp_draw(handle,posX,posY);
    posX = math.rand() % 360;
    posY = math.rand() % 152;
    handle++;
    if (handle > 14) {
        handle = 0;
    }
    dest_offset = -1;
});

agent.on("draw", function(myhandle) {
    posX = math.rand() % 360;
    posY = math.rand() % 152;
    display.cp_draw(myhandle,posX,posY);
});

/* RUNTIME BEGINS HERE -------------------------------------------------------*/

cs_l_pin <- hardware.pin7;
cs_l_pin.configure(DIGITAL_OUT);
cs_l_pin.write(1);

pd_l_pin <- hardware.pin2;
pd_l_pin.configure(DIGITAL_OUT);
pd_l_pin.write(0);

int_pin <- hardware.pin5;
int_pin.configure(DIGITAL_IN, disp_int_handler);

// Configure SPI @ 4Mhz
spi <- hardware.spi189;
spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, 4000);

/* Beginning of execution */
display <- ft800(spi, cs_l_pin, pd_l_pin, int_pin);
display.power_down(function() {
    // initialize display
    server.log("Powered Down");
    
    display.power_up(function() {
        display.init();
        display.config();
        server.log("Powered Up");
        // clear display to white
        display.cp_clear_to(255,255,255);
        // Doing development on my desk with display upside-down.
        display.set_rotation(1);
        display.cp_start();
        display.cp_text("Ready.");
        display.cp_swap();
    });
});
