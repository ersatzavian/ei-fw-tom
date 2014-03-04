/*
Copyright (C) 2014 electric imp, inc.

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

/* WS2812 "Neopixel" LED Driver
 * 
 * Uses SPI to emulate 1-wire
 * http://learn.adafruit.com/adafruit-neopixel-uberguide/advanced-coding
 *
 */
 
/* CONSTS AND GLOBALS --------------------------------------------------------*/

// constants for using SPI to emulate 1-wire
const BYTESPERPIXEL = 27;
const BYTESPERCOLOR = 9; // BYTESPERPIXEL / 3
const SPICLK = 7500; // SPI clock speed in kHz

// this string contains the "equivalent waveform" to send the numbers 0-255 over SPI at 7.5MHz.
// 9 bytes of string are required to send 1 byte of emulated 1-wire data. 
// For example, to add a byte containing the number "14" to the frame:
// bits.slice(14 * 9, (14 * 9) + 9);
bits <- ["\xE0\x70\x38\x1C\x0E\x07\x03\x81\xC0",
                "\xE0\x70\x38\x1C\x0E\x07\x03\x81\xF8",
                "\xE0\x70\x38\x1C\x0E\x07\x03\xF1\xC0",
                "\xE0\x70\x38\x1C\x0E\x07\x03\xF1\xF8",
                "\xE0\x70\x38\x1C\x0E\x07\xE3\x81\xC0",
                "\xE0\x70\x38\x1C\x0E\x07\xE3\x81\xF8",
                "\xE0\x70\x38\x1C\x0E\x07\xE3\xF1\xC0",
                "\xE0\x70\x38\x1C\x0E\x07\xE3\xF1\xF8",
                "\xE0\x70\x38\x1C\x0F\xC7\x03\x81\xC0",
                "\xE0\x70\x38\x1C\x0F\xC7\x03\x81\xF8",
                "\xE0\x70\x38\x1C\x0F\xC7\x03\xF1\xC0",
                "\xE0\x70\x38\x1C\x0F\xC7\x03\xF1\xF8",
                "\xE0\x70\x38\x1C\x0F\xC7\xE3\x81\xC0",
                "\xE0\x70\x38\x1C\x0F\xC7\xE3\x81\xF8",
                "\xE0\x70\x38\x1C\x0F\xC7\xE3\xF1\xC0",
                "\xE0\x70\x38\x1C\x0F\xC7\xE3\xF1\xF8",
                "\xE0\x70\x38\x1F\x8E\x07\x03\x81\xC0",
                "\xE0\x70\x38\x1F\x8E\x07\x03\x81\xF8",
                "\xE0\x70\x38\x1F\x8E\x07\x03\xF1\xC0",
                "\xE0\x70\x38\x1F\x8E\x07\x03\xF1\xF8",
                "\xE0\x70\x38\x1F\x8E\x07\xE3\x81\xC0",
                "\xE0\x70\x38\x1F\x8E\x07\xE3\x81\xF8",
                "\xE0\x70\x38\x1F\x8E\x07\xE3\xF1\xC0",
                "\xE0\x70\x38\x1F\x8E\x07\xE3\xF1\xF8",
                "\xE0\x70\x38\x1F\x8F\xC7\x03\x81\xC0",
                "\xE0\x70\x38\x1F\x8F\xC7\x03\x81\xF8",
                "\xE0\x70\x38\x1F\x8F\xC7\x03\xF1\xC0",
                "\xE0\x70\x38\x1F\x8F\xC7\x03\xF1\xF8",
                "\xE0\x70\x38\x1F\x8F\xC7\xE3\x81\xC0",
                "\xE0\x70\x38\x1F\x8F\xC7\xE3\x81\xF8",
                "\xE0\x70\x38\x1F\x8F\xC7\xE3\xF1\xC0",
                "\xE0\x70\x38\x1F\x8F\xC7\xE3\xF1\xF8",
                "\xE0\x70\x3F\x1C\x0E\x07\x03\x81\xC0",
                "\xE0\x70\x3F\x1C\x0E\x07\x03\x81\xF8",
                "\xE0\x70\x3F\x1C\x0E\x07\x03\xF1\xC0",
                "\xE0\x70\x3F\x1C\x0E\x07\x03\xF1\xF8",
                "\xE0\x70\x3F\x1C\x0E\x07\xE3\x81\xC0",
                "\xE0\x70\x3F\x1C\x0E\x07\xE3\x81\xF8",
                "\xE0\x70\x3F\x1C\x0E\x07\xE3\xF1\xC0",
                "\xE0\x70\x3F\x1C\x0E\x07\xE3\xF1\xF8",
                "\xE0\x70\x3F\x1C\x0F\xC7\x03\x81\xC0",
                "\xE0\x70\x3F\x1C\x0F\xC7\x03\x81\xF8",
                "\xE0\x70\x3F\x1C\x0F\xC7\x03\xF1\xC0",
                "\xE0\x70\x3F\x1C\x0F\xC7\x03\xF1\xF8",
                "\xE0\x70\x3F\x1C\x0F\xC7\xE3\x81\xC0",
                "\xE0\x70\x3F\x1C\x0F\xC7\xE3\x81\xF8",
                "\xE0\x70\x3F\x1C\x0F\xC7\xE3\xF1\xC0",
                "\xE0\x70\x3F\x1C\x0F\xC7\xE3\xF1\xF8",
                "\xE0\x70\x3F\x1F\x8E\x07\x03\x81\xC0",
                "\xE0\x70\x3F\x1F\x8E\x07\x03\x81\xF8",
                "\xE0\x70\x3F\x1F\x8E\x07\x03\xF1\xC0",
                "\xE0\x70\x3F\x1F\x8E\x07\x03\xF1\xF8",
                "\xE0\x70\x3F\x1F\x8E\x07\xE3\x81\xC0",
                "\xE0\x70\x3F\x1F\x8E\x07\xE3\x81\xF8",
                "\xE0\x70\x3F\x1F\x8E\x07\xE3\xF1\xC0",
                "\xE0\x70\x3F\x1F\x8E\x07\xE3\xF1\xF8",
                "\xE0\x70\x3F\x1F\x8F\xC7\x03\x81\xC0",
                "\xE0\x70\x3F\x1F\x8F\xC7\x03\x81\xF8",
                "\xE0\x70\x3F\x1F\x8F\xC7\x03\xF1\xC0",
                "\xE0\x70\x3F\x1F\x8F\xC7\x03\xF1\xF8",
                "\xE0\x70\x3F\x1F\x8F\xC7\xE3\x81\xC0",
                "\xE0\x70\x3F\x1F\x8F\xC7\xE3\x81\xF8",
                "\xE0\x70\x3F\x1F\x8F\xC7\xE3\xF1\xC0",
                "\xE0\x70\x3F\x1F\x8F\xC7\xE3\xF1\xF8",
                "\xE0\x7E\x38\x1C\x0E\x07\x03\x81\xC0",
                "\xE0\x7E\x38\x1C\x0E\x07\x03\x81\xF8",
                "\xE0\x7E\x38\x1C\x0E\x07\x03\xF1\xC0",
                "\xE0\x7E\x38\x1C\x0E\x07\x03\xF1\xF8",
                "\xE0\x7E\x38\x1C\x0E\x07\xE3\x81\xC0",
                "\xE0\x7E\x38\x1C\x0E\x07\xE3\x81\xF8",
                "\xE0\x7E\x38\x1C\x0E\x07\xE3\xF1\xC0",
                "\xE0\x7E\x38\x1C\x0E\x07\xE3\xF1\xF8",
                "\xE0\x7E\x38\x1C\x0F\xC7\x03\x81\xC0",
                "\xE0\x7E\x38\x1C\x0F\xC7\x03\x81\xF8",
                "\xE0\x7E\x38\x1C\x0F\xC7\x03\xF1\xC0",
                "\xE0\x7E\x38\x1C\x0F\xC7\x03\xF1\xF8",
                "\xE0\x7E\x38\x1C\x0F\xC7\xE3\x81\xC0",
                "\xE0\x7E\x38\x1C\x0F\xC7\xE3\x81\xF8",
                "\xE0\x7E\x38\x1C\x0F\xC7\xE3\xF1\xC0",
                "\xE0\x7E\x38\x1C\x0F\xC7\xE3\xF1\xF8",
                "\xE0\x7E\x38\x1F\x8E\x07\x03\x81\xC0",
                "\xE0\x7E\x38\x1F\x8E\x07\x03\x81\xF8",
                "\xE0\x7E\x38\x1F\x8E\x07\x03\xF1\xC0",
                "\xE0\x7E\x38\x1F\x8E\x07\x03\xF1\xF8",
                "\xE0\x7E\x38\x1F\x8E\x07\xE3\x81\xC0",
                "\xE0\x7E\x38\x1F\x8E\x07\xE3\x81\xF8",
                "\xE0\x7E\x38\x1F\x8E\x07\xE3\xF1\xC0",
                "\xE0\x7E\x38\x1F\x8E\x07\xE3\xF1\xF8",
                "\xE0\x7E\x38\x1F\x8F\xC7\x03\x81\xC0",
                "\xE0\x7E\x38\x1F\x8F\xC7\x03\x81\xF8",
                "\xE0\x7E\x38\x1F\x8F\xC7\x03\xF1\xC0",
                "\xE0\x7E\x38\x1F\x8F\xC7\x03\xF1\xF8",
                "\xE0\x7E\x38\x1F\x8F\xC7\xE3\x81\xC0",
                "\xE0\x7E\x38\x1F\x8F\xC7\xE3\x81\xF8",
                "\xE0\x7E\x38\x1F\x8F\xC7\xE3\xF1\xC0",
                "\xE0\x7E\x38\x1F\x8F\xC7\xE3\xF1\xF8",
                "\xE0\x7E\x3F\x1C\x0E\x07\x03\x81\xC0",
                "\xE0\x7E\x3F\x1C\x0E\x07\x03\x81\xF8",
                "\xE0\x7E\x3F\x1C\x0E\x07\x03\xF1\xC0",
                "\xE0\x7E\x3F\x1C\x0E\x07\x03\xF1\xF8",
                "\xE0\x7E\x3F\x1C\x0E\x07\xE3\x81\xC0",
                "\xE0\x7E\x3F\x1C\x0E\x07\xE3\x81\xF8",
                "\xE0\x7E\x3F\x1C\x0E\x07\xE3\xF1\xC0",
                "\xE0\x7E\x3F\x1C\x0E\x07\xE3\xF1\xF8",
                "\xE0\x7E\x3F\x1C\x0F\xC7\x03\x81\xC0",
                "\xE0\x7E\x3F\x1C\x0F\xC7\x03\x81\xF8",
                "\xE0\x7E\x3F\x1C\x0F\xC7\x03\xF1\xC0",
                "\xE0\x7E\x3F\x1C\x0F\xC7\x03\xF1\xF8",
                "\xE0\x7E\x3F\x1C\x0F\xC7\xE3\x81\xC0",
                "\xE0\x7E\x3F\x1C\x0F\xC7\xE3\x81\xF8",
                "\xE0\x7E\x3F\x1C\x0F\xC7\xE3\xF1\xC0",
                "\xE0\x7E\x3F\x1C\x0F\xC7\xE3\xF1\xF8",
                "\xE0\x7E\x3F\x1F\x8E\x07\x03\x81\xC0",
                "\xE0\x7E\x3F\x1F\x8E\x07\x03\x81\xF8",
                "\xE0\x7E\x3F\x1F\x8E\x07\x03\xF1\xC0",
                "\xE0\x7E\x3F\x1F\x8E\x07\x03\xF1\xF8",
                "\xE0\x7E\x3F\x1F\x8E\x07\xE3\x81\xC0",
                "\xE0\x7E\x3F\x1F\x8E\x07\xE3\x81\xF8",
                "\xE0\x7E\x3F\x1F\x8E\x07\xE3\xF1\xC0",
                "\xE0\x7E\x3F\x1F\x8E\x07\xE3\xF1\xF8",
                "\xE0\x7E\x3F\x1F\x8F\xC7\x03\x81\xC0",
                "\xE0\x7E\x3F\x1F\x8F\xC7\x03\x81\xF8",
                "\xE0\x7E\x3F\x1F\x8F\xC7\x03\xF1\xC0",
                "\xE0\x7E\x3F\x1F\x8F\xC7\x03\xF1\xF8",
                "\xE0\x7E\x3F\x1F\x8F\xC7\xE3\x81\xC0",
                "\xE0\x7E\x3F\x1F\x8F\xC7\xE3\x81\xF8",
                "\xE0\x7E\x3F\x1F\x8F\xC7\xE3\xF1\xC0",
                "\xE0\x7E\x3F\x1F\x8F\xC7\xE3\xF1\xF8",
                "\xFC\x70\x38\x1C\x0E\x07\x03\x81\xC0",
                "\xFC\x70\x38\x1C\x0E\x07\x03\x81\xF8",
                "\xFC\x70\x38\x1C\x0E\x07\x03\xF1\xC0",
                "\xFC\x70\x38\x1C\x0E\x07\x03\xF1\xF8",
                "\xFC\x70\x38\x1C\x0E\x07\xE3\x81\xC0",
                "\xFC\x70\x38\x1C\x0E\x07\xE3\x81\xF8",
                "\xFC\x70\x38\x1C\x0E\x07\xE3\xF1\xC0",
                "\xFC\x70\x38\x1C\x0E\x07\xE3\xF1\xF8",
                "\xFC\x70\x38\x1C\x0F\xC7\x03\x81\xC0",
                "\xFC\x70\x38\x1C\x0F\xC7\x03\x81\xF8",
                "\xFC\x70\x38\x1C\x0F\xC7\x03\xF1\xC0",
                "\xFC\x70\x38\x1C\x0F\xC7\x03\xF1\xF8",
                "\xFC\x70\x38\x1C\x0F\xC7\xE3\x81\xC0",
                "\xFC\x70\x38\x1C\x0F\xC7\xE3\x81\xF8",
                "\xFC\x70\x38\x1C\x0F\xC7\xE3\xF1\xC0",
                "\xFC\x70\x38\x1C\x0F\xC7\xE3\xF1\xF8",
                "\xFC\x70\x38\x1F\x8E\x07\x03\x81\xC0",
                "\xFC\x70\x38\x1F\x8E\x07\x03\x81\xF8",
                "\xFC\x70\x38\x1F\x8E\x07\x03\xF1\xC0",
                "\xFC\x70\x38\x1F\x8E\x07\x03\xF1\xF8",
                "\xFC\x70\x38\x1F\x8E\x07\xE3\x81\xC0",
                "\xFC\x70\x38\x1F\x8E\x07\xE3\x81\xF8",
                "\xFC\x70\x38\x1F\x8E\x07\xE3\xF1\xC0",
                "\xFC\x70\x38\x1F\x8E\x07\xE3\xF1\xF8",
                "\xFC\x70\x38\x1F\x8F\xC7\x03\x81\xC0",
                "\xFC\x70\x38\x1F\x8F\xC7\x03\x81\xF8",
                "\xFC\x70\x38\x1F\x8F\xC7\x03\xF1\xC0",
                "\xFC\x70\x38\x1F\x8F\xC7\x03\xF1\xF8",
                "\xFC\x70\x38\x1F\x8F\xC7\xE3\x81\xC0",
                "\xFC\x70\x38\x1F\x8F\xC7\xE3\x81\xF8",
                "\xFC\x70\x38\x1F\x8F\xC7\xE3\xF1\xC0",
                "\xFC\x70\x38\x1F\x8F\xC7\xE3\xF1\xF8",
                "\xFC\x70\x3F\x1C\x0E\x07\x03\x81\xC0",
                "\xFC\x70\x3F\x1C\x0E\x07\x03\x81\xF8",
                "\xFC\x70\x3F\x1C\x0E\x07\x03\xF1\xC0",
                "\xFC\x70\x3F\x1C\x0E\x07\x03\xF1\xF8",
                "\xFC\x70\x3F\x1C\x0E\x07\xE3\x81\xC0",
                "\xFC\x70\x3F\x1C\x0E\x07\xE3\x81\xF8",
                "\xFC\x70\x3F\x1C\x0E\x07\xE3\xF1\xC0",
                "\xFC\x70\x3F\x1C\x0E\x07\xE3\xF1\xF8",
                "\xFC\x70\x3F\x1C\x0F\xC7\x03\x81\xC0",
                "\xFC\x70\x3F\x1C\x0F\xC7\x03\x81\xF8",
                "\xFC\x70\x3F\x1C\x0F\xC7\x03\xF1\xC0",
                "\xFC\x70\x3F\x1C\x0F\xC7\x03\xF1\xF8",
                "\xFC\x70\x3F\x1C\x0F\xC7\xE3\x81\xC0",
                "\xFC\x70\x3F\x1C\x0F\xC7\xE3\x81\xF8",
                "\xFC\x70\x3F\x1C\x0F\xC7\xE3\xF1\xC0",
                "\xFC\x70\x3F\x1C\x0F\xC7\xE3\xF1\xF8",
                "\xFC\x70\x3F\x1F\x8E\x07\x03\x81\xC0",
                "\xFC\x70\x3F\x1F\x8E\x07\x03\x81\xF8",
                "\xFC\x70\x3F\x1F\x8E\x07\x03\xF1\xC0",
                "\xFC\x70\x3F\x1F\x8E\x07\x03\xF1\xF8",
                "\xFC\x70\x3F\x1F\x8E\x07\xE3\x81\xC0",
                "\xFC\x70\x3F\x1F\x8E\x07\xE3\x81\xF8",
                "\xFC\x70\x3F\x1F\x8E\x07\xE3\xF1\xC0",
                "\xFC\x70\x3F\x1F\x8E\x07\xE3\xF1\xF8",
                "\xFC\x70\x3F\x1F\x8F\xC7\x03\x81\xC0",
                "\xFC\x70\x3F\x1F\x8F\xC7\x03\x81\xF8",
                "\xFC\x70\x3F\x1F\x8F\xC7\x03\xF1\xC0",
                "\xFC\x70\x3F\x1F\x8F\xC7\x03\xF1\xF8",
                "\xFC\x70\x3F\x1F\x8F\xC7\xE3\x81\xC0",
                "\xFC\x70\x3F\x1F\x8F\xC7\xE3\x81\xF8",
                "\xFC\x70\x3F\x1F\x8F\xC7\xE3\xF1\xC0",
                "\xFC\x70\x3F\x1F\x8F\xC7\xE3\xF1\xF8",
                "\xFC\x7E\x38\x1C\x0E\x07\x03\x81\xC0",
                "\xFC\x7E\x38\x1C\x0E\x07\x03\x81\xF8",
                "\xFC\x7E\x38\x1C\x0E\x07\x03\xF1\xC0",
                "\xFC\x7E\x38\x1C\x0E\x07\x03\xF1\xF8",
                "\xFC\x7E\x38\x1C\x0E\x07\xE3\x81\xC0",
                "\xFC\x7E\x38\x1C\x0E\x07\xE3\x81\xF8",
                "\xFC\x7E\x38\x1C\x0E\x07\xE3\xF1\xC0",
                "\xFC\x7E\x38\x1C\x0E\x07\xE3\xF1\xF8",
                "\xFC\x7E\x38\x1C\x0F\xC7\x03\x81\xC0",
                "\xFC\x7E\x38\x1C\x0F\xC7\x03\x81\xF8",
                "\xFC\x7E\x38\x1C\x0F\xC7\x03\xF1\xC0",
                "\xFC\x7E\x38\x1C\x0F\xC7\x03\xF1\xF8",
                "\xFC\x7E\x38\x1C\x0F\xC7\xE3\x81\xC0",
                "\xFC\x7E\x38\x1C\x0F\xC7\xE3\x81\xF8",
                "\xFC\x7E\x38\x1C\x0F\xC7\xE3\xF1\xC0",
                "\xFC\x7E\x38\x1C\x0F\xC7\xE3\xF1\xF8",
                "\xFC\x7E\x38\x1F\x8E\x07\x03\x81\xC0",
                "\xFC\x7E\x38\x1F\x8E\x07\x03\x81\xF8",
                "\xFC\x7E\x38\x1F\x8E\x07\x03\xF1\xC0",
                "\xFC\x7E\x38\x1F\x8E\x07\x03\xF1\xF8",
                "\xFC\x7E\x38\x1F\x8E\x07\xE3\x81\xC0",
                "\xFC\x7E\x38\x1F\x8E\x07\xE3\x81\xF8",
                "\xFC\x7E\x38\x1F\x8E\x07\xE3\xF1\xC0",
                "\xFC\x7E\x38\x1F\x8E\x07\xE3\xF1\xF8",
                "\xFC\x7E\x38\x1F\x8F\xC7\x03\x81\xC0",
                "\xFC\x7E\x38\x1F\x8F\xC7\x03\x81\xF8",
                "\xFC\x7E\x38\x1F\x8F\xC7\x03\xF1\xC0",
                "\xFC\x7E\x38\x1F\x8F\xC7\x03\xF1\xF8",
                "\xFC\x7E\x38\x1F\x8F\xC7\xE3\x81\xC0",
                "\xFC\x7E\x38\x1F\x8F\xC7\xE3\x81\xF8",
                "\xFC\x7E\x38\x1F\x8F\xC7\xE3\xF1\xC0",
                "\xFC\x7E\x38\x1F\x8F\xC7\xE3\xF1\xF8",
                "\xFC\x7E\x3F\x1C\x0E\x07\x03\x81\xC0",
                "\xFC\x7E\x3F\x1C\x0E\x07\x03\x81\xF8",
                "\xFC\x7E\x3F\x1C\x0E\x07\x03\xF1\xC0",
                "\xFC\x7E\x3F\x1C\x0E\x07\x03\xF1\xF8",
                "\xFC\x7E\x3F\x1C\x0E\x07\xE3\x81\xC0",
                "\xFC\x7E\x3F\x1C\x0E\x07\xE3\x81\xF8",
                "\xFC\x7E\x3F\x1C\x0E\x07\xE3\xF1\xC0",
                "\xFC\x7E\x3F\x1C\x0E\x07\xE3\xF1\xF8",
                "\xFC\x7E\x3F\x1C\x0F\xC7\x03\x81\xC0",
                "\xFC\x7E\x3F\x1C\x0F\xC7\x03\x81\xF8",
                "\xFC\x7E\x3F\x1C\x0F\xC7\x03\xF1\xC0",
                "\xFC\x7E\x3F\x1C\x0F\xC7\x03\xF1\xF8",
                "\xFC\x7E\x3F\x1C\x0F\xC7\xE3\x81\xC0",
                "\xFC\x7E\x3F\x1C\x0F\xC7\xE3\x81\xF8",
                "\xFC\x7E\x3F\x1C\x0F\xC7\xE3\xF1\xC0",
                "\xFC\x7E\x3F\x1C\x0F\xC7\xE3\xF1\xF8",
                "\xFC\x7E\x3F\x1F\x8E\x07\x03\x81\xC0",
                "\xFC\x7E\x3F\x1F\x8E\x07\x03\x81\xF8",
                "\xFC\x7E\x3F\x1F\x8E\x07\x03\xF1\xC0",
                "\xFC\x7E\x3F\x1F\x8E\x07\x03\xF1\xF8",
                "\xFC\x7E\x3F\x1F\x8E\x07\xE3\x81\xC0",
                "\xFC\x7E\x3F\x1F\x8E\x07\xE3\x81\xF8",
                "\xFC\x7E\x3F\x1F\x8E\x07\xE3\xF1\xC0",
                "\xFC\x7E\x3F\x1F\x8E\x07\xE3\xF1\xF8",
                "\xFC\x7E\x3F\x1F\x8F\xC7\x03\x81\xC0",
                "\xFC\x7E\x3F\x1F\x8F\xC7\x03\x81\xF8",
                "\xFC\x7E\x3F\x1F\x8F\xC7\x03\xF1\xC0",
                "\xFC\x7E\x3F\x1F\x8F\xC7\x03\xF1\xF8",
                "\xFC\x7E\x3F\x1F\x8F\xC7\xE3\x81\xC0",
                "\xFC\x7E\x3F\x1F\x8F\xC7\xE3\x81\xF8",
                "\xFC\x7E\x3F\x1F\x8F\xC7\xE3\xF1\xC0",
                "\xFC\x7E\x3F\x1F\x8F\xC7\xE3\xF1\xF8"];
