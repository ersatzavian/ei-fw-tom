
controllerID <- 0;

function BlobToHexString(data) {
  local str = "0x";
  foreach (b in data) str += format("%02x", b);
  return str;
}

device.on("controllerIDfromMAC", function(mac) {
    
    local rawhash = http.hash.md5(mac);
    server.log("imp MAC address: 0x"+mac);
    server.log("hashed MAC address: "+BlobToHexString(rawhash));
    
    for (local i = 2; i >= 0; i--) {
        controllerID += (rawhash[i] << (16 - (8 * i)));
    }
    
    server.log(format("Generated Controller ID: 0x%03x",controllerID));
    
    device.send("setControllerId",controllerID);
});