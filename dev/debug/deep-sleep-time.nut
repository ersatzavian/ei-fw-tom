/* Deep Sleep Timing Test */

// 24 hours = 86400
// docs state that max sleep time is 86395s
// docs DO NOT address the behavior if sleeptime > this max sleep time
const SLEEPTIME = 86400;
/*
    86396 seconds (1 day - 4)   -> imp goes to sleep and stays down
    86397 seconds (1 day - 3)   -> imp enters a boot loop. Time between logs is ~2s.
    86398 seconds (1 day - 2)   -> imp enters a boot loop. Time between logs is ~3s.
    86400 seconds (1 day)       -> imp enters a boot loop. Time between logs is ~5s.
*/

imp.configure("Deep Sleep Test",[],[]);

server.log("MAC: "+imp.getmacaddress());
server.log("SW: "+imp.getsoftwareversion());
server.log("Sleeping for "+SLEEPTIME+"s.");

imp.onidle( function() {
    server.sleepfor(SLEEPTIME);
});