---
title: Rigging up an automatic On-Air light for my work computer
---

Nobody wants to be interrupted in a work meeting or, worse, inadvertently star in the background of a partner or roommate's video call, so I imagine that other working-from-home people have also devised complex systems of hand/face/phone/eyebrow signals to silently communicate microphone and camera statuses at a distance. That's stone age tech, though; the broadcasting industry solved this problem decades ago by installing bright red "On Air" lights outside studio doors that indicate when a studio is in use.

I recently set up a slightly more subtle take on this concept for my office (read: corner): a small light that turns on automatically when a camera or microphone is active. I won't claim my solution elegant or even particularly good, but it does the job!

---

Although Amazon sells dozens of different brands of LED light strips, I couldn't find anybody selling individual USB-controlled LEDs. Oh well, at least I looked. I probably wouldn't have wanted to install whatever sketchy control software such a thing would require on my work computer anyway.

I soldered an RGB LED to a [very cheap Arduino-compatible microcontroller breakout board](https://www.aliexpress.com/item/2043055746.html) (a knock-off of the [Digispark](https://www.kickstarter.com/projects/digistump/digispark-the-tiny-arduino-enabled-usb-dev-board), which I don't think you can buy officially anymore), and wrote a quick sketch ([Arduino](https://www.arduino.cc/en/Guide/Introduction)-speak for program) to listen for colour codes sent over the USB cable. I also removed the board's built-in test and power LEDs, since the power indicator would annoyingly be on all the time and the test LED shared a circuit with one of pins I had to use for the RGB LED.

{% image /assets/images/blog/2022-04-24/digispark.jpg medium %}

The sketch (code below) is pretty simple; it listens for a colour code in typical 8-bit-per-colour RGB hex format (e.g. `ff0000` for red) and sets the three coloured LEDs to the appropriate brightnesses. The only complication was that the ATtiny85 microcontroller onboard the Digispark has only three [PWM](https://en.wikipedia.org/wiki/Pulse-width_modulation)-capable pins and one of them is used for USB purposes; the hacky software-based PWM implemented in my sketch is to get around that limitation (although, since I ended up only driving the LEDs at full duty cycles anyway, it ended up being overkill).

On the computer side of things, I wrote a quick script to monitor the log written by [Micro Snitch](https://obdev.at/products/microsnitch) (a little app that watches the status of connected microphones and cameras) and turn on the LED when a device becomes active. Based on a cursory search, I decided that figuring out how to check mic and camera statuses myself would be a waste of time when Micro Snitch does it so well. For USB communication, I used [DigiUSB](https://github.com/digistump/DigisparkArduinoIntegration/tree/master/libraries/DigisparkUSB), a firmware-only USB driver for the microcontroller that pairs with a [handy rubygem](https://rubygems.org/gems/digiusb/versions/1.0.5) to provide a serial-terminal-like interface between the computer and Digispark. Another library, DigiCDC, was supposed to be able to emulate a virtual serial device (which the computer could communicate with natively, no specific software required), but it didn't seem to be compatible with macOS.

I loaded the Arduino sketch onto the Digispark, set the ruby script to launch at login on my computer, and stuck the LED board to the back of my monitor, where it's in plain view as you approach my desk. (I added an origami waterbomb as a diffuser to soften the light a little bit.) Ta-da:

{% image /assets/images/blog/2022-04-24/on_air.jpg %}

---

*on_air.ino*:

{% highlight c++ linenos %}
#include <DigiUSB.h>

#define RED PB2
#define GREEN PB1
#define BLUE PB0

/* PWM STUFF */
/* Fake PWM because not all the pins we're using support it at the hardware level */
unsigned long lastPwmTime;
unsigned long pwmInterval = 20;

struct pwmPin {
  int pin;
  unsigned char pwm = 0;
  unsigned char tick = 0;
  pwmPin(int pin) : pin(pin) {}
};

pwmPin red = pwmPin(RED);
pwmPin green = pwmPin(GREEN);
pwmPin blue = pwmPin(BLUE);

const int pinsLength = 3;
pwmPin *pins[pinsLength] = { &red, &green, &blue };

void setupPwm() {
  for (int i = 0; i < pinsLength; ++i) {
    pinMode(pins[i]->pin, OUTPUT);
  }
  lastPwmTime = micros();
}

void loopPwm() {
  unsigned long currentTime = micros();
  if (currentTime - lastPwmTime > pwmInterval) {
    lastPwmTime = currentTime;
    for (int i = 0; i < pinsLength; ++i) {
      ++pins[i]->tick;
      digitalWrite(pins[i]->pin, (pins[i]->tick < pins[i]->pwm) ? HIGH : LOW);
    }
  }
}

/* DigiUSB STUFF */
/* Similar to how PWM is handled*/
unsigned long lastDigiUsbTime;
unsigned long digiUsbInterval = 2000;

const int inputLength = 6;
char input[inputLength]; // stores USB input
int currentInputIndex = 0;

void setupDigiUsb() {
  DigiUSB.begin();
  lastDigiUsbTime = micros();
}

void loopDigiUsb() {
  unsigned long currentTime = micros();
  if (currentTime - lastDigiUsbTime > digiUsbInterval) {
    lastDigiUsbTime = currentTime;
    if (DigiUSB.available()) {
      handleChar(DigiUSB.read());
    }
    DigiUSB.refresh();
  }
}

void handleChar(char c) {
  if (c == '\n') {
    if (currentInputIndex == inputLength) {
      red.pwm = byteFromHex(input[0], input[1]);
      green.pwm = byteFromHex(input[2], input[3]);
      blue.pwm = byteFromHex(input[4], input[5]);
    }
    currentInputIndex = 0;
  } else {
    if (currentInputIndex < inputLength) {
      input[currentInputIndex] = c;
    }
    ++currentInputIndex;
  }
}

unsigned char byteFromHex(char _16, char _1) {
  unsigned char x = 0;
  if ('0' <= _16 && _16 <= '9') {
    x += (_16 - '0') * 16;
  } else if ('a' <= _16 && _16 <= 'f') {
    x += (_16 - 'a' + 10) * 16;
  }
  if ('0' <= _1 && _1 <= '9') {
    x += (_1 - '0');
  } else if ('a' <= _1 && _1 <= 'f') {
    x += (_1 - 'a' + 10);
  }
  return x;
}

void setup() {
  setupPwm();
  setupDigiUsb();
}

void loop() {
  loopPwm();
  loopDigiUsb();
}
{% endhighlight %}


*on_air.rb*:

{% highlight ruby linenos %}
require "digiusb"
require "open3"

# [Micro Snitch](https://obdev.at/products/microsnitch) is an app that monitors and reports camera/microphone activity.
# This script tails Micro Snitch's log and updates an LED driven by an attached Digispark (an Arduino-compatible ATTiny85 breakout board)
# based on the camera and mic status.

# Requires:
# - libusb (`brew install libusb`)
# - digiusb (`gem install digiusb`)

# God bless https://zendesk.engineering/running-a-child-process-in-ruby-properly-febd0a2b6ec8
# for summarizing the various options for spawning a subprocess in Ruby.

LOG_FILE = "/Users/stephen/Library/Logs/Micro Snitch.log"
LOG_REGEX = /(?<type>Video|Audio) Device became (?<status>active|inactive): (?<device>.*)/

CAMERA_ON_COLOUR = "ff0000"
MICROPHONE_ON_COLOUR = "00ff00"
BOTH_ON_COLOUR = "ffff00"
BOTH_OFF_COLOUR = "000000"

microphones = {}
cameras = {}

digi = DigiUSB.connect()

Open3.popen2("tail", "-n0", "-f", LOG_FILE) do |_stdin, stdout, _wait_thr|
  stdout.each_line do |line|
    match = line.match(LOG_REGEX)
    if match
      devices = match[:type] ==  "Audio" ? microphones : cameras
      devices[match[:device]] = match[:status]

      digi.puts(
        if microphones.values.include?("active") && cameras.values.include?("active")
          BOTH_ON_COLOUR
        elsif microphones.values.include?("active")
          MICROPHONE_ON_COLOUR
        elsif cameras.values.include?("active")
          CAMERA_ON_COLOUR
        else
          BOTH_OFF_COLOUR
        end
      )
    end
  end
  puts("Something went wrong...")
end

{% endhighlight %}
