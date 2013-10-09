/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/* 
 * Epaper Agent Firmware
 * Tom Byrne
 * tom@electricimp.com
 * 10/9/2013
 */

server.log("Agent Running at "+http.agenturl());

/*
 * Input: WIF image data (blob)
 *
 * Return: image data (table)
 *         	.height: height in pixels
 * 			.width:  width in pixels
 * 			.data:   image data (blob)
 */
function unpackWIF(packedData) {
	packedData.seek(0,'b');

	// length of actual data is the length of the blob minus the first four bytes (dimensions)
	local datalen = packedData.len() - 4;
	local retVal = {height = null, width = null, data = blob(datalen*2)};
	retVal.height = packedData.readn('w');
	retVal.width = packedData.readn('w');
	server.log("Unpacking WIF Image, Height = "+retVal.height+" px, Width = "+retVal.width+" px");

	/*
	 * Unpack WIF for RePaper Display
	 * each row is (width / 4) bytes (2 bits per pixel)
	 * first (width / 8) bytes are even pixels
	 * second (width / 8) bytes are odd pixels
	 * unpacked index must be incremented by (width / 8) every (width / 8) bytes to avoid overwriting the odd pixels.
	 *
	 * Display is drawn from top-right to bottom-left
	 *
	 * black pixel is 0b11
	 * white pixel is 0b10
	 * "don't care" is 0b00 or 0b01
	 * WIF does not support don't-care bits
	 *
	 */

	for (local row = 0; row < retVal.height; row++) {
		//for (local col = 0; col < (retVal.width / 8); col++) {
		for (local col = (retVal.width / 8) - 1; col >= 0; col--) {
			local packedByte = packedData.readn('b');
			local unpackedWordEven = 0x00;
			local unpackedWordOdd  = 0x00;

			for (local bit = 0; bit < 8; bit++) {
				// the display expects the data for each line to be interlaced; all even pixels, then all odd pixels
				if (!(bit % 2)) {
					// even pixels become odd pixels because the screen is drawn right to left
					if (packedByte & (0x01 << bit)) {
						unpackedWordOdd = unpackedWordOdd | (0x03 << (6-bit));
					} else {
						unpackedWordOdd = unpackedWordOdd | (0x02 << (6-bit));
					}
				} else {
					// odd pixel becomes even pixel
					if (packedByte & (0x01 << bit)) {
						unpackedWordEven = unpackedWordEven | (0x03 << bit - 1);
					} else {
						unpackedWordEven = unpackedWordEven | (0x02 << bit - 1);
					}
				}
			}

			retVal.data[(row * (retVal.width/4))+col] = unpackedWordEven;
			retVal.data[(row * (retVal.width/4))+(retVal.width/4) - col - 1] = unpackedWordOdd;
		} // end of col
	} // end of row

	server.log("Done Unpacking WIF File.");

	return retVal;
}

/* HTTP EVENT HANDLERS ------------------------------------------------------*/

http.onrequest(function(request, res) {
    server.log("Agent got new HTTP Request");
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (request.path == "/WIFimage" || request.path == "/WIFimage/") {
    	// return right away to keep things responsive
    	res.send(200, "OK\n");

    	// incoming data has to be base64decoded so we can get a blob right away
    	local data = http.base64decode(request.body);
    	server.log("Got new data, len "+data.len());

    	// unpack the WIF image data
    	local imageData = unpackWIF(data);

    	// send the table containing dimensions and image data to the device
    	device.send("image", imageData);
    	server.log("New Image sent to device.");
    } else if (request.path == "/clear" || request.path == "/clear/") {
    	res.send(200, "OK\n");

    	device.send("clear", 0);
    	server.log("Requesting Screen Clear.");
    } else {
    	server.log("Agent got unknown request");
    	res.send(200, "OK\n");
    }
});
