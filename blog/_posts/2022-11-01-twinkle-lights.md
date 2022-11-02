---
title: Twinkle lights
---

If you've read any of my recent posts, you'll probably have gathered that I find single-purpose remote controls annoying. It won't be a surprise, then, that when a string of twinkle lights controlled by an infrared remote ([basically these](https://www.amazon.ca/Mintlemon-Lighting-Dimmable-Backdrop-Tapestry/dp/B07W4H33V7/)) stopped turning on, I wasn't all that upset.

{% figure /assets/images/blog/2022-11-01/product_photo.jpg small %}
<i>Stolen from the linked Amazon listing</i>
{% endfigure %}

I had two problems with these lights:

1. I hate remotes.
2. The controller had no persistent storage, so the power and mode states reset every time the light string was unplugged. This was unsurprising and even perfectly reasonable, but it meant that I couldn't replace the remote with a simple analog lamp timer.

Since I had ESP32 dev boards and recent experience with HomeKit left over from my [last project](2022-10-04-wifi-vacuum.md), it was easy enough to replace the broken LED controller, trading infrared control for Wi-Fi and Siri/Home app support.

{% image /assets/images/blog/2022-11-01/usb_top.jpg tiny %}
{% image /assets/images/blog/2022-11-01/usb_bottom.jpg tiny %}

{% image /assets/images/blog/2022-11-01/led.jpg tiny %}

The light string consists of 100 LEDs wired in parallel between two thin enamelled wires (originally attached at L1 and L2 on the stock controller pictured above). In some two-wire light strips, each LED is controlled by a tiny addressable chip, but this light string is less complicated and probably much cheaper. There's nothing special about the LEDs, but the polarity of every other one is reversed, so only half the string lights up at a time depending on which direction direction current is applied in. This enables some basic alternating patterns; to produce the illusion of lighting up the entire string at once, you just have to switch back and forth really fast.

According to the [datasheet](https://www.espressif.com/sites/default/files/documentation/esp32_datasheet_en.pdf), the ESP32's GPIO pins are rated for 40 mA source and 28 mA sink current. I found that at 3.3 V and with a 33 Ω resistor in series, the LED string drew 21 mA, safely within the acceptable range.

{% image /assets/images/blog/2022-11-01/current.jpg small %}

I soldered the LED string and resistor to the ESP32 and wrote a relatively simple Arduino + [HomeSpan](https://github.com/HomeSpan/HomeSpan) sketch to control the lights. It presents them to HomeKit as a single light bulb which can be on or off and have a brightness from 1 to 8, each step increasing the frequency of switching between the two sets of LEDs (the fastest/brightest setting appears solid).

{% image /assets/images/blog/2022-11-01/soldering.jpg small %}

It works pretty well, with a few potential areas for improvement (at least this time the ESP32 is easily accessible for reprogramming):

1. The LEDs are a bit dimmer than they were with the stock controller. I might try to bump up the current  by adding a couple transistors to drive the LEDs, rather than powering them directly from the GPIO pins.
2. I didn't implement any of the fancy brightness fading patterns that the stock controller supported, just simple flashing.
3. Why not add support for the infrared remote? 🤷

### `led_string.ino`

{% highlight c++ linenos %}
#include "HomeSpan.h"
#include <nvs_flash.h>

#include "DEV_LedString.h"

#define STATUS_LED_PIN 2
#define RESET_BUTTON_PIN 13
#define STATUS_AUTO_OFF 300
#define AP_AUTO_OFF 300
#define WEBLOG_ENTRIES 25
#define LOG_LEVEL 0

#define LED1 22
#define LED2 23

void setup() {
  Serial.begin(115200);

  configureResetButton();
  configureHomeSpan();
}

void loop() {
  pollResetButton();
  homeSpan.poll();
}

void configureHomeSpan() {
  homeSpan.setStatusPin(STATUS_LED_PIN);
  homeSpan.setStatusAutoOff(STATUS_AUTO_OFF);

  homeSpan.enableWebLog(WEBLOG_ENTRIES,"pool.ntp.org","UTC","log");
  homeSpan.setLogLevel(LOG_LEVEL);

  homeSpan.setApSSID("LEDString-Setup");
  homeSpan.setApTimeout(AP_AUTO_OFF);
  homeSpan.enableAutoStartAP();

  homeSpan.begin(Category::Lighting, "LED String", "LEDString", "LEDString");

  new SpanAccessory();
  
    new Service::AccessoryInformation();
      new Characteristic::Identify();

    new DEV_LedString(LED1, LED2);
}

void configureResetButton() {
  pinMode(RESET_BUTTON_PIN, INPUT_PULLUP);
}

void pollResetButton() {
  if (digitalRead(RESET_BUTTON_PIN) == LOW) {
    Serial.print("\n*** Clearing non-volatile storage and restarting...\n\n");
    nvs_flash_erase();
    ESP.restart();
  }
}
{% endhighlight %}

### `DEV_LedString.h`

{% highlight c++ linenos %}
#define FLICKER_STEPS 8

const uint32_t steps[FLICKER_STEPS] = {
  10,
  100,
  200,
  400,
  800,
  1600,
  3200,
  6400,
};

struct DEV_LedString : Service::LightBulb {
  uint8_t pin1;
  uint8_t pin2;
  
  SpanCharacteristic *power;
  SpanCharacteristic *level;

  uint32_t wait;
  uint32_t timer;

  bool ledMode = false;

  DEV_LedString(uint8_t pin1, uint8_t pin2) : Service::LightBulb() {
    this->pin1 = pin1;
    this->pin2 = pin2;

    pinMode(pin1, OUTPUT);
    pinMode(pin2, OUTPUT);
    
    this->power = new Characteristic::On(false, true);
    this->level = new Characteristic::Brightness(FLICKER_STEPS, true);
    level->setRange(0, FLICKER_STEPS, 1);

    switchLeds();
  }

  bool update() {
    WEBLOG("Setting power to %s, level to %d", power->getNewVal() ? "ON" : "OFF", level->getNewVal());
    switchLeds();
    return true;
  }

  void loop() {
    if (power->getVal()) {
      if (checkTimer()) {
        switchLeds();
      }
    } else {
      digitalWrite(pin1, LOW);
      digitalWrite(pin2, LOW);
    }
  }

  bool checkTimer() {
    return millis() - timer > wait;
  }

  void switchLeds() {
    ledMode = !ledMode;
    digitalWrite(pin1, ledMode);
    digitalWrite(pin2, !ledMode);

    wait = steps[FLICKER_STEPS - level->getNewVal()];
    timer = millis();
  }
};
{% endhighlight %}
