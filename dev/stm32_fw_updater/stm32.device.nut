// STM32 microprocessor firmware updater
// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// GLOBALS AND CONSTS ----------------------------------------------------------

const BUFFERSIZE = 8192; // bytes per buffer of data sent from agent
const BAUD = 9600; // any standard baud between 9600 and 115200 is allowed
                    // exceeding 38400 is not recommended as the STM32 may overrun the imp's RX FIFO
BYTE_TIME <- 8.0 / (BAUD * 1.0);

// CLASS AND FUNCTION DEFS -----------------------------------------------------

function hexdump(data) {
    local i = 0;
    while (i < data.tell()) {
        local line = " ";
        for (local j = 0; j < 8 && i < data.tell(); j++) {
            line += format("%02x ", data[i++]);
        }
        server.log(line);
    }
}

class Stm32 {
    static FLASH_BASE_ADDR  = 0x08000000;
    static INIT_TIME        = 0.1; // ms, 85 ms min for V3.X
    static UART_CONN_TIME   = 0.010; // ms, two byte times plus configuration time
    static TIMEOUT          = 100000; // µs
    static FLASH_TIMEOUT    = 5000000; // µs; erases take a long time!
    static SYS_RESET_WAIT   = 0.2; // seconds to wait during system reset (some commands trigger this)
    static INIT             = 0x7F;
    static ACK              = 0x79;
    static NACK             = 0x1F;
    static CMD_GET          = 0x00;
    static CMD_GET_VERSION_PROT_STATUS = 0x01;
    static CMD_GET_ID       = 0x02;
    static CMD_RD_MEMORY    = 0x11;
    static CMD_GO           = 0x21;
    static CMD_WR_MEMORY    = 0x31;
    static CMD_ERASE        = 0x43; // ERASE and EXT_ERASE are exclusive; only one is supported
    static CMD_EXT_ERASE    = 0x44;
    static CMD_WR_PROT      = 0x63;
    static CMD_WR_UNPROT    = 0x73;
    static CMD_RDOUT_PROT   = 0x82;
    static CMD_RDOUT_UNPROT = 0x92;
    
    bootloader_version = null;
    supported_cmds = [];
    pid = null;
    flash_ptr = 0;
    
    uart = null;
    nrst = null;
    boot0 = null;
    boot1 = null;
    
    constructor(_uart, _nrst, _boot0, _boot1 = null) {
        uart = _uart;
        nrst = _nrst;
        boot0 = _boot0;
        if (_boot1) { boot1 = _boot1; }
        flash_ptr = FLASH_BASE_ADDR;
    }
    
    // Helper function: clear the UART RX FIFO by reading out any remaining data
    // Input: None
    // Return: None
    function clear_uart() {
        local byte = uart.read();
        while (byte != -1) {
            byte = uart.read();
        }
    }
    
    // Helper function: block and read a set number of bytes from the UART
    // Times out if the UART doesn't receive the required number of bytes in 2 * BYTE TIME
    // Helpful primarily when reading more than the UART RX FIFO can hold (80 bytes)
    // Input: num_bytes (integer)
    // Return: RX'd data (blob)
    function read_uart(num_bytes) {
        local result = blob(num_bytes);
        local start = hardware.micros();
        while (result.tell() < num_bytes) {
            if (hardware.micros() - start > TIMEOUT) {
                throw format("Timed out waiting for data, got %d / %d bytes",result.tell(),num_bytes);
            }
            local byte = uart.read();
            if (byte != -1) {
                result.writen(byte,'b');
            }
        }
        return result;
    }
    
    // Helper function: compute the checksum for a blob and write the checksum to the end of the blob
    // Note that STM32 checksum is really just a parity byte
    // Input: data (blob)
    //      Blob pointer should be at the end of the data to checksum
    // Return: data (blob), with checksum written to end
    function wr_checksum(data) {
        local checksum = 0;
        for (local i = 0; i < data.tell(); i++) {
            //server.log(format("%02x",data[i]));
            checksum = (checksum ^ data[i]) & 0xff;
        }
        data.writen(checksum, 'b');
    }
    