// This string holds three "zero" bytes [0,0,0]; clears a pixel when written to the frame
const clearString = "\xE0\x70\x38\x1C\x0E\x07\x03\x81\xC0\xE0\x70\x38\x1C\x0E\x07\x03\x81\xC0\xE0\x70\x38\x1C\x0E\x07\x03\x81\xC0";

/* CLASS AND FUNCTION DEFINITIONS --------------------------------------------*/

class neoPixels {
    spi = null;
    frameSize = null;
    frame = null;

    // _spi - A configured spi (MSB_FIRST, 7.5MHz)
    // _frameSize - Number of Pixels per frame
    constructor(_spi, _frameSize) {
        this.spi = _spi;
        this.frameSize = _frameSize;
        this.frame = blob(frameSize*27 + 1);
        
        clearFrame();
        writeFrame();
    }

    // sets a pixel in the frame buffer
    // but does not write it to the pixel strip
    // color is an array of the form [r, g, b]
    function writePixel(p, color) {
        frame.seek(p*BYTESPERPIXEL);
        // red and green are swapped for some reason, so swizzle them back 
        frame.writestring(bits[color[1]]);
        frame.writestring(bits[color[0]]);
        frame.writestring(bits[color[2]]);    
    }
    
    // Clears the frame buffer
    // but does not write it to the pixel strip
    function clearFrame() {
        frame.seek(0);
        for (local p = 0; p < frameSize; p++) frame.writestring(clearString);
        frame.writen(0x00,'c');
    }
    
