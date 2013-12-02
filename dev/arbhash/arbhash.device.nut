
imp.configure("mac hash test",[],[]);

controllerID <- 0;

function generateControllerID() {
    agent.send("controllerIDfromMAC",imp.getmacaddress());
}

agent.on("setControllerId",function(id) {
    controllerID = id;
    server.log(format("Controller ID set to 0x%03x",controllerID));
});

generateControllerID();