    // Helper function: send a UART bootloader command
    // Not all commands can use this helper, as some require multiple steps
    // Sends command, gets ACK, and receives number of bytes indicated by STM32
    // Input: cmd - USART bootloader command (defined above)
    // Return: response (blob) - results of sending command
    function send_cmd(cmd) {
        clear_uart();
        local checksum = (~cmd) & 0xff;
        uart.write(format("%c%c",cmd,checksum));
        
        get_ack();
        imp.sleep(BYTE_TIME * 2);
        local num_bytes = uart.read() + 0;
        if (cmd == CMD_GET_ID) {num_bytes++;} // GET_ID command responds w/ number of bytes in ID - 1.
        server.log(format("%02x: Receiving %d bytes", cmd, num_bytes));
        imp.sleep(BYTE_TIME * (num_bytes + 4));
        
        local result = blob(num_bytes);
        for (local i = 0; i < num_bytes; i++) {
            result.writen(uart.read(),'b');
        }
        
        result.seek(0,'b');
        return result;
    }
    
    // Helper function: wait for an ACK from STM32 when sending a command
    // Implements a timeout and blocks until ACK is received or timeout is reached
    // Input: [optional] timeout in µs
    // Return: bool. True for ACK, False for NACK.
    function get_ack() {
        local byte = uart.read();
        local start = hardware.micros();
        while ((hardware.micros() - start) < FLASH_TIMEOUT) {
            // server.log(format("Looking for ACK: %02x",byte));
            if (byte == ACK) { return true; }
            if (byte == NACK) { return false; }
            if (byte != -1) { server.log(format("%02x",byte)); }
            byte = uart.read();
        }
        throw "Timed out waiting for ACK";
    }
    
    // set the class's internal pointer for the current address in flash
    // this allows functions outside the class to start at 0 and ignore the flash base address
    // Input: relative position of flash memory pointer (integer)
    // Return: None
    function set_flash_ptr(addr) {
        flash_ptr = addr + FLASH_BASE_ADDR;
    }
    
    // get the relative position of the current address in flash
    // Input: None
    // Return: relative position of flash memory pointer (integer)
    function get_flash_ptr() {
        return flash_ptr - FLASH_BASE_ADDR;
    }
    
    // get the base address of flash memory
    // Input: None
    // Return: flash base address (integer)
    function get_flash_base_addr() {
        return FLASH_BASE_ADDR;
    }
    
    // Reset the STM32 to bring it out of USART bootloader
    // Releases the boot0 pin, then toggles reset
    // Input: None
    // Return: None
    function reset() {
        nrst.write(0);
        // release boot0 so we don't come back up in USART bootloader mode
        boot0.write(0);
        imp.sleep(0.010);
        nrst.write(1);
    }
    
    // Reset the STM32 and bring it up in USART bootloader mode
    // Applies "pattern1" from "STM32 system memory boot mode” application note (AN2606)
    // Note that the USARTs available for bootloader vary between STM32 parts
    // Input: None
    // Return: None
    function enter_bootloader() {
        // hold boot0 high, boot1 low, and toggle reset
        nrst.write(0);
        boot0.write(1);
        if (boot1) { boot1.write(0); }
        nrst.write(1);
        // bootloader will take a little time to come up
        imp.sleep(INIT_TIME);
        // release boot0 so we don't wind up back in the bootloader on our next reset
        boot0.write(0);
        // send a command to initialize the bootloader on this UART
        clear_uart();
        uart.write(INIT);
        imp.sleep(UART_CONN_TIME);
        local response = uart.read() + 0;
        if (response == ACK) {
            // USART bootloader successfully configured
            return;
        } else {
            throw "Failed to configure USART Bootloader, got "+response;
        }
    }
    
    // Send the GET command to the STM32
    // Gets the bootloader version and a list of supported commands
    // The imp will store the results of this command to save time if asked again later
    // Input: None
    // Return: Result (table)
    //      bootloader_version (byte)
    //      supported_cmds (array)
    function cmd_get() {
        // only request info from the device if we don't already have it
        if (bootloader_version == null || supported_cmds.len() == 0) {
            local result = send_cmd(CMD_GET);
            bootloader_version = result.readn('b');
            while (!result.eos()) {
                local byte  = result.readn('b');
                supported_cmds.push(byte);
            }
        } 
        return {bootloader_version = bootloader_version, supported_cmds = supported_cmds};
    }
    
