// Battery powered motion sensor
server.log("PIR booted");

imp.setpowersave(true);

local out1 = OutputPort("Motion detector");
imp.configure("Motion sensor", [], [out1]);

function motion() {
  local s = hardware.pin1.read();
  out1.set(s);
  server.show(s?"motion":"");
}

hardware.pin1.configure(DIGITAL_IN_PULLUP, motion);
motion();
