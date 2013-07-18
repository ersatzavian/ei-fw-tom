/* Expectonlinein test */

imp.configure("Expectonlinein Test",[],[]);

server.log("Up!");

// This works right.
//imp.onidle( function() {server.sleepfor(2);});

// This doesn't work right.
server.expectonlinein(10);
imp.onidle( function() {imp.deepsleepfor(2);});