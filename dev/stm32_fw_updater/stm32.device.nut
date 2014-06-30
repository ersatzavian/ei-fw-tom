// STM32 microprocessor firmware updater
// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// GLOBALS AND CONSTS ----------------------------------------------------------

const BAUD = 9600;
BYTE_TIME <- 8.0 / (BAUD * 1.0);

// CLASS AND FUNCTION DEFS -----------------------------------------------------

function hexdump(data) {
    local i = 0;
    while (i < data.tell()) {
        local line = " ";
        for (local j = 0; j < 8; j++) {
            line += format("%02x ", data[i++]);
        }
        server.log(line);
    }
}

class Stm32 {
    static FLASH_START_ADDR = 0x08080000;
    static INIT_TIME        = 0.1; // ms, 85 ms min for V3.X
    static UART_CONN_TIME   = 0.010; // ms, two byte times plus configuration time
    static ACK_TIMEOUT      = 10000; // µs
    static INIT             = 0x7F;
    static ACK              = 0x79;
    static NACK             = 0x1F;
    static CMD_GET          = 0x00;
    static CMD_GET_VERSION_PROT_STATUS = 0x01;
    static CMD_GET_ID       = 0x02;
    static CMD_RD_MEMORY    = 0x11;
    static CMD_GO_MEMORY    = 0x21;
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
    
    uart = null;
    nrst = null;
    boot0 = null;
    boot1 = null;
    
    constructor(_uart, _nrst, _boot0, _boot1 = null) {
        uart = _uart;
        nrst = _nrst;
        boot0 = _boot0;
        if (_boot1) { boot1 = _boot1; }
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
        local timeout = (num_bytes * BYTE_TIME * 2 * 1000.0);
        local start = hardware.millis();
        while (result.tell() < num_bytes) {
            if (hardware.millis() - start > timeout) {
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
    // Input: None
    // Return: bool. True for ACK, False for NACK.
    function get_ack() {
        local byte = uart.read();
        local start = hardware.micros();
        while ((hardware.micros() - start) < ACK_TIMEOUT) {
            // server.log(format("Looking for ACK: %02x",byte));
            if (byte == ACK) { return true; }
            if (byte == NACK) { return false; }
            byte = uart.read();
        }
        throw "Timed out waiting for ACK";
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
    function cmd_go(addr) {
        clear_uart()
        uart.write(format("%c%c",CMD_GO, (~CMD_GO) & 0xff));
        get_ack();
        // GO command ACKs, then waits for starting address
        local addrblob = blob(5);
        addrblob.writen(addr,'i');
        addrblob.swap4(); // STM32 wants MSB-first. Imp is LSB-first.
        wr_checksum(addrblob);
        uart.write(addrblob);
    }
    
    // Write data to any valid memory address (RAM, Flash, Option Byte Area, etc.)
    // Note: to write to option byte area, address must be base address of this area
    // Maximum length of block to be written is 256 bytes
    // Input: 
    //      addr: 4-byte starting address
    //      data: data to write (0 to 256 bytes, blob)
    // Return: None
    function cmd_wr_mem(addr, data) {
        clear_uart();
        uart.write(format("%c%c",CMD_WR_MEMORY, (~CMD_WR_MEMORY) & 0xff));
        get_ack();
        // read mem command ACKs, then waits for starting memory address
        local addrblob = blob(5);
        addrblob.writen(addr,'i');
        addrblob.swap4(); // STM32 wants MSB-first. Imp is LSB-first.
        wr_checksum(addrblob);
        uart.write(addrblob);
        if (!get_ack()) {
            throw format("Got NACK on WR_MEMORY for addr %08x (invalid address)",addr);
        };
        // STM32 ACKs the address, then waits for the number of bytes to be written
        len = len & 0xff;
        local wrblob = blob(data.len() + 2);
        wrblob.writen(len,'b');
        wrblob.writeblob(data);
        wr_checksum(wrblob);
        uart.write(wrblob);
        if (!get_ack()) {
            throw format("Got NACK on WR_MEMORY for %d bytes starting at %08x (write protected)",len,addr);
        }
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
        if (!get_ack()) {
            throw "Flash Mass Erase Failed; received NACK";
        }
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
            throw "Flash Bank 1 Failed; received NACK";
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
            throw "Flash Bank 2 Failed; received NACK";
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
            throw "Flash Erase Failed; received NACK";
        }
    }
    
    // Disable write protection of all flash memory sectors
    // System reset is generated at end of command to apply the new configuration
    // Input: None
    // Return: None
    function wr_unprot(sectors, sector_codes) {
        clear_uart();
        uart.write(format("%c%c",CMD_WR_UNPROT, (~CMD_WR_UNPROT) & 0xff));
        get_ack();
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
        // second ACK acknowledges completion of write protect enable
        get_ack();
    }
    
}

// AGENT CALLBACKS -------------------------------------------------------------


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

// read back a bit of memory, to make sure that works
// RAM: 0x20002000 - 0x2001ffff (version 3.1)
// RAM: 0x20004000 - 0x2001ffff (version 9.1)
// SYSTEM Mem: 0x1fff0000 - 0x1fff77ff (all versions)
local addr = 0x20002000;
local len = 248;
local mem_contents = stm32.cmd_rd_mem(addr, len);
server.log(format("Got %d bytes of data starting at %02x ", mem_contents.len(), addr));
//hexdump(mem_contents);

imp.wakeup(1, function() {
    server.log("Resetting STM32");
    stm32.reset();
});