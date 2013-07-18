// Epaper Agent

server.log("Agent Running at "+http.agenturl());

function log(msg) {
	server.log("Agent: "+msg);
}

/* 
 * Input: WIF image data (blob)
 *
 * Return: image data (table)
 * 			.height: height in pixels
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
	log("Unpacking WIF Image, Height = "+retVal.height+" px, Width = "+retVal.width+" px");

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

	log("Done Unpacking WIF File.");

	return retVal;
}

/* HTTP EVENT HANDLERS ------------------------------------------------------*/

http.onrequest(function(request, res) {
    server.log("Agent got new HTTP Request");
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (request.path == "/WIFimage") {
    	// return right away to keep things responsive
    	res.send(200, "OK\n");

    	// incoming data has to be base64decoded so we can get a blob right away
    	local data = http.base64decode(request.body);
    	log("Got new data, len "+data.len());

    	// unpack the WIF image data
    	local imageData = unpackWIF(data);

    	// send the table containing dimensions and image data to the device
    	device.send("image", imageData);
    	log("New Image sent to device.");
    } else {
    	log("Agent got unknown request");
    	res.send(200, "OK\n");
    }
});
