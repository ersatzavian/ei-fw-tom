
const DISPWIDTH     = 480;
const DISPHEIGHT    = 272;

// bitmap header parameters
const BI_BITFIELDS  = 3;
// FT800 bit mask codes
const ARGB1555      = 0;
const L1            = 1;
const L4            = 2;
const L8            = 3;
const RGB332        = 4;
const ARGB2         = 5;
const ARGB4         = 6;
const RGB565        = 7;
const PALETTED      = 8;

function sendBmp(bmpdata) {
    local bmpheader = {};
    
    // Read the BMP Header
    bmpheader.bmptype       <- format("%c%c",bmpdata.readn('b'),bmpdata.readn('b'));
    bmpheader.filesize      <- bmpdata.readn('i');
    bmpdata.seek(0x0A,'b');
    bmpheader.pxoffset      <- bmpdata.readn('i');
    
    
    // Read the DIB header, which (probably) immediately follows the BMP Header
    local headersize        =  bmpdata.readn('i');
    bmpheader.width         <- bmpdata.readn('i');
    bmpheader.height        <- bmpdata.readn('i');
    bmpheader.colorplanes   <- bmpdata.readn('w');
    bmpheader.bitsperpx     <- bmpdata.readn('w');
    bmpheader.compression   <- bmpdata.readn('i');
    bmpheader.imgsize       <- bmpdata.readn('i');
    if (bmpheader.imgsize == 0) {
        bmpheader.imgsize = ((bmpheader.width * bmpheader.height) * bmpheader.bitsperpx);
    }
    bmpheader.hres          <- bmpdata.readn('i');
    bmpheader.vres          <- bmpdata.readn('i');
    bmpheader.colors        <- bmpdata.readn('i');
    bmpheader.impcolors     <- bmpdata.readn('i');
    if (bmpheader.compression == BI_BITFIELDS) {
        bmpheader.rmask     <- bmpdata.readn('i');
        bmpheader.gmask     <- bmpdata.readn('i');
        bmpheader.bmask     <- bmpdata.readn('i');
        bmpheader.amask     <- bmpdata.readn('i');
        
        server.log(format("rmask: 0x%08x",bmpheader.rmask));
        server.log(format("gmask: 0x%08x",bmpheader.gmask));
        server.log(format("bmask: 0x%08x",bmpheader.bmask));
        server.log(format("amask: 0x%08x",bmpheader.amask));
    }
    
    server.log(format("Bits per px: %d",bmpheader.bitsperpx));
    
    
    // do a couple calcuations here (where it's faster) to simplify things for the device
    // Calculate the linestride (offset between scan lines)
    bmpheader.stride        <- 4 * ((bmpheader.width * (bmpheader.bitsperpx / 8) + 3) / 4);
    // determine the format code word for the FT800
    if (bmpheader.bitsperpx == 1) {
        bmpheader.format <- L1;   
    } else if (bmpheader.bitsperpx == 2) {
        // unsupported
        server.error("Two-byte-per-pixel encoding not supported.");
        return 1;
    } else if (bmpheader.bitsperpx == 4) {
        bmpheader.format <- L4;
    } else if (bmpheader.bitsperpx == 8) {
        if (bmpheader.compression == BI_BITFIELDS) {
            if (bmpheader.amask == 0) {
                bmpheader.format <- RGB332;
            } else {
                bmpheader.format <- ARGB2;
            }
        } else {
            bmpheader.format <- L8;
        }
    } else if (bmpheader.bitsperpx == 16) {
        if (bmpheader.compression == BI_BITFIELDS) {
            if (bmpheader.amask == 0x00) {
                bmpheader.format <- RGB565;
            } else if (bmpheader.amask == 0x8000) {
                bmpheader.format <- ARGB1555;
            } else {
                bmpheader.format <- ARGB4;
            }
        } else {
            bmpheader.format <- RGB565;
        }
    } else if (bmpheader.bitsperpx == 24) {
        server.error("Two-byte-per-pixel encoding not supported.");
        return 1;
    } else { // assume 32 bits per px
        bmpheader.format <- PALETTED;
    }
    
    server.log("header format code: "+bmpheader.format);
   
    // read the pixel field into a separate blob to make things simpler device-side
    bmpdata.seek(bmpheader.pxoffset,'b');
    local imgdata = bmpdata.readblob(bmpheader.imgsize);
    
    // tell the screen where to put the new image. Currently random.
    local xoffset = math.rand() % (DISPWIDTH - bmpheader.width);
    local yoffset = math.rand() % (DISPHEIGHT - bmpheader.height);

    // Send the parsed header and raw file
    device.send("bmp", {"bmpheader":bmpheader,"bmpdata":imgdata,"xoffset":xoffset,"yoffset":yoffset} );

    server.log(format("Parsed BMP, %d x %d px", bmpheader.width, bmpheader.height));
}

function sendJpg(jpgdata) {
    // pad jpg blob to make sure length is a multiple of 4 (FT800 requirement)
    local length = jpgdata.len()
    jpgdata.seek(0, 'e');
    for (local i = 0; i < (4 - (length % 4)); i++) {
        jpgdata.writen(0x00,'b');
    }
    
    // tell the screen where to put the new image.
//    local xoffset = math.rand() % (DISPWIDTH - 120);
//    local yoffset = math.rand() % (DISPHEIGHT - 120);
//    local xoffset = DISPWIDTH / 2;
//    local yoffset = DISPHEIGHT / 2;
    local xoffset = 0;
    local yoffset = 0;

    device.send("jpg", {"jpgdata":jpgdata,"xoffset":xoffset,"yoffset":yoffset});
}

http.onrequest(function(req, resp) {
    if (req.path == "/clear" || req.path == "/clear/") {
        device.send("clear",0);
    } else if (req.path == "/bmp" || req.path == "/bmp/") {
        sendBmp(http.base64decode(req.body));
        resp.send(200, "OK\n");
    } else if (req.path =="/jpg" || req.path == "/jpg/") {
        sendJpg(http.base64decode(req.body));
        resp.send(200, "OK\n");
    } else if (req.path == "/text" || req.path == "/text") {
        device.send("text",req.body);
        resp.send(200, "OK\n");
    } else {
        resp.send(200, "OK\n");
    }
});

server.log("Agent Started.");