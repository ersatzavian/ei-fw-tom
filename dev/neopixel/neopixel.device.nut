server.log(imp.getsoftwareversion());
imp.enableblinkup(true);

/* This class uses SPI to emulate the newpixels' one-wire protocol. 
 * This requires one byte per bit to send data at 7.5 MHz via SPI. 
 * These consts define the "waveform" to represent a zero or one */
const ZERO      = 0xC0;
const ONE       = 0xF8;
const SPICLK    = 7500; // kHz

// This is used for timing testing only
us <- hardware.micros.bindenv(hardware);

class neoPixels {
    spi = null;
    frameSize = null;
    frame = null;

    // _spi - A configured spi (MSB_FIRST, 7.5MHz)
    // _frameSize - Number of Pixels per frame
    constructor(_spi, _frameSize) {
        this.spi = _spi;
        this.frameSize = _frameSize;
        this.frame = blob(frameSize*8);
        
        clearFrame();
        writeFrame();
    }

    function writePixel(p,r,g,b) {
        local tick = us();
        frame.seek(p*24);
        
        /* This loop has been unrolled to optimize for speed.\
         * This allows writePixel to execute in approximately 1.2 ms
         * Re-rolling the loop causes writePixel to execute in closer to 2.3 ms.
         */
        frame.writen((g & 0x80) ? ONE:ZERO,'b');
        frame.writen((g & 0x40) ? ONE:ZERO,'b');
        frame.writen((g & 0x20) ? ONE:ZERO,'b');
        frame.writen((g & 0x10) ? ONE:ZERO,'b');
        frame.writen((g & 0x08) ? ONE:ZERO,'b');
        frame.writen((g & 0x04) ? ONE:ZERO,'b');
        frame.writen((g & 0x02) ? ONE:ZERO,'b');
        frame.writen((g & 0x01) ? ONE:ZERO,'b');
        
        frame.writen((r & 0x80) ? ONE:ZERO,'b');
        frame.writen((r & 0x40) ? ONE:ZERO,'b');
        frame.writen((r & 0x20) ? ONE:ZERO,'b');
        frame.writen((r & 0x10) ? ONE:ZERO,'b');
        frame.writen((r & 0x08) ? ONE:ZERO,'b');
        frame.writen((r & 0x04) ? ONE:ZERO,'b');
        frame.writen((r & 0x02) ? ONE:ZERO,'b');
        frame.writen((r & 0x01) ? ONE:ZERO,'b');
        
        frame.writen((b & 0x80) ? ONE:ZERO,'b');
        frame.writen((b & 0x40) ? ONE:ZERO,'b');
        frame.writen((b & 0x20) ? ONE:ZERO,'b');
        frame.writen((b & 0x10) ? ONE:ZERO,'b');
        frame.writen((b & 0x08) ? ONE:ZERO,'b');
        frame.writen((b & 0x04) ? ONE:ZERO,'b');
        frame.writen((b & 0x02) ? ONE:ZERO,'b');
        frame.writen((b & 0x01) ? ONE:ZERO,'b');
        
        local tock = us();
        //server.log(format("wrote pixel in %d us.",(tock-tick)));
    }
    
    function clearFrame() {
      for (local p = 0; p < frameSize; p++) writePixel(p,0,0,0);
      for (local i = 0; i < 40; i++) frame.writen(0x00,'c');
    }
    
    function writeFrame() {
        spi.write(frame);
    }
}

const NUMPIXELS = 64;
const DELAY = 0.025;

spi <- hardware.spi257;
spi.configure(MSB_FIRST, SPICLK);
pixelStrip <- neoPixels(spi, NUMPIXELS);

pixels <- [0,0,0,0,0]
currentPixel <- 0;
pAdd <- 1;

function test(d = null) { 
  pixelStrip.writePixel(pixels[0], 0, 0, 0);
  for(local i = 1; i < 5; i++) {
      local b = math.pow(2, i);
      pixelStrip.writePixel(pixels[i], b.tointeger(), (b/2).tointeger(), (b*1.5).tointeger());
  }
  
  pixelStrip.writeFrame();
  if (currentPixel >= NUMPIXELS-1) pAdd = -1;
  if (currentPixel <= 0) pAdd = 1;
  currentPixel += pAdd;
  
  for (local i = 0; i < 4; i++) pixels[i] = pixels[i+1];
  pixels[4] = currentPixel;
  
  imp.wakeup(DELAY, test);
} 

test();