    // writes the frame buffer to the pixel strip
    // ie - this function changes the pixel strip
    function writeFrame() {
        spi.write(frame);
    }
}

class neoWeather extends neoPixels {
    
    REFRESHPERIOD   = 0.05; // effects refresh 10 times per second
    NEWPIXELFACTOR  = 1000; // 1/100 pixels will show a new "drop" for a factor 1 effect
    LIGHTNINGFACTOR = 5000; // factor/5000 refreshes will yield lightning
    SCALE           = 100;  // NEWPIXELFACTOR / maximum "factor" value provided to an effect
                            // this class uses factor 0-10 to set intensity
    MAXNEWDROP      = 500;  // max percent chance a new drop will occur on an empty pixel
    MAXLIGHTNING    = 10;   // max percentage chance lightning will occur on an frame
    LTBRTSCALE      = 3.1;  // amount to scale lightning brightness with intensity factor
    DIMPIXELPERCENT = 0.8;  // percent of previous value to dim a pixel to when fading
    
    /* default color values */
    RED     = [16,0,0];
    GREEN   = [0,16,0];
    BLUE    = [0,0,16];
    YELLOW  = [8,8,0];
    CYAN    = [0,8,8];
    MAGENTA = [8,0,8];
    ORANGE  = [16,8,0];
    WHITE   = [7,8,8];
    
