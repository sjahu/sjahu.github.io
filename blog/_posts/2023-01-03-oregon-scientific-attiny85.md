---
title: "ATtiny85-based Oregon Scientific v2.1 remote temperature sensor"
---

In my [last post](/blog/2022/12/04/oregon-scientific), I showed off a prototype of my Arduino-based Oregon Scientific v2.1 sensor. It worked, but it wouldn't be very practical for real use. Let's take a look at building a more "production-ready" version. The following headers are in no particular order; a wiring schematic (if you can call it that) is near the bottom of the post, and so is the code. 

# Bill of materials

- [ATTINY85V-10PU](https://www.digikey.ca/en/products/detail/microchip-technology/ATTINY85V-10PU/735471)
- [1" × 1" perfboard](https://www.digikey.ca/en/products/detail/sparkfun-electronics/PRT-08808/7387401)
- [433 MHz transmitter](https://www.aliexpress.com/item/32980820915.html)
- [DHT22 sensor](https://www.aliexpress.com/item/32523611214.html)
- 2x [100 nF capacitor](https://www.amazon.ca/dp/B08DNF191P)
- [32 768 Hz crystal oscillator](https://www.digikey.com/en/products/detail/micro-crystal-ag/OM-7605-C8-32-768KHZ-20PPM-TA-QC/10499153)

This comes out to about $10 CAD if you ignore my wasted shipping costs from placing multiple orders, the fact that I actually bought several of each part, and the large Amazon markup I paid to get a box of several hundred capacitors shipped next-day rather than waiting for delivery from China.

# Microcontroller

The Arduino-on-breadboard form factor, while great for prototyping, is too expensive (25 USD for an [Arduino Leonardo](https://store-usa.arduino.cc/products/arduino-leonardo-with-headers)), too large (2.7" × 2.1"), and too power-hungry (it draws ~20 mA at 3.3 V running an empty Arduino sketch at 16 MHz) to use for something as simple and portable as a temperature sensor.

I chose an ATtiny85 microcontroller as the brain for version 2 of my sensor since it's compatible with the Arduino IDE but tiny (so accurately named!) and cheap. A 1" square perfboard provides a perfect platform for the 8 pin chip and the the few necessary peripherals.

# Programming the ATtiny85

I programmed the ATtiny85 using my Arduino Leonardo board and the ArduinoISP sketch included with the Arduino IDE. It's easy to find instructions on how to do this, e.g. [here](https://petervanhoyweghen.wordpress.com/2012/09/16/arduinoisp-on-the-leonardo/).

{% figure /assets/images/blog/2023-01-03/arduino_isp.jpg medium %}
Flashing the firmware.
{% endfigure %}

# Power consumption

Out of the box, an Arduino board running a naïvely written sketch can be impractical to run on battery power; assuming a capacity of 1200 mAh per AAA cell, a constant load of 20 mA (as quoted above for an empty sketch running on an Arduino Leonardo at 16 MHz and 3.3 V) would drain two cells in only about 5 days. Nick Gammon describes some ways to save power in microcontroller projects [here](http://www.gammon.com.au/power). Based on those tips, I made the following optimizations:

- lose the development board and just use the microcontroller on its own,
- disable the Analog to Digital converter when not in use,
- use as low a clock speed as possible,
- power off peripherals (sensor, radio, oscillator) when not in use, and
- don't busy-wait; use the microcontroller's power-off sleep mode whenever possible.

I set the ATtiny to run at 8 MHz, instead of 16, which saves a significant amount of power when the CPU is running. The microcontroller's internal oscillator can also run at 1 MHz, but that's too slow to interface with the DHT22 sensor, at least with the library I was using.

Powered on but not transmitting, the 433 MHz transmitter drew about 4.7 mA; transmitting, this jumped to 25.5 mA. The DHT22 drew about 170 µA at idle and a few mA when in use. The oscillator also drew a few µA when powered on. All of these would reduce battery life if they were powered on all the time, so I elected to switch them on only when necessary. Since each pin on the ATtiny can supply 40 mA, it's fine to drive the peripherals directly.

In power-off sleep with all the peripherals unpowered and the ADC disabled, I found that the ATtiny85 used about only about 4.4 µA at 3.3 V. This is basically a rounding error compared to the power usage when not sleeping: ~4 mA by the microcontroller itself when the processor is running for a fraction of a second, plus 25 mA for 0.2 seconds when transmitting (the signal takes about 0.2 seconds to send and we send it twice; given a 50% duty cycle that means the transmitter is powered for 0.2 seconds). Plugging those rough numbers into a calculation indicates that two AAAs should power the device for at least a year and a half.

# Timing

I mentioned in my previous post that the Oregon Scientific base station is very picky about timing-- if the timing of a transmission is off from 1024 Hz by more than about +/- 3 µs per cycle, the transmission will be ignored. That's a tolerance of about 0.3%, which I achieved in the prototype by calibrating the delay used to generate the output signal based on the signal's measured frequency. Unfortunately, the ATtiny85's internal [RC oscillator](https://en.wikipedia.org/wiki/RC_oscillator) is not particularly stable with respect to voltage or temperature, both of which will vary in this application as the battery wear and weather conditions change. According to the [datasheet](https://ww1.microchip.com/downloads/en/DeviceDoc/Atmel-2586-AVR-8-bit-Microcontroller-ATtiny25-ATtiny45-ATtiny85_Datasheet.pdf) (which was an invaluable resource at every step of this build), the frequency can vary by nearly 4%, which is an order of magnitute more what would be acceptable. When I tested this by putting my ATtiny-based v2 prototype, which worked at room temperature, in the freezer, the base station quickly stopped receiving transmissions and the recordings that I captured on my laptop confirmed that the signal's frequency had dropped well out of spec.

{% image /assets/images/blog/2023-01-03/datasheet_oscillator_frequency.png %}

I toyed with the idea of trying to model the expected internal oscillator frequency based on the instantaneous measured temperature and voltage, but it seemed very unlikely that the results would be precise enough to be worth the effort. The consensus on AVRFreaks.net when somebody else [considered doing something similar](https://www.avrfreaks.net/s/topic/a5C3l000000UNwDEAW/t105811) was that, "unless your widget will be produced by ten of millions pieces a year", "do not fuck your brain ... connect a crystal to it". Sage advice. Instead, I ordered a 32 768 Hz crystal oscillator, guaranteed to be accurate to ±20 ppm (parts per million) at room temperature and up to an additional 150 ppm off at the extremes of -40°C to 90°C. That's an order of magnitude *better* than the receiver requires.

The ATtiny85 supports clocking the entire device with an external oscillator or crystal. In this case, however, I didn't care what frequency computations were performed at, which is why, instead of replacing the device clock source, I opted to use a crystal oscillator with a frequency divisible by 1024 Hz as the clock source only for Timer0, leaving the CPU to use the imprecise internal oscillator. I rewrote the signal generation code to use sleeps and interrupts (occurring every 16 ticks of the 32 768 Hz oscillator, i.e. at 2048 Hz) to generate the output signal. This resulted in an acceptable level of precision over the whole voltage and temperature range.

Aside: *why 32 768 Hz?*, you might ask. Well, 32 768 is divisible by 2048, so it's a suitable frequency for this particular task. Secondarily, 32 768 Hz crystal oscillators are extremely abundant and cheap because they're commonly used in real-time clock applications (like almost all digital watches)-- you can measure exactly 1 second using a 32 768 Hz oscillator and a 15-bit binary counter.

The watch crystal worked well, but I misread the datasheet when ordering it and was unpleasantly surprised to find that it was only 2 mm² in area. This crumb-sized component proved very difficult to solder onto my perfboard; I ended up having to place it at an angle to get three of the pins touching solder pads, then use a glob of solder between the fourth pad and metal lid to establish the ground connection. If I ever build another one of these, I'll design a real PCB with properly spaced pads.

{% figure /assets/images/blog/2023-01-03/oscillator.jpg small %}
Zoom in.
{% endfigure %}

# Irrational temperature data

I noticed that once in a while, particularly when testing it in the freezer, my DHT22 sensor returned irrational data: either 150°C/100% RH or 50°C/0% RH. I'm not sure why this happened; maybe it was just a bad part. The datasheet doesn't mention anything about these values, but I ordered the sensor from Aliexpress so who knows if it's even the real thing. Anyway, I added a check for these specific pairs that causes the program to leave the sensor powered on for a couple seconds then try again. This seemed to usually result in a successful reading.

# Low-battery detection

The v2.1 protocol supports a low-battery flag, which I didn't implement in the prototype. The ATtiny85 can use its Analog to Digital Converter to calculate its own supply voltage by setting the reference voltage for a comparison to Vcc and the measurement voltage to the internal 1.1 V reference. By inverting result, you can solve for Vcc.

If the calculated Vcc is lower than a certain threshold, the low-battery flag is set in the transmission.

# Channel selection

The sensor can mark transmissions as channel 1, 2, or 3. I initially implemented some startup logic to read the channel setting from two input pins, but when I added the crystal oscillator I had to give those up. Instead, I made it so resetting the device via the external reset pin (which can be differentiated in software from a reset triggered by power-cycling the device) increments a value stored in the EEPROM, and this value is used to determine the channel number.

The stored value is also used as the seed for the random number generator that picks the rolling ID. This means the behaviour of the sensor is slightly different from the factory one, in that the rolling ID only changes on reset and not on powering off/on. I find this to be an improvement, since the base station usually refurses to display a transmissios for a given channel if the rolling ID is different from the value in the previous transmission.

# Sleeping and waking using the watchdog timer

The ATtiny85 supports various sleep modes, including power-down mode, which uses the least power. To wake up from power-down sleep, you can use the microcontroller's built-in watchdog timer to trigger an interrupt after a certain interval. (The watchdog timer can operate in two modes: reset mode, where it triggers a system reset when its timer matches, or interrupt mode, where it triggers an interrupt and doesn't reset the chip.)

The [datasheet](https://ww1.microchip.com/downloads/en/DeviceDoc/Atmel-2586-AVR-8-bit-Microcontroller-ATtiny25-ATtiny45-ATtiny85_Datasheet.pdf) has a lot of good information on using the watchdog timer; see also the code, below, for exactly how I implemented this.

As a bonus safety feature, I configured the watchdog timer to trigger a rest (not an interrupt) if the code in the main loop (reading the sensor, generating the data, transmitting the signal) ever gets stuck.

# Circuit assembly

{% figure /assets/images/blog/2023-01-03/attiny85_breadboard.jpg medium %}
Prototype v2.
{% endfigure %}

Converting my v2 prototype into the final build was in principle straightforward, but took a lot of work. I planned out a circuit to connect the microcontroller pins to the radio, sensor, and oscillator as described in the code, then soldered it all together. Note the 100 nF capacitors connected between power and ground of the ATtiny85 and the DHT22: these are to [decouple](https://en.wikipedia.org/wiki/Decoupling_capacitor) the chips from the power supply.

{% figure /assets/images/blog/2023-01-03/schematic.jpg large %}
Does this count as a schematic?
{% endfigure %}

{% image /assets/images/blog/2023-01-03/top.jpg small %}

{% image /assets/images/blog/2023-01-03/bottom.jpg small %}

All of the components I selected are pretty flexible in terms of what voltage they'll operate on. This circuit can be powered by two or three AAA or AA cells, depending on the desired battery life and signal power. A device reset/channel change can be triggered by using a metal screwdriver to briefly connect the reset pin and ground (i.e. the top-left-most two blobs in the last picture).

# Code

Also hosted on GitHub, [here](https://github.com/sjahu/oregon-scientific). The code below is up-to-date only as of the initial commit in the linked repo.

## sensor.ino

```cpp
/*
 * ATTiny85-based temperature/humidity sensor compatible with the Oregon Scientific v2.1
 * 433.92 MHz weather sensor protocol.
 *
 * This sketch replicates the behaviour of the Oregon Scientific THGR122NX sensor.
 * 
 * Most of the pin assignments defined below are flexible; the only one that isn't is T0,
 * which must be connected to the external oscillator clocking Timer/Counter0. On the
 * ATTiny85, T0 is on PB2.
 *
 * More info here: https://shumphries.ca/blog/2023/01/03/oregon-scientific-attiny85
 *
 * LICENCE
 *
 * Copyright © 2023 Stephen Humphries
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include <avr/sleep.h>
#include <avr/wdt.h>

#include "DHTWrapper.h"
#define DHT_DATA_PIN 4 // I/O for the temperature/humidity sensor
#define DHT_POWER_PIN 3
DHTWrapper dht = DHTWrapper(DHT_DATA_PIN, DHT_POWER_PIN);

#define T0_PIN 2
#define T0_XO_POWER_PIN 1 // Power for the crystal oscillator clocking Timer0
#include "OS21Tx.h"
#define TX_PIN 0 // Output for the 433.92 Mhz modulator
OS21Tx tx = OS21Tx(TX_PIN);

#include <EEPROM.h>
#define RESET_COUNT_ADDR 0 // Where to store the current reset count (used for seeding RNG and saving channel setting)

#define RESET_PIN 5

#define LOW_BATTERY 2000 // Threshold in mV (2V picked with 2x 1.5V AAA cells in mind. Adjust as required.)

void setup() {
  cli();
  uint8_t _MCUSR = MCUSR;
  MCUSR = 0; // As per the datasheet, if a watchdog timer reset status flag is set, it must be cleared ASAP
  wdt_disable(); // Otherwise, the watchdog timer will start over immediately with the smallest prescale value
  sei();

  ADCSRA = 0; // Disable Analog to Digital Converter (wastes power)

  pinMode(RESET_PIN, INPUT_PULLUP); // Leaving the reset pin floating can trigger random resets

  pinMode(T0_XO_POWER_PIN, OUTPUT);

  uint32_t resetCount;
  EEPROM.get(RESET_COUNT_ADDR, resetCount);
  if (_MCUSR & (1 << EXTRF)) { // Increment the saved channel if an external reset was triggered
    ++resetCount;
    EEPROM.put(RESET_COUNT_ADDR, resetCount);
  }
  
  uint8_t channel = (resetCount % 3) + 1; // i.e. 1, 2, or 3
  randomSeed(resetCount); // Seed RNG for picking Rolling ID

  dht.begin();
  tx.begin(channel, random(256));
}

void loop() {
  digitalWrite(T0_XO_POWER_PIN, HIGH);
  dht.powerOn();

  // Sleep for 2 seconds to give the DHT22 and crystal oscillator a chance to wake up
  set_sleep_mode(SLEEP_MODE_PWR_DOWN);
  sleep_enable();
  WDTCR = (1 << WDIE) | (1 << WDCE) | (1 << WDE) | (1 << WDP2) | (1 << WDP1) | (1 << WDP0); // Enable watchdog timer interrupt with 2 second countdown (see ATtiny85 datasheet, section 8.5)
  wdt_reset(); // With the WDE bit set, too, WDIE is cleared when a timeout occurs, putting the watchdog in reset mode
  sleep_cpu(); // So if something in the following sensor or tx code hangs for more than 2s, the watchdog will trigger a chip reset
  sleep_disable();
  
  float t, h;
  dht.read(t, h);

  if (dht.irrationalReading(t, h)) {
    return; // Try again if we get a known bad reading
  }
  
  dht.powerOff();

#ifdef LOW_BATTERY
  tx.transmit(t, h, getVcc() < LOW_BATTERY);
#else
  tx.transmit(t, h);
#endif

  digitalWrite(T0_XO_POWER_PIN, LOW);

  // Sleep for 8*5 = 40 seconds (8 seconds is the max for the watchdog timer prescaler)
  set_sleep_mode(SLEEP_MODE_PWR_DOWN);
  sleep_enable();
  wdt_disable(); // Clear WDE to put watchdog timer back in interrupt-only mode
  WDTCR = (1 << WDIE) | (1 << WDCE) | (1 << WDP3) | (1 << WDP0);
  wdt_reset();
  sleep_cpu(); // This is probably overly cautious, but I'm not using a loop here
  sleep_cpu(); // because if cosmic rays or something disrupted the counter, we
  sleep_cpu(); // could be sleeping for a very long time, since the watchdog timer 
  sleep_cpu(); // reset is disabled at this point
  sleep_cpu();
  sleep_disable();
}

ISR(WDT_vect) {
  // Interrupt handler for watchdog timer
  // Do nothing; just return control flow to where it was before sleeping
}

long getVcc() {
  uint8_t _ADCSRA = ADCSRA;
  
  ADCSRA = (1 << ADEN); // Enable ADC
  ADMUX = (1 << MUX3) | (1 << MUX2); // Vcc as voltage reference; 1.1V bandgap voltage as measurement target
  
  delay(2); // Allow ADC to settle after switching to internal voltage reference (as per datasheet)
  
  ADCSRA |= (1 << ADSC); // Start conversion
  while (ADCSRA & (1 << ADSC));
 
  uint8_t adcl  = ADCL;
  uint8_t adch = ADCH;
  
  uint16_t result = (adch << 8) | (adcl << 0); // result is 10 bits (max 1023)

  ADCSRA = _ADCSRA;
  
  return 1125300L / result; // Vcc in mV (1.1 * 1023 * 1000 = 1125300)
}
```

## DHTWrapper.h

```cpp
/*
 * A fairly dumb wrapper for DHT.h that adds handling for powering a DHT22 sensor
 * on and off via a separate power pin.

 * More info here: https://shumphries.ca/blog/2023/01/03/oregon-scientific-attiny85
 *
 * LICENCE
 *
 * Copyright © 2023 Stephen Humphries
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
 
#ifndef DHTWRAPPER_H
#define DHTWRAPPER_H

#include <DHT.h> // Adafruit's DHT sensor library (https://github.com/adafruit/DHT-sensor-library)

#define SENSOR_TYPE DHT22

class DHTWrapper {
  public:
  const uint8_t dataPin;
  const uint8_t powerPin;
  DHT dht;

  DHTWrapper(uint8_t dataPin,  uint8_t powerPin): dataPin(dataPin), powerPin(powerPin), dht(DHT(dataPin, SENSOR_TYPE)) {}

  void begin() {
    pinMode(powerPin, OUTPUT);
    dht.begin(); // Must call this to set the initial pulltime value (see dht.h/dht.cpp)
    pinMode(dataPin, OUTPUT);
    digitalWrite(dataPin, LOW);
  }

  void powerOn() {
    digitalWrite(powerPin, HIGH);
    // DHT::read() takes care of setting the data pin to the correct state before reading
  }

  void powerOff() {
    digitalWrite(powerPin, LOW);
    
    pinMode(dataPin, OUTPUT);
    digitalWrite(dataPin, LOW);
  }

  void read(float &t, float &h) {
    // Without force=true, the DHT library only communicates with the seonsor if the last reading was taken more than 2 seconds ago
    // Since power off sleeping stops all the clocks, that 2 seconds would be counting actual CPU run time, which is not helpful for this application
    t = dht.readTemperature(/*fahrenheit*/false, /*force*/true);
    h = dht.readHumidity(/*force*/false);
  }

  bool irrationalReading(float t, float h) {
    return (
      (t == 0.0   && h == 0.0) || // Returned by DHT::read() when the reading times out; rare if the sensor is given long enough to power on, but still possible
      (t == 150.0 && h == 100.0) || // My sensor seems to sometimes return irrational data pairs like this and the next one. Maybe it's a bad part ¯\_(ツ)_/¯
      (t == 50.0  && h == 0.0)
    );    
  }
};

#endif /* DHTWRAPPER_H */
```

## OS21Tx.h

```cpp
/*
 * A library for transmitting temperature and humidity data via the Oregon Scientific v2.1 protocol.
 * 
 * Requires a 433.92 MHz transmitter connected to a digital pin and a 32 768 Hz crystal oscillator
 * connected to T0 (PB2 on ATTiny85).
 * 
 * Assumes that an interrupt waking the CPU from sleep will occur 2 048 times per second. It should
 * be straightforward to change how this interrupt is generated (e.g. to use an oscillator with a
 * different frequency) by modifying the configureTimer() and restoreTimer() functions below.

 * More info here: https://shumphries.ca/blog/2023/01/03/oregon-scientific-attiny85
 *
 * LICENCE
 *
 * Copyright © 2023 Stephen Humphries
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifndef OS21TX_H
#define OS21TX_H

// Example transmission data
// - Bytes are transmitted in order, small nibble first
// - Nibbles are transmitted LSB-first
// - Nibble descritions in this example are large nibble first, to align with the byte-wise representation
// - Sensor ID 1d20, Channel 1, Rolling ID bb, Battery low, Temperature 22.7°C, Humidity 30%
// uint8_t data[] = {
//   0xff, // Preamble (16 ones (transmitted as 32 bits, alternating 01))
//   0xff, // Preamble
//   0x1a, // Sensor ID (1d20) / Sync (0xa)
//   0x2d, // Sensor ID
//   0x20, // Channel (1=0x1, 2=0x2, 3=0x4) / Sensor ID
//   0xbb, // Rolling ID (randomly generated on startup)
//   0x7c, // Temperature, 10^-1 / Battery low (low is 0x4, not low is 0x0, but both are often OR'd with a 0x8 bit of unknown significance)
//   0x22, // Temperature, 10^1 / Temperature, 10^0
//   0x00, // Humidity, 10^0 / Temperature sign (largest 2 bits, 0x0 for +ve, 0x8 for -ve) | Temperature 10^2 (smallest 2 bits)
//   0x83, // Unknown / Humidity, 10^1
//   0x4a, // Checksum (simple sum)
//   0x55, // Postamble (CRC checksum)
// };

#define SUM_MASK 0xfffe0 // Only some nibbles are included in the checksum and CRC calculations
#define CRC_MASK 0xff3e0
#define CRC_IV 0x42 // ¯\_(ツ)_/¯ (see the blog post for details)
#define CRC_POLY 0x7 // CRC-8-CCITT

#define DATA_LEN 12

#include <avr/sleep.h>

class OS21Tx {
  public:
  const uint8_t pin;

  OS21Tx(uint8_t pin): pin(pin) {}

  void begin(uint8_t channel, uint8_t rollingId) {
    pinMode(pin, OUTPUT);

    setRollingId(rollingId);
    setChannel(channel);
  }

  void transmit(float temperature, float humidity, bool lowBattery = false) {
    setTemperature(temperature);
    setHumidity(humidity);
    setLowBattery(lowBattery);
    setChecksum();
    setCRC();

    sendData(); // Send the message twice
    delay(55); // Pause for a short time between transmissions
    sendData();
  }

  private:

  uint8_t old_TCCR0A;
  uint8_t old_TCCR0B;
  uint8_t old_OCR0A;
  uint8_t old_TIMSK;

  uint8_t data[DATA_LEN] = { // Data frame, initialized with the parts that never change
    0xff,            // Preamble
    0xff,
    0x1a,            // Sync nibble and sensor ID
    0x2d,
    0x00,
    0x00,
    0x08,            // Unknown
    0x00,
    0x00,
    0x80,            // Unknown
    0x00,
    0x00,
  };

  void setRollingId(uint8_t rollingId) {
    data[5] &= 0x00; data[5] |= (rollingId & 0xff);
  }

  void setChannel(uint8_t channel) {
    const uint8_t channelCode = (1 << (channel - 1)); // 1=0x1, 2=0x2, 3=0x4
    data[4] &= 0x0f; data[4] |= ((channelCode << 4) & 0xf0);
  }

  void setTemperature(float t) {
    const uint8_t t_sign = t < 0;
    const uint8_t t_deci = ((int)(t * (t_sign ? -10 : 10)) / 1) % 10;
    const uint8_t t_ones = ((int)(t * (t_sign ? -10 : 10)) / 10) % 10;
    const uint8_t t_tens = ((int)(t * (t_sign ? -10 : 10)) / 100) % 10;
    const uint8_t t_huns = ((int)(t * (t_sign ? -10 : 10)) / 1000) % 10;

    data[6] &= 0x0f; data[6] |= ((t_deci << 4) & 0xf0);
    data[7] &= 0xf0; data[7] |= ((t_ones << 0) & 0x0f);
    data[7] &= 0x0f; data[7] |= ((t_tens << 4) & 0xf0);
    data[8] &= 0xfc; data[8] |= ((t_huns << 0) & 0x03);
    data[8] &= 0xf3; data[8] |= ((t_sign << 3) & 0x0c);
  }

  void setHumidity(float h) {
    h += 0.5; // Round to the nearest one by adding 0.5 then truncating the decimal
    
    const uint8_t h_ones = ((int)(h * 10) / 10) % 10;
    const uint8_t h_tens = ((int)(h * 10) / 100) % 10;
  
    data[8] &= 0x0f; data[8] |= ((h_ones << 4) & 0xf0);
    data[9] &= 0xf0; data[9] |= ((h_tens << 0) & 0x0f);
  }

  void setLowBattery(bool b) {
    data[6] &= 0xf8; data[6] |= (b ? 0x4 : 0x0);
  }

  void setChecksum() {
    data[10] &= 0x00; data[10] |= (checksumSimple(data, SUM_MASK) & 0xff);
  }

  void setCRC() {
    data[11] &= 0x00; data[11] |= (checksumCRC(data, CRC_MASK, CRC_IV) & 0xff);
  }

  void sendData() {
    configureTimer();
    
    for (int i = 0; i < DATA_LEN * 8; ++i) { // Bits are transmitted LSB-first
      sendBit((data[i / 8] >> (i % 8)) & 0x1);
    }
    writeSyncBit(LOW); // Don't leave the transmitter on!

    restoreTimer();
  }

  void sendBit(bool val) {
    if (val) {
      sendZero(); // Recall that each bit is sent twice, inverted first
      sendOne();
    } else {        
      sendOne();
      sendZero();
    }
  }

  void sendZero() {
    writeSyncBit(LOW);
    writeSyncBit(HIGH);
  }
  
  void sendOne() {
    writeSyncBit(HIGH);
    writeSyncBit(LOW);
  }

  static uint8_t checksumSimple(const uint8_t data[], uint64_t mask) {
    uint16_t s = 0x0000;
  
    for (int i = 0; i < 64; ++i) {
      if (!((mask >> i) & 0x1)) continue; // Skip nibbles that aren't set in the mask
  
      s += (data[i / 2] >> ((i % 2) * 4)) & 0xf; // Sum data nibble by nibble
      s += (s >> 8) & 0x1; // Add any overflow back into the sum
      s &= 0xff;
    }
  
    return s;
  }

  
  static uint8_t checksumCRC(const uint8_t data[], uint64_t mask, uint8_t iv) {
    uint16_t s = iv;
  
    for (int i = 0; i < 64; ++i) {
      if (!((mask >> i) & 0x1)) continue; // Skip nibbles that aren't set in the mask
  
      uint8_t nibble = (data[i / 2] >> ((i % 2) * 4)) & 0xf;
  
      for (int j = 3; j >= 0; --j) {
        uint8_t bit = (nibble >> j) & 0x1;
  
        s <<= 1;
        s |= bit;
  
        if (s & 0x100) {
          s ^= CRC_POLY;
        }
      }
    }
  
    for (int i = 0; i < 8; ++i) {
      s <<= 1;
      if (s & 0x100) {
        s ^= CRC_POLY;
      }
    }
  
    return s;
  }

  void writeSyncBit(bool val) {
    // Synchronise writes to the 2048 Hz timer by sleeping until the timer interrupt
    // This works so long as there's less than 488 us worth of computation between write calls
    sleep_cpu(); // Sleep right before a pin change (rather than after) to ensure all edges are identically spaced
    digitalWrite(pin, val); 
  }

  void configureTimer() {
    old_TCCR0A = TCCR0A; // Save and restore Timer0 config since it's used by Arduino for delay()
    old_TCCR0B = TCCR0B;
    old_OCR0A = OCR0A;
    old_TIMSK = TIMSK;

    cli();
    TCCR0A = (1 << WGM01); // CTC (Clear Timer on Compare Match)
    TCCR0B = (1 << CS02) | (1 << CS01) | (1 << CS00); // External clock source on T0 pin
    OCR0A = 0xf; // Output compare register (32 768 Hz / 16 = 2 048 Hz)
    TIMSK = (1 << OCIE0A); // Interrupt on output compare match
    sei();

    set_sleep_mode(SLEEP_MODE_IDLE);
    sleep_enable();
  }

  void restoreTimer() {
    sleep_disable();
  
    cli();
    TCCR0A = old_TCCR0A;
    TCCR0B = old_TCCR0B;
    OCR0A = old_OCR0A;
    TIMSK = old_TIMSK;
    sei();
  }
};

ISR(TIMER0_COMPA_vect) {
  // Interrupt handler for TIMER0
  // Do nothing; just return control flow to where it was before sleeping
}

#endif /* OS21TX_H */
```