    // Send the GET ID command to the STM32
    // Gets the chip ID from the device
    // The imp will store the results of this command to save time if asked again later
    // Input: None
    // Return: pid (2 bytes)
    function cmd_get_id() {
        if (pid == null) {
            local result = send_cmd(CMD_GET_ID);
            pid = result.readn('w');
        }
        return format("%04x",pid);
    }
    
    // Read a section of device memory
    // Input: 
    //      addr: 4-byte address. Refer to “STM32 microcontroller system memory boot mode” application note (AN2606) for valid addresses
    //      len: number of bytes to read. 0-255.
    // Return: 
    //      memory contents from addr to addr+len (blob)
    function cmd_rd_mem(addr, len) {
        clear_uart();
        uart.write(format("%c%c",CMD_RD_MEMORY, (~CMD_RD_MEMORY) & 0xff));
        get_ack();
        // read mem command ACKs, then waits for starting memory address
        local addrblob = blob(5);
        addrblob.writen(addr,'i');
        addrblob.swap4(); // STM32 wants MSB-first. Imp is LSB-first.
        wr_checksum(addrblob);
        uart.write(addrblob);
        if (!get_ack()) {
            throw format("Got NACK on RD_MEMORY for addr %08x (invalid address)",addr);
        };
        // STM32 ACKs the address, then waits for the number of bytes to read
        len = len & 0xff;
        uart.write(format("%c%c",len, (~len) & 0xff));
        if (!get_ack()) {
            throw format("Got NACK on RD_MEMORY for %d bytes starting at %08x (read protected)",len,addr);
        }
        // blocking read the memory contents
        local result = read_uart(len);
        return result;
    }
    
    // Execute downloaded or other code by branching to a specified address
    // When the address is valid and the command is executed: 
    // - registers of all peripherals used by bootloader are reset to default values
    // - user application's main stack pointer is initialized
    // - STM32 jumps to memory location specified + 4
    // Host should send base address where the application to jump to is programmed
    // Jump to application only works if the user application sets the vector table correctly to point to application addr
    // Input: 
    //      addr: 4-byte address
    // Return: None
    function cmd_go(addr = null) {
        clear_uart()
        uart.write(format("%c%c",CMD_GO, (~CMD_GO) & 0xff));
        get_ack();
        // GO command ACKs, then waits for starting address
        // if no address was given, assume image starts at the beginning of the flash
        if (addr == null) { addr = FLASH_BASE_ADDR; }
        local addrblob = blob(5);
        addrblob.writen(addr,'i');
        addrblob.swap4(); // STM32 wants MSB-first. Imp is LSB-first.
        wr_checksum(addrblob);
        uart.write(addrblob);        
        if (!get_ack()) {
            throw format("Got NACK on WR_MEMORY for addr %08x (invalid address)",addr);
        };
    }
    
    // Write data to any valid memory address (RAM, Flash, Option Byte Area, etc.)
    // Note: to write to option byte area, address must be base address of this area
    // Maximum length of block to be written is 256 bytes
    // Input: 
    //      addr: 4-byte starting address
    //      data: data to write (0 to 256 bytes, blob)
    // Return: None
    function cmd_wr_mem(data, addr = null) {
        local len = data.len();
        clear_uart();
        uart.write(format("%c%c",CMD_WR_MEMORY, (~CMD_WR_MEMORY) & 0xff));
        get_ack();
        //server.log("Write Command OK.");
        
        // read mem command ACKs, then waits for starting memory address
        local addrblob = blob(5);
        if (addr == null) { addr = flash_ptr; }
        addrblob.writen(addr,'i');
        addrblob.swap4(); // STM32 wants MSB-first. Imp is LSB-first.
        wr_checksum(addrblob);
        uart.write(addrblob);
        if (!get_ack()) {
            throw format("Got NACK on WR_MEMORY for addr %08x (invalid address)",addr);
        };
        //server.log("Write Address OK.");
        
        // STM32 ACKs the address, then waits for the number of bytes to be written
        local wrblob = blob(data.len() + 2);
        wrblob.writen(len - 1,'b');
        wrblob.writeblob(data);
        wr_checksum(wrblob);
        //server.log(wrblob.tell());
        //hexdump(wrblob);
        uart.write(wrblob);
        
        //server.log("Data sent, waiting for write to finish.");
        
        local byte = uart.read();
        local start = hardware.millis();
        while ((hardware.millis() - start) < 60000) {
            if (byte == ACK) { 
                //server.log("Write complete, ACKed");
                flash_ptr += len;
                return;
            }
            if (byte == NACK) { 
                server.log("Write error, NACKed");
                break;
            }
            byte = uart.read();
        }
        throw "Write Timed Out."
    }
    