    // an array of [r,g,b] arrays to describe the next frame to be displayed
    pixelvalues = [];
    wakehandle = 0; // keep track of the next imp.wakeup handle, so we can cancel if changing effects
    
    constructor(_spi, _frameSize) {
        base.constructor(_spi, _frameSize);
        pixelvalues = [];
        for (local x = 0; x < _frameSize; x++) { pixelvalues.push([0,0,0]); }
    }

    /* Stop all effects from displaying and blank out all the pixels.
     * Input: (none)
     * Return: (none)
     */
    function stop() {
        // cancel any previous effect currently running
        imp.cancelwakeup(wakehandle);
        dialvalues = array(_frameSize, [0,0,0]);
        draw();
    }
    
    /* Blue and Purple fading dots effect.
     * Factor is 1 to 10 and scales the number of new raindrops per refresh.
     */
    function rain(factor) {
        local NUMCOLORS = 2;
        //local tick = hardware.micros();
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
 
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {rain(factor)}.bindenv(this));
        
        local newdrop = 0;
        local threshold = (factor * SCALE);
        if (threshold < NUMCOLORS) { threshold = NUMCOLORS; }
        if (threshold > MAXNEWDROP) { threshold = MAXNEWDROP; }
        local next = false;
        clearFrame();
        for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
            //server.log(pixel);
            // if there's any color data in this pixel, fade it down 
            next = false;
            if (pixelvalues[pixel][0]) { pixelvalues[pixel][0] = math.floor(pixelvalues[pixel][0] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][1]) { pixelvalues[pixel][1] = math.floor(pixelvalues[pixel][1] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][2]) { pixelvalues[pixel][2] = math.floor(pixelvalues[pixel][2] * DIMPIXELPERCENT); next = true;}
            // skip random number generation if we just dimmed
            if (!next) {
                newdrop = math.rand() % NEWPIXELFACTOR;
                if (newdrop <= threshold) {
                    switch (newdrop % NUMCOLORS) {
                        case 0:
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = BLUE[channel];
                            }
                            break;
                        default: 
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = MAGENTA[channel];
                            }
                            break;
                    }
                }
            }
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
        //local tock = hardware.micros();
        //server.log(format("Refreshed Effect in %d us",(tock-tick)));
    }
    
    /* White fading dots effect.
     * Factor is 1 to 10 and scales the number of new raindrops per refresh.
     */
    function snow(factor) {
        //local tick = hardware.micros();
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
 
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {snow(factor)}.bindenv(this));
        
        local newdrop = 0;
        local threshold = (factor * SCALE);
        if (threshold < NUMCOLORS) { threshold = NUMCOLORS; }
        if (threshold > MAXNEWDROP) { threshold = MAXNEWDROP; }
        local next = false;
        clearFrame();
        for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
            //server.log(pixel);
            // if there's any color data in this pixel, fade it down 
            next = false;
            if (pixelvalues[pixel][0]) { pixelvalues[pixel][0] = math.floor(pixelvalues[pixel][0] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][1]) { pixelvalues[pixel][1] = math.floor(pixelvalues[pixel][1] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][2]) { pixelvalues[pixel][2] = math.floor(pixelvalues[pixel][2] * DIMPIXELPERCENT); next = true;}
            // skip random number generation if we just dimmed
            if (!next) {
                newdrop = math.rand() % NEWPIXELFACTOR;
                if (newdrop <= threshold) {
                    for (local channel = 0; channel < 3; channel++) {
                        pixelvalues[pixel][channel] = WHITE[channel];
                    }
                }
            }
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
        //local tock = hardware.micros();
        //server.log(format("Refreshed Effect in %d us",(tock-tick)));
    }
    
    /* Blue and White fading dots effect.
     * Factor is 1 to 10 and scales the number of new raindrops per refresh.
     */
    function hail(factor) {
        local NUMCOLORS = 3; // colors used in this effect
        //local tick = hardware.micros();
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
 
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {hail(factor)}.bindenv(this));
        
        local newdrop = 0;
        local threshold = (factor * SCALE);
        if (threshold < NUMCOLORS) { threshold = NUMCOLORS; }
        if (threshold > MAXNEWDROP) { threshold = MAXNEWDROP; }
        local next = false;
        clearFrame();
        for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
            //server.log(pixel);
            // if there's any color data in this pixel, fade it down 
            next = false;
            if (pixelvalues[pixel][0]) { pixelvalues[pixel][0] = math.floor(pixelvalues[pixel][0] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][1]) { pixelvalues[pixel][1] = math.floor(pixelvalues[pixel][1] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][2]) { pixelvalues[pixel][2] = math.floor(pixelvalues[pixel][2] * DIMPIXELPERCENT); next = true;}
            // skip random number generation if we just dimmed
            if (!next) {
                newdrop = math.rand() % NEWPIXELFACTOR;
                if (newdrop <= threshold) {
                    switch (newdrop % NUMCOLORS) {
                        case 0: 
                            //server.log("cyan");
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = CYAN[channel];
                            }
                            break;
                        case 1: 
                            //server.log("magenta");
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = MAGENTA[channel];
                            }
                            break;
                        default: 
                            //server.log("white");
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = WHITE[channel];
                            }
                            break;
                    }
                }
            }
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
        //local tock = hardware.micros();
        //server.log(format("Refreshed Effect in %d us",(tock-tick)));
    }
    
    /* Blue and Purple fading dots effect with yellow "lightning strikes".
     * Factor is 0 to 10 and scales the number of new raindrops per refresh, 
     * as well as frequency of lightning.
     */
    function thunder(factor) {
        local NUMCOLORS = 2;
        //local tick = hardware.micros();
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
 
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {thunder(factor)}.bindenv(this));
        
        local newdrop = 0;
        local threshold = (factor * SCALE);
        if (threshold < NUMCOLORS) { threshold = NUMCOLORS; }
        if (threshold > MAXNEWDROP) { threshold = MAXNEWDROP; }
        //server.log(threshold);
        
        local lightningthreshold = factor;
        if (lightningthreshold > MAXLIGHTNING) { threshold = MAXLIGHTNING; }
        
        local lightningcheck = math.rand() % LIGHTNINGFACTOR;
        local next = false;
        clearFrame();
        if (lightningcheck <= lightningthreshold) {
            local lightningbrightness = math.floor(factor * LTBRTSCALE);
            for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
                for (local channel = 0; channel < 3; channel++) {
                    pixelvalues[pixel][channel] = lightningbrightness * YELLOW[channel];
                }
            }
        } else {
            for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
                //server.log(pixel);
                // if there's any color data in this pixel, fade it down 
                next = false;
                if (pixelvalues[pixel][0]) { pixelvalues[pixel][0] = math.floor(pixelvalues[pixel][0] * DIMPIXELPERCENT); next = true;}
                if (pixelvalues[pixel][1]) { pixelvalues[pixel][1] = math.floor(pixelvalues[pixel][1] * DIMPIXELPERCENT); next = true;}
                if (pixelvalues[pixel][2]) { pixelvalues[pixel][2] = math.floor(pixelvalues[pixel][2] * DIMPIXELPERCENT); next = true;}
                // skip random number generation if we just dimmed
                if (!next) {
                    newdrop = math.rand() % NEWPIXELFACTOR;
                    if (newdrop <= threshold) {
                        switch (newdrop % NUMCOLORS) {
                            case 0:
                                for (local channel = 0; channel < 3; channel++) {
                                    pixelvalues[pixel][channel] = BLUE[channel];
                                }
                                break;
                            default: 
                                for (local channel = 0; channel < 3; channel++) {
                                    pixelvalues[pixel][channel] = MAGENTA[channel];
                                }
                                break;
                        }
                    }
                }
                writePixel(pixel, pixelvalues[pixel]);
            }
        }
        writeFrame();
        //local tock = hardware.micros();
        //server.log(format("Refreshed Effect in %d us",(tock-tick)));
    }
    
    function ice(factor) {
    }
    
    function mist(factor) {
    }
    
    function fog(factor) {
    }
    
    function temp(val, factor) {
        // cancel any previous effect currently running
        imp.cancelwakeup(wakehandle);
    }
}

/* AGENT CALLBACKS -----------------------------------------------------------*/

agent.on("seteffect", function(val) {
    try {
        cond = val.conditions;
        temp = val.temperature;
    } catch (err) {
        server.error("Invalid Request from Agent: "+err);
        return;
    }
    
    if (cond == "drizzle") {
        display.rain(1);
    } else if (cond == "rain") {
        display.rain(2);
    } else if (cond == "snow") {
        display.snow(1);
    } else if (cond == "ice") {
        display.ice(1);
    } else if (cond == "hail") {
        display.hail(1);
    } else if (cond == "mist") {
        display.mist(1);
    } else if (cond == "fog") {
        display.fog(1);
    } else if (cond == "thunderstorm") {
        display.thunder(2);
    } else if (cond == "clear") {
        display.temp(temp, 4);    
    } else if (cond == "mostlycloudy") {
        display.temp(temp, 3); 
    } else if (cond == "partlycloudy") {
        display.temp(temp, 2);
    } else {
        display.temp(temp, 1);
    }
});

/* RUNTIME BEGINS HERE -------------------------------------------------------*/

// The number of pixels in your chain
const NUMPIXELS = 64;

spi <- hardware.spi257;
spi.configure(MSB_FIRST, SPICLK);
display <- neoWeather(spi, NUMPIXELS);

server.log("ready.");
display.thunder(5);
server.log("effect started.");