    // Erase flash memory pages
    // Note that either ERASE or EXT_ERASE are supported, but not both
    // The STM32F407VG does not support ERASE
    // Input:
    //      num_pages (1-byte integer) number of pages to erase
    //      page_codes (array)
    // Return: None
    function erase_mem(num_pages, page_codes) {
        clear_uart();
        uart.write(format("%c%c",CMD_ERASE, (~CMD_ERASE) & 0xff));
        get_ack();
        local erblob = blob(page_codes.len() + 2);
        erblob.writen(num_pages & 0xff, 'b');
        foreach (page in page_codes) {
            erblob.writen(page & 0xff, 'b');
        }
        wr_checksum(erblob);
        uart.write(wrblob);
        if (!get_ack()) {
            throw "Flash Erase Failed; received NACK";
        }
    }
    
    // Erase all flash memory
    // Note that either ERASE or EXT_ERASE are supported, but not both
    // The STM32F407VG does not support ERASE
    // Input: None
    // Return: None
    function erase_global_mem() {
        clear_uart();
        uart.write(format("%c%c",CMD_ERASE, (~CMD_ERASE) & 0xff));
        get_ack();
        uart.write("\xff\x00");
        if (!get_ack()) {
            throw "Flash Erase Failed; received NACK";
        }
    }
    
    // Erase flash memory pages using two byte addressing
    // Note that either ERASE or EXT_ERASE are supported, but not both
    // The STM32F407VG does not support ERASE
    // Input: 
    //      num_pages (2-byte integer) number of pages to erase
    //      page_codes (array of 2-byte codes)
    // Return: None
    function ext_erase_mem(addr, len) {
        clear_uart();
        uart.write(format("%c%c",CMD_EXT_ERASE, (~CMD_EXT_ERASE) & 0xff));
        get_ack();
        // 2 bytes for num_pages, 2 bytes per page code, 1 byte for checksum
        local erblob = blob(2 * page_codes.len() + 3);
        erblob.writen(num_pages & 0xff00 >> 8, 'b');
        erblob.writen(num_pages * 0xff, 'b');
        foreach (page in page_codes) {
            erblob.writen(page & 0xff00 >> 8, 'b');
            erblob.writen(page * 0xff, 'b');
        }
        wr_checksum(erblob);
        uart.write(wrblob);
        if (!get_ack()) {
            throw "Flash Extended Erase Failed; received NACK";
        }
    }
    
    // Erase all flash memory for devices that support EXT_ERASE
    // Input: None
    // Return: None
    function mass_erase() {
        clear_uart();
        uart.write(format("%c%c",CMD_EXT_ERASE, (~CMD_EXT_ERASE) & 0xff));
        get_ack();
        uart.write("\xff\xff\x00");
        local byte = uart.read();
        local start = hardware.millis();
        while ((hardware.millis() - start) < 60000) {
            if (byte == ACK) { 
                server.log("Mass Erase complete, ACKed");
                flash_ptr = FLASH_BASE_ADDR;
                return;
            }
            if (byte == NACK) { 
                server.log("Mass Erase error, NACKed");
                break;
            }
            byte = uart.read();
        }
        server.log("Mass Erase Timed Out. Resetting.");
    }
    
    // Erase bank 1 flash memory for devices that support EXT_ERASE
    // Input: None
    // Return: None
    function bank1_erase() {
        clear_uart();
        uart.write(format("%c%c",CMD_EXT_ERASE, (~CMD_EXT_ERASE) & 0xff));
        get_ack();
        uart.write("\xff\xfe\x01");
        if (!get_ack()) {
            throw "Flash Bank 1 Erase Failed; received NACK";
        }
    }
    
    // Erase bank 2 flash memory for devices that support EXT_ERASE
    // Input: None
    // Return: None    
    function bank2_erase() {
        clear_uart();
        uart.write(format("%c%c",CMD_EXT_ERASE, (~CMD_EXT_ERASE) & 0xff));
        get_ack();
        uart.write("\xff\xfd\x02");
        if (!get_ack()) {
            throw "Flash Bank 2 Erase Failed; received NACK";
        }
    }
    
    // Enable write protection for some or all flash memory sectors
    // System reset is generated at end of command to apply the new configuration
    // Input: 
    //      num_sectors: (1-byte integer) number of sectors to protect
    //      sector_codes: (1-byte integer array) sector codes of sectors to protect
    // Return: None
    function wr_prot(num_sectors, sector_codes) {
        clear_uart();
        uart.write(format("%c%c",CMD_WR_PROT, (~CMD_WR_PROT) & 0xff));
        get_ack();
        local protblob = blob(sector_codes.len() + 2);
        protblob.writen(num_sectors & 0xff, 'b');
        foreach (sector in sector_codes) {
            protblob.writen(sector & 0xff, 'b');
        }
        wr_checksum(protblob);
        uart.write(protblob);
        if (!get_ack()) {
            throw "Write Protect Failed; received NACK";
        }
    }
    
    // Disable write protection of all flash memory sectors
    // System reset is generated at end of command to apply the new configuration
    // Input: None
    // Return: None
    function wr_unprot() {
        clear_uart();
        uart.write(format("%c%c",CMD_WR_UNPROT, (~CMD_WR_UNPROT) & 0xff));
        // first ACK acknowledges command
        get_ack();
        local byte = uart.read();
        local start = hardware.millis();
        while ((hardware.millis() - start) < 5000) {
            if (byte == ACK) { 
                server.log("CMD_WR_UNPROT complete (ACK)");
                return;
            }
            if (byte == NACK) { 
                server.log("CMD_WR_UNPROT error (NACK)");
                break;
            }
            byte = uart.read();
        }
        server.log("CMD_WR_UNPROT Timed Out. Resetting.");
        // second ACK acknowledges completion of write protect enable
        //get_ack();
        // system will now reset
        imp.sleep(SYS_RESET_WAIT);
        enter_bootloader();
        server.log("STM32 Reset Complete, re-entered bootloader");
    }
    
    // Enable flash memory read protection
    // System reset is generated at end of command to apply the new configuration
    // Input: None
    // Return: None
    function rd_prot() {
        clear_uart();
        uart.write(format("%c%c",CMD_RDOUT_PROT, (~CMD_RDOUT_PROT) & 0xff));
        // first ACK acknowledges command
        get_ack();
        // second ACK acknowledges completion of write protect enable
        get_ack();
        // system will now reset
        imp.sleep(SYS_RESET_WAIT);
        enter_bootloader();
    }
    
    // Disable flash memory read protection
    // System reset is generated at end of command to apply the new configuration
    // Input: None
    // Return: None
    function rd_unprot() {
        clear_uart();
        uart.write(format("%c%c",CMD_RDOUT_UNPROT, (~CMD_RDOUT_UNPROT) & 0xff));
        // first ACK acknowledges command
        get_ack();
        imp.sleep(5);
        // second ACK acknowledges completion of write protect enable
        get_ack();
        // system will now reset
        imp.sleep(SYS_RESET_WAIT);
        enter_bootloader();
    }
    
}

// AGENT CALLBACKS -------------------------------------------------------------

// Allow the agent to put the stm32 in bootloader mode
agent.on("bootloader", function(dummy) {
    stm32.enter_bootloader();
});

// Allow the agent to reset the stm32 to normal operation
agent.on("reset", function(dummy) {
    stm32.reset();
});

fw_len <- null;
// Initiate an application firmware update
agent.on("load_fw", function(len) {
    fw_len = len;
    server.log(format("FW Update: %d bytes",fw_len));
    stm32.enter_bootloader();
    server.log("FW Update: Enabling Flash Write");
    stm32.wr_unprot();
    // wr_unprotect causes a system reset, so we need to re-enter the bootloader
    stm32.enter_bootloader();
    server.log("FW Update: Mass Erasing Flash");
    stm32.mass_erase();
    server.log("FW Update: Starting Download");
    local num_bytes = BUFFERSIZE;
    if (fw_len < BUFFERSIZE) { num_bytes = fw_len; }
    agent.send("pull", num_bytes);
});

// used to load new application firmware; device sends a block of data to the stm32,
// then requests another block from the agent with "pull". Agent responds with "push".
agent.on("push", function(buffer) {
    buffer.seek(0,'b');
    local data = blob(256);
    while (!buffer.eos()) {
        local bytes_left_this_buffer = buffer.len() - buffer.tell()
        server.log(format("%d bytes left in current buffer. Flash pointer at %d",bytes_left_this_buffer,stm32.get_flash_ptr()));
        if (bytes_left_this_buffer > 256) { data = buffer.readblob(256); }
        else { data = buffer.readblob(bytes_left_this_buffer); }
        stm32.cmd_wr_mem(data);
    }
    
    local bytes_left_total = fw_len - stm32.get_flash_ptr();
    local next_buffer_size = bytes_left_total > BUFFERSIZE ? BUFFERSIZE : bytes_left_total;
    server.log(format("%d total bytes remaining, next buffer %d bytes",bytes_left_total,next_buffer_size));
    imp.sleep(0.5)
    
    if (next_buffer_size == 0) {
        server.log("FW Update: Complete, Resetting");
        fw_len = 0;
        stm32.cmd_go();
        //stm32.reset();
        agent.send("fw_update_complete", true);
    } else {
        agent.send("pull", next_buffer_size);
        server.log(format("FW Update: loaded %d / %d",stm32.get_flash_ptr(),fw_len));
    }
});


// MAIN ------------------------------------------------------------------------

nrst <- hardware.pin8;
boot0 <- hardware.pin9;
uart <- hardware.uart57;

nrst.configure(DIGITAL_OUT);
nrst.write(1);
boot0.configure(DIGITAL_OUT);
boot0.write(1);
uart.configure(BAUD, 8, PARITY_EVEN, 1, NO_CTSRTS);

stm32 <- Stm32(uart, nrst, boot0);

/*
local myblob = blob(5);
myblob.writen(0x06,'b');
myblob.writen(0x04,'b');
myblob.writen(0x01,'b');
myblob.writen(0x01,'b');
stm32.wr_checksum(myblob);
*/

// reset the STM32 and bring it up in bootloader mode
stm32.enter_bootloader();
server.log("STM32 in USART Bootloader Mode");

// use the GET command to get the bootloader version and list of supported commands
local bootloader_info = stm32.cmd_get();
server.log(format("STM32 Bootloader Version: %02x",bootloader_info.bootloader_version));
local supported_cmds_str = ""; 
foreach (cmd in bootloader_info.supported_cmds) {
    supported_cmds_str += format("%02x ",cmd);
}
server.log("Bootloader supports commands: " + supported_cmds_str);

// use the GET_ID command to get the PID
server.log("STM32 PID: "+stm32.cmd_get_id());

//server.log("Disabling Readback Protection");
//stm32.rd_unprot()
//server.log("Readback Protection Disabled");

// read back a bit of memory, to make sure that works
// RAM: 0x20002000 - 0x2001ffff (version 3.1)
// RAM: 0x20004000 - 0x2001ffff (version 9.1)
// SYSTEM Mem: 0x1fff0000 - 0x1fff77ff (all versions)
// Here, we read the option byte section. Bytes 15:0 show write protection
//local addr = 0x1FFFC008;
/*
local addr = 0x08000000
local len = 64;
local mem_contents = stm32.cmd_rd_mem(addr, len);
server.log(format("Got %d bytes of data starting at %02x ", mem_contents.len(), addr));
hexdump(mem_contents);

// test write unprotect
stm32.wr_unprot();

// test write
local testblob = blob(16);
while (!testblob.eos()) {
    testblob.writen(0xAACC, 'w');
}
testblob.seek(0,'b');
server.log("Testing Write by writing 16 bytes of 0xAACC to 0x0800 0000");
stm32.cmd_wr_mem(testblob, addr);
server.log("Write Complete, reading back to verify.");

// verify write
mem_contents = stm32.cmd_rd_mem(addr, len);
server.log(format("Got %d bytes of data starting at %08x ", mem_contents.len(), addr));
hexdump(mem_contents);
*/

imp.wakeup(1, function() {
    stm32.reset();
    server.log("STM32 Reset");
});