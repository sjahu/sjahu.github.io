---
title: Forwarding HDMI CEC volume control messages to my TV
header_image: /assets/images/blog/2022-04-06/setup.jpg
header_image_caption: not so smart after all
---

In a recent article [shared on Hacker News](https://news.ycombinator.com/item?id=30869140), the author detailed his attempt at creating [the smallest and worst HDMI display](https://mitxela.com/projects/ddc-oled) by abusing the i<sup>2</sup>c bus that powers the Display Data Channel protocol. The comments prompted me to read up on another constituent protocol of HDMI that I had, up to that point, taken for granted: [Consumer Electronics Control](https://en.wikipedia.org/wiki/Consumer_Electronics_Control) (CEC).

## Nirvana

CEC is a feature that enables HDMI-connected devices to communicate over a single-wire serial bus separate from all the other signals carried by the cable. I use it to have my TV turn on and switch to the correct input when the Apple TV 4K plugged into it turns on, and off when it turns off. Combined with the learning infrared repeater built in to the Apple TV's remote, with this setup I have achieved "single remote nirvana": power on and off via HDMI CEC and volume control via infrared. Day to day, I mostly use my iPhone's built-in remote app and only reach for the Apple TV remote when I need to change the volume. This is a nice configuration, but, since buying the TV, I've dreampt of an even more idyllic state of "zero remote nirvana" in which I could control the TV entirely from my phone.

According to [Apple's docs](https://support.apple.com/en-ca/guide/tv/atvb701cadc1/tvos), if my TV supported volume control via CEC, I should have been able to use the volume buttons on my phone to increase or decrease the volume. Since this has never worked and since the volume icon in the remote app has always been greyed out, I deduced that the TV must not support that feature. What if I added a device to the CEC bus to intercept volume control commands from the Apple TV and repeat them via infrared to the TV?

## Easy as pi?

Having read one Wikipedia article on the protocol and thus considering myself somewhat of an expert, I figured that couldn't be *that* hard to do. A quick search turned up an excellent [forum thread](https://forum.arduino.cc/t/hdmi-cec-interface/22401) from 2009 that had ultimately produced a library and circuit schematic for interacting with CEC from an Arduino microcontroller. An Arduino would conveniently also be the perfect platform for driving an infrared LED, but another search turned up a potentially simpler option: a [USB - CEC Adapter](https://www.pulse-eight.com/p/104/usb-hdmi-cec-adapter) from a company called Pulse-Eight. Using the pre-made adapter controlled by a small computer like a Raspberry Pi, the necessary circuitry would be limited to one LED and a resistor, which is much more at my level of electrical engineering.

Hold on-- doesn't a Raspberry Pi have an HDMI output onboard anyway? Yes it does, and from looking at the specs, it supports CEC (not all HDMI devices do). Even better, Pulse-Eight's [`libcec`](https://github.com/Pulse-Eight/libcec) library supports the Raspberry Pi, with no adapter necessary, out of the box. Encouraged, I ordered a mini-HDMI to HDMI cable, a 30 pack of IR emitter and receiver diodes, and an absurd quantity of various resistors (I needed a single ~200Ω resistor to limit the LED to a safe current of 16 mA-- any greater draw than that from one GPIO pin could damage the Pi). I already had a [Raspberry Pi Zero](https://www.raspberrypi.com/products/raspberry-pi-zero/) and was excited to have finally found a purpose for it that didn't require Wi-Fi or ethernet, neither of which it has.

I downloaded the latest headless version of [Raspberry Pi OS](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-32-bit), flashed it to a micro SD card, and configured the OS to [allow SSH connections over the USB cable](https://learn.adafruit.com/turning-your-raspberry-pi-zero-into-a-usb-gadget) (technically, that means enabling USB On-The-Go and the `g_ether` kernel module). Once I had managed to find a micro USB cable that wasn't power-only, I was able to connect to the Pi from my laptop.

![](/assets/images/blog/2022-04-06/setup.jpg)

Pulse-Eight bundles `libcec` in a package called [`cec-utils`](https://packages.debian.org/bullseye/cec-utils), which also contains a demo client program, `cec-client`. The help docs for `cec-client`, which describe what it can do, can be found [here](https://github.com/Pulse-Eight/libcec/blob/76551ea1dd9a55f0ce1533e440dc12dbc594f7ba/src/cec-client/cec-client.cpp#L291-L365) or be printed out by the program itself.

I started `cec-client` and began to play around. With `cec-client` in monitoring mode (`-m`), I noticed that the Apple TV wouldn't even try to send volume up/down commands to the TV. With `cec-client` started in Audio System mode (`-t a`), in which it pretends to be an audio system (for CEC purposes only), the Apple TV happily sent volume control commands to my Raspberry Pi. Great, I thought; this might actually work.

---

### Aside

CEC frames consist of a series of bytes. The first two [nibbles](https://en.wikipedia.org/wiki/Nibble) in a message indicate, respectively, the source and destination device; the second byte is the opcode; and subsequent bytes are other data, as required, depending on the operation. Each byte is immediately followed by an end-of-message bit, used to indicate the end of a frame, and an acknowledge bit, which is set by the receiver to acknowledge the transmission. A frame containing only a source and destination acts like a ping; the sender can detect if a recipient is present based on whether it acknowledges the transmission. The 4-bit addresses used in the first byte of a CEC frame are logical addresses based on the role of the device, not the hierarchical addresses used to map the physical connections between devices. For my use case, the three relevant addresses will always be the same: `0` for the TV, `4` for Playback 1 (the Apple TV), and `5` for Audio System (the Raspberry Pi). A neat tool, [CEC-O-MATIC](https://www.cec-o-matic.com/), shows the 16 possible logical addresses (`f` is used for broadcast) and can also generate or decode any CEC frame.

---

![](/assets/images/blog/2022-04-06/cec-client.png)

The CEC frame sent from the Apple TV to the Raspberry Pi to turn up the volume looks like this: `45:44:41`. `45` for "Device 4 (Playback 1) to Device 5 (Audio System)", `44` for "User Control Pressed", and `41` for "Volume Up". On a whim, I tried transmitting a similar frame, `50:44:41`, using `cec-client`'s `tx` command. To my surprise, this did exactly what it should have: it turned up the volume on the TV, no infrared necessary. I thought, well that's weird, but I'll take it. This development would make things much easier; instead of wiring up the infrared LED and figuring out how to record and play back the right signals, I could just forward commands received by the Raspberry Pi directly to the TV via CEC.

I wrote a quick little Python script to wrap `cec-client` and forward key presses sent by the Apple TV (see it at the bottom of the page). Using `libcec` directly would be more pure, but this was quicker, and particularly nice because `cec-client` handles responding to the various status/device info/vendor info/etc messages that a device must accept. I tried it out, and it worked! I was able to control the TV volume from my iPhone. Mission accomplished. I added my script to `/etc/rc.local`, rebooted the Raspberry Pi, and watched the script start automatically with output sent to TTY1 (displayed on the TV via the non-CEC HDMI channels).

The CEC volume control had noticeably more latency than the infrared remote, which changed the volume virtually instantaneously. This might be marginally improved by replacing my text-scraping script with a proper library-based CEC client implementation, but each 3-byte frame takes about 90 ms to transmit, so, doubling that to account for repeating the message, there's a strict 180 ms lower bound on performance anyway. It's still only a small fraction of a second, so I decided I could live with it.

![](/assets/images/blog/2022-04-06/demo.jpg)

## Almost there...

Not everything was perfect, though. I quickly noticed that the Apple TV would only send volume control messages to the Raspberry Pi the first time it booted up. After a sleep/wake cycle, it would grey out the volume buttons in the remote app and revert to infrared-only volume control. With the Apple TV unplugged, I restarted `cec-client` to take a trace of the messages being sent. I plugged in the Apple TV, let it boot up, put it to sleep, then woke it up. As before, the volume control from my iPhone was available only from the initial boot till when the Apple TV was awoken from sleep.

Perusing the output from the trace, I discovered that there was a difference between the initial state and the post-wakeup state. In the initial state, the "System Audio Mode Status" (used to indicate whether an audio system is being used or not) was "on". While starting up, the Apple TV queried this status by sending the frame `45:7d` ("Device 4 to Device 5, Give System Audio Mode Status") and received `54:7e:01` ("Device 5 to Device 4, System Audio Mode Status, On") in response. When the Apple TV went to sleep, it informed the other devices that it was entering standby mode, which caused the TV to enter standby mode and the audio system being emulated by `cec-client` to set the System Audio Mode Status to "off". When the Apple TV was woken up, the very first thing it tried to do was query the System Audio Mode Status with the same `45:7d` message seen before. At this point, only the Apple TV was on, so `cec-client` responded truthfully with `54:7e:00` ("off"), causing the Apple TV to disable the volume control feature. Had the Apple TV waited to ask for the status till after it had turned on the TV (which set the System Audio Mode to "on"), or had it listened in to the messages later exchanged between the Audio System and the TV, it would have known that System Audio Mode was in fact enabled.

I thought, at this point, that I might have to implement my own client using `libcec` after all in order to be able to tell the Apple TV that the System Audio Mode Status was "on" when it was really "off". Luckily, though, the Apple TV was willing to accept an unsolicited `54:7e:01` frame even after its initial wake-up routine which immediately made the volume control in the iPhone remote available. I updated my script to listen for any `54:7e:00` frame and immediately follow it up with `54:7e:01`. This solved the problem without having to drop down a level. Very nice.

![](/assets/images/blog/2022-04-06/tidy.jpg)
## Why?

It's not totally clear to me who's to blame for the incompatibility between the Apple TV and my TV, which is manufactured by TCL and runs a Roku operating system. The Apple TV seems to always send a `45:7d` frame when it wakes up and only enables the volume control feature if that message is both acknowledged and elicits a `54:7e:01` response. The TV could accommodate this behaviour by advertising itself as an Audio System (when no external amplifier is connected) as well as as a TV; the same physical device can be multiple CEC logical devices. Alternatively, to determine whether volume control is supported, the Apple TV could attempt to send a volume control frame to the TV, which could accept it or refuse it via a `00` abort message. I'm far from an expert, but I suspect the Apple TV is correct in its implementation (aside from its deficiency in checking the system audio status before turning any of the devices on-- that's a bug, in my opinion). System Audio Mode appears to be designed with external audio systems in mind, so it seems reasonable for the Apple TV to assume that any controllable audio system would respond to messages sent to Device 5.

Either way, I'm thrilled that this worked and I'm settling happily in to zero remote nirvana.

---

![](/assets/images/blog/2022-04-06/diagram.png)

---

*cec_vol.py*:

{% highlight python linenos %}

#!/usr/bin/python3

# My Apple TV won't send HDMI CEC volume control commands to my TV, seemingly because the TV
# doesn't advertise itself as an audio sink. This program wraps cec-client, which pretends to
# be an audio system, and forwards volume up/down commands that it receives from the Apple TV
# to the TV.

# Launch automatically after boot by calling this script from /etc/rc.local

import re
import subprocess
from subprocess import Popen, PIPE

# CEC constants
TV = "0"
PLAYBACK_1 = "4"
AUDIO_SYSTEM= "5"
USER_CONTROL_PRESSED = "44"
USER_CONTROL_RELEASED = "45"
SYSTEM_AUDIO_MODE_STATUS = "7e"
SYSTEM_AUDIO_MODE_STATUS_OFF = "00"
SYSTEM_AUDIO_MODE_STATUS_ON = "01"

# Colour constants
RED = "\033[1;31m"
BLUE = "\033[1;34m"
NCOL = "\033[0m"

# Start cec-client with device type AUDIO_SYSTEM
proc = Popen(["cec-client", "-t", "a"], stdin=PIPE, stdout=PIPE)

# Listen to the output from cec-client
for line_bytes in proc.stdout:
  line = line_bytes.decode()

  # Match sent or received CEC frames
  frame = re.search(
    "^TRAFFIC:.*(?:>>|<<) (?P<src>[0-9a-f])(?P<dest>[0-9a-f]):(?P<op>[0-9a-f]{2})(?P<data>(?::[0-9a-f]{2})*)",
    line
  )

  if (
    frame
    and frame.group("src") == PLAYBACK_1
    and frame.group("dest") == AUDIO_SYSTEM
    and frame.group("op") in [USER_CONTROL_PRESSED, USER_CONTROL_RELEASED]
  ):
    # Forward any keypresses sent from PLAYBACK_1 to AUDIO_SYSTEM to TV
    out = AUDIO_SYSTEM + TV + ":" + frame.group("op") + frame.group("data")
  elif (
    frame
    and frame.group("src") == AUDIO_SYSTEM
    and frame.group("dest") == PLAYBACK_1
    and frame.group("op") == SYSTEM_AUDIO_MODE_STATUS
    and frame.group("data") == ":" + SYSTEM_AUDIO_MODE_STATUS_OFF
  ):
    # If cec-client tells PLAYBACK_1 that the system audio mode status is "off", immediately send
    # another message indicating that it's really "on". Although a lie, this is necessary because,
    # for some reason, the Apple TV queries the system audio mode status FIRST thing after waking
    # up, before even turning the TV on or setting itself as the active source. At that point, of
    # course the system audio mode status is "off", because it's the TV that sets it to "on" after
    # it is itself woken up. The Apple TV never asks for the status again and ignores messages
    # between the TV and AUDIO_SYSTEM setting the status to "on". It assumes, incorrectly, that
    # the status at the time it was awoken is permanent.
    out = AUDIO_SYSTEM + PLAYBACK_1 + ":" + SYSTEM_AUDIO_MODE_STATUS + ":" + SYSTEM_AUDIO_MODE_STATUS_ON
  else:
    out = None

  # Print output with important lines coloured
  if out:
    proc.stdin.write(("tx " + out + "\n").encode())
    proc.stdin.flush()

    print(BLUE + line + NCOL, end="")
    print(RED + "Sending frame: " + out + NCOL)
  else:
    print(line, end="")


{% endhighlight %}

---

This is the log trace that I used to figure out why volume controls weren't available after sleeping and waking the Apple TV:

```
pi@raspberrypi:~ $ cec-client -t a
== using device type 'audio system'
CEC Parser created - libCEC version 6.0.2
no serial port given. trying autodetect:
 path:     /sys/devices/platform/soc/20902000.hdmi/cec0
 com port: /dev/cec0

opening a connection to the CEC adapter...
DEBUG:   [             195]	Broadcast (F): osd name set to 'Broadcast'
DEBUG:   [             198]	CLinuxCECAdapterCommunication::Open - m_path=/dev/cec0 m_fd=4 bStartListening=1
DEBUG:   [             199]	CLinuxCECAdapterCommunication::Open - ioctl CEC_ADAP_G_PHYS_ADDR - addr=2000
DEBUG:   [             201]	CLinuxCECAdapterCommunication::Open - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=0000 num_log_addrs=0
DEBUG:   [             203]	CLinuxCECAdapterCommunication::Open - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=8000 num_log_addrs=1
NOTICE:  [             205]	connection opened
DEBUG:   [             208]	CLinuxCECAdapterCommunication::Process - CEC_DQEVENT - CEC_EVENT_STATE_CHANGE - log_addr_mask=8000 phys_addr=2000
DEBUG:   [             210]	<< Broadcast (F) -> TV (0): POLL
TRAFFIC: [             211]	<< f0
DEBUG:   [             212]	processor thread started
DEBUG:   [             510]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=1 addr=f0 opcode=ffffffff
DEBUG:   [             510]	>> POLL sent
DEBUG:   [             510]	TV (0): device status changed into 'present'
DEBUG:   [             510]	<< requesting vendor ID of 'TV' (0)
TRAFFIC: [             510]	<< f0:8c
DEBUG:   [             577]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=2 addr=f0 opcode=8c
DEBUG:   [            1577]	expected response not received (87: device vendor id)
TRAFFIC: [            1577]	<< f0:8c
DEBUG:   [            1630]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=2 addr=f0 opcode=8c
DEBUG:   [            2630]	expected response not received (87: device vendor id)
DEBUG:   [            2631]	registering new CEC client - v6.0.2
DEBUG:   [            2631]	SetClientVersion - using client version '6.0.2'
NOTICE:  [            2631]	setting HDMI port to 1 on device TV (0)
DEBUG:   [            2631]	SetConfiguration: double tap timeout = 200ms, repeat rate = 0ms, release delay = 500ms
DEBUG:   [            2631]	detecting logical address for type 'audiosystem'
DEBUG:   [            2631]	trying logical address 'Audio'
DEBUG:   [            2631]	<< Audio (5) -> Audio (5): POLL
TRAFFIC: [            2631]	<< 55
DEBUG:   [            2693]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=1 addr=55 opcode=ffffffff
TRAFFIC: [            2693]	<< 55
DEBUG:   [            2765]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=1 addr=55 opcode=ffffffff
DEBUG:   [            2765]	>> POLL not sent
DEBUG:   [            2765]	using logical address 'Audio'
DEBUG:   [            2765]	Audio (5): device status changed into 'handled by libCEC'
DEBUG:   [            2765]	Audio (5): power status changed from 'unknown' to 'on'
DEBUG:   [            2765]	Audio (5): vendor = Pulse Eight (001582)
DEBUG:   [            2765]	Audio (5): CEC version 1.4
DEBUG:   [            2765]	AllocateLogicalAddresses - device '0', type 'audio system', LA '5'
DEBUG:   [            2765]	CLinuxCECAdapterCommunication::SetLogicalAddresses - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=0000 num_log_addrs=0
DEBUG:   [            2772]	CLinuxCECAdapterCommunication::Process - CEC_DQEVENT - CEC_EVENT_STATE_CHANGE - log_addr_mask=0000 phys_addr=2000
DEBUG:   [            2908]	CLinuxCECAdapterCommunication::SetLogicalAddresses - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=0020 num_log_addrs=1
DEBUG:   [            2908]	Audio (5): osd name set to 'CECTester'
DEBUG:   [            2908]	Audio (5): menu language set to 'eng'
DEBUG:   [            2908]	using auto-detected physical address 2000
DEBUG:   [            2908]	Audio (5): physical address changed from ffff to 2000
DEBUG:   [            2908]	<< Audio (5) -> broadcast (F): physical address 2000
TRAFFIC: [            2908]	<< 5f:84:20:00:05
DEBUG:   [            2909]	CLinuxCECAdapterCommunication::Process - CEC_DQEVENT - CEC_EVENT_STATE_CHANGE - log_addr_mask=0020 phys_addr=2000
DEBUG:   [            3319]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=5 addr=5f opcode=84
NOTICE:  [            3320]	CEC client registered: libCEC version = 6.0.2, client version = 6.0.2, firmware version = 0, logical address(es) = Audio (5) , physical address: 2.0.0.0, compiled on Linux-5.10.63-v8+ ... , features: P8_USB, DRM, P8_detect, randr, RPi, Exynos, Linux, AOCEC
DEBUG:   [            3320]	<< Audio (5) -> TV (0): OSD name 'CECTester'
TRAFFIC: [            3320]	<< 50:47:43:45:43:54:65:73:74:65:72
DEBUG:   [            3602]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=11 addr=50 opcode=47
DEBUG:   [            3603]	<< requesting power status of 'TV' (0)
TRAFFIC: [            3603]	<< 50:8f
DEBUG:   [            3669]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=2 addr=50 opcode=8f
waiting for input
DEBUG:   [            3765]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=3 addr=05 opcode=90
TRAFFIC: [            3765]	>> 05:90:01
DEBUG:   [            3765]	TV (0): power status changed from 'unknown' to 'standby'
DEBUG:   [            3765]	expected response received (90: report power status)
DEBUG:   [            3770]	>> TV (0) -> Audio (5): report power status (90)




# PLUGGING IN APPLE TV




DEBUG:   [           57445]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=45 opcode=83
TRAFFIC: [           57447]	>> 45:83
DEBUG:   [           57447]	<< Audio (5) -> broadcast (F): physical address 2000
TRAFFIC: [           57447]	<< 5f:84:20:00:05
DEBUG:   [           57453]	>> Playback 1 (4) -> Audio (5): give physical address (83)
DEBUG:   [           57580]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=5 addr=5f opcode=84
DEBUG:   [           57580]	device Playback 1 (4) status changed to present after command give physical address
DEBUG:   [           57740]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=6 addr=4f opcode=a6
TRAFFIC: [           57740]	>> 4f:a6:06:10:56:10
DEBUG:   [           57744]	>> Playback 1 (4) -> Broadcast (F): UNKNOWN (A6)
DEBUG:   [           57891]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=5 addr=4f opcode=84
TRAFFIC: [           57891]	>> 4f:84:10:00:04
DEBUG:   [           57891]	Playback 1 (4): physical address changed from ffff to 1000
DEBUG:   [           57895]	>> Playback 1 (4) -> Broadcast (F): report physical address (84)
DEBUG:   [           57986]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=4f opcode=85
TRAFFIC: [           57987]	>> 4f:85
DEBUG:   [           57987]	>> 4 requests active source
DEBUG:   [           57987]	Playback 1 (4): power status changed from 'unknown' to 'on'
DEBUG:   [           57987]	<< Audio (5) is not the active source
DEBUG:   [           57991]	>> Playback 1 (4) -> Broadcast (F): request active source (85)
DEBUG:   [           58298]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=45 opcode=7d
TRAFFIC: [           58298]	>> 45:7d
DEBUG:   [           58298]	<< 5 -> 4: system audio mode 'on'
TRAFFIC: [           58299]	<< 54:7e:01
DEBUG:   [           58303]	>> Playback 1 (4) -> Audio (5): give audio mode status (7D)
DEBUG:   [           58442]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=3 addr=54 opcode=7e
TRAFFIC: [           58442]	<< 54:7e:01
DEBUG:   [           58584]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=3 addr=54 opcode=7e
DEBUG:   [           58832]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=45 opcode=83
TRAFFIC: [           58832]	>> 45:83
DEBUG:   [           58832]	<< Audio (5) -> broadcast (F): physical address 2000
TRAFFIC: [           58832]	<< 5f:84:20:00:05
DEBUG:   [           58835]	>> Playback 1 (4) -> Audio (5): give physical address (83)
DEBUG:   [           58966]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=5 addr=5f opcode=84
DEBUG:   [           59126]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=6 addr=4f opcode=a6
TRAFFIC: [           59127]	>> 4f:a6:06:10:56:10
DEBUG:   [           59130]	>> Playback 1 (4) -> Broadcast (F): UNKNOWN (A6)
DEBUG:   [           59277]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=5 addr=4f opcode=84
TRAFFIC: [           59277]	>> 4f:84:10:00:04
DEBUG:   [           59280]	>> Playback 1 (4) -> Broadcast (F): report physical address (84)
DEBUG:   [           59359]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=4f opcode=85
TRAFFIC: [           59359]	>> 4f:85
DEBUG:   [           59360]	>> 4 requests active source
DEBUG:   [           59360]	<< Audio (5) is not the active source
DEBUG:   [           59364]	>> Playback 1 (4) -> Broadcast (F): request active source (85)
DEBUG:   [           59544]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=45 opcode=7d
TRAFFIC: [           59544]	>> 45:7d
DEBUG:   [           59544]	<< 5 -> 4: system audio mode 'on'
TRAFFIC: [           59545]	<< 54:7e:01
DEBUG:   [           59549]	>> Playback 1 (4) -> Audio (5): give audio mode status (7D)
DEBUG:   [           59631]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=3 addr=54 opcode=7e
DEBUG:   [           59695]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=45 opcode=83
TRAFFIC: [           59695]	>> 45:83
DEBUG:   [           59695]	<< Audio (5) -> broadcast (F): physical address 2000
TRAFFIC: [           59695]	<< 5f:84:20:00:05
DEBUG:   [           59698]	>> Playback 1 (4) -> Audio (5): give physical address (83)
DEBUG:   [           59830]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=5 addr=5f opcode=84
DEBUG:   [           59893]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=45 opcode=8f
TRAFFIC: [           59894]	>> 45:8f
DEBUG:   [           59894]	<< Audio (5) -> Playback 1 (4): on
TRAFFIC: [           59894]	<< 54:90:00
DEBUG:   [           59897]	>> Playback 1 (4) -> Audio (5): give device power status (8F)
DEBUG:   [           59980]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=3 addr=54 opcode=90
DEBUG:   [           60044]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=45 opcode=9f
TRAFFIC: [           60044]	>> 45:9f
DEBUG:   [           60045]	<< Audio (5) -> Playback 1 (4): cec version 1.4
TRAFFIC: [           60045]	<< 54:9e:05
DEBUG:   [           60048]	>> Playback 1 (4) -> Audio (5): get cec version (9F)
DEBUG:   [           60131]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=3 addr=54 opcode=9e
DEBUG:   [           60195]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=45 opcode=8c
TRAFFIC: [           60195]	>> 45:8c
DEBUG:   [           60195]	<< Audio (5) -> Playback 1 (4): vendor id Pulse Eight (1582)
TRAFFIC: [           60195]	<< 5f:87:00:15:82
DEBUG:   [           60199]	>> Playback 1 (4) -> Audio (5): give device vendor id (8C)
DEBUG:   [           60330]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=5 addr=5f opcode=87




# AUDIO CONTROL FROM APPLE TV IS AVAILBLE (SHOWS ON CONTROL). WAKING UP APPLE TV...




DEBUG:   [          127007]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=4 addr=4f opcode=82
TRAFFIC: [          127008]	>> 4f:82:10:00
DEBUG:   [          127008]	making Playback 1 (4) the active source
DEBUG:   [          127008]	TV (0): power status changed from 'standby' to 'in transition from standby to on'
DEBUG:   [          127016]	>> Playback 1 (4) -> Broadcast (F): active source (82)
DEBUG:   [          127074]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=0f opcode=85
TRAFFIC: [          127074]	>> 0f:85
DEBUG:   [          127074]	>> 0 requests active source
DEBUG:   [          127074]	TV (0): power status changed from 'in transition from standby to on' to 'on'
DEBUG:   [          127074]	<< Audio (5) is not the active source
DEBUG:   [          127079]	>> TV (0) -> Broadcast (F): request active source (85)
DEBUG:   [          127293]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=4 addr=05 opcode=70
TRAFFIC: [          127293]	>> 05:70:00:00
DEBUG:   [          127293]	making TV (0) the active source
DEBUG:   [          127294]	marking Playback 1 (4) as inactive source
DEBUG:   [          127294]	<< 5 -> 0: set system audio mode '7f'
TRAFFIC: [          127294]	<< 50:72:01
DEBUG:   [          127298]	>> TV (0) -> Audio (5): system audio mode request (70)
DEBUG:   [          127380]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=3 addr=50 opcode=72
DEBUG:   [          127492]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=4 addr=4f opcode=82
TRAFFIC: [          127492]	>> 4f:82:10:00
DEBUG:   [          127492]	making Playback 1 (4) the active source
DEBUG:   [          127492]	marking TV (0) as inactive source
DEBUG:   [          127496]	>> Playback 1 (4) -> Broadcast (F): active source (82)
DEBUG:   [          127609]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=05 opcode=7d
TRAFFIC: [          127609]	>> 05:7d
DEBUG:   [          127610]	<< 5 -> 0: system audio mode 'on'
TRAFFIC: [          127610]	<< 50:7e:01
DEBUG:   [          127613]	>> TV (0) -> Audio (5): give audio mode status (7D)
DEBUG:   [          127696]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=3 addr=50 opcode=7e
DEBUG:   [          127780]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=05 opcode=83
TRAFFIC: [          127780]	>> 05:83
DEBUG:   [          127780]	<< Audio (5) -> broadcast (F): physical address 2000
TRAFFIC: [          127780]	<< 5f:84:20:00:05
DEBUG:   [          127784]	>> TV (0) -> Audio (5): give physical address (83)
DEBUG:   [          127915]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=5 addr=5f opcode=84
DEBUG:   [          127991]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=05 opcode=8c
TRAFFIC: [          127991]	>> 05:8c
DEBUG:   [          127991]	<< Audio (5) -> TV (0): vendor id Pulse Eight (1582)
TRAFFIC: [          127991]	<< 5f:87:00:15:82
DEBUG:   [          127995]	>> TV (0) -> Audio (5): give device vendor id (8C)
DEBUG:   [          128125]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=5 addr=5f opcode=87
DEBUG:   [          128192]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=05 opcode=46
TRAFFIC: [          128192]	>> 05:46
DEBUG:   [          128192]	<< Audio (5) -> TV (0): OSD name 'CECTester'
TRAFFIC: [          128193]	<< 50:47:43:45:43:54:65:73:74:65:72
DEBUG:   [          128196]	>> TV (0) -> Audio (5): give osd name (46)
DEBUG:   [          128471]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=11 addr=50 opcode=47
DEBUG:   [          128685]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=7 addr=05 opcode=a0
TRAFFIC: [          128686]	>> 05:a0:8a:c7:2e:10:18
DEBUG:   [          128686]	TV (0): vendor = Unknown (8ac72e)
DEBUG:   [          128686]	sending abort with opcode a0 and reason 'invalid operand' to TV
DEBUG:   [          128686]	<< transmitting abort message
TRAFFIC: [          128686]	<< 50:00:a0:03
DEBUG:   [          128689]	>> TV (0) -> Audio (5): vendor command with id (A0)
DEBUG:   [          128796]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
NOTICE:  [          128796]	Unmapped code detected. Please send an email to support@pulse-eight.com with the following details, and if you pressed a key, tell us which one you pressed, and we'll add support for this it.
CEC command: >> 05:a0:8a:c7:2e:10:18
Vendor ID: Unknown (000000)
DEBUG:   [          129156]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=6 addr=0f opcode=80
TRAFFIC: [          129156]	>> 0f:80:00:00:10:00
DEBUG:   [          129161]	>> TV (0) -> Broadcast (F): routing change (80)
DEBUG:   [          130312]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=7 addr=05 opcode=a0
TRAFFIC: [          130312]	>> 05:a0:8a:c7:2e:10:18
DEBUG:   [          130312]	sending abort with opcode a0 and reason 'invalid operand' to TV
DEBUG:   [          130312]	<< transmitting abort message
TRAFFIC: [          130313]	<< 50:00:a0:03
DEBUG:   [          130320]	>> TV (0) -> Audio (5): vendor command with id (A0)
DEBUG:   [          130423]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
DEBUG:   [          131063]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=5 addr=05 opcode=a4
TRAFFIC: [          131063]	>> 05:a4:07:0a:02
DEBUG:   [          131063]	sending abort with opcode a4 and reason 'unrecognised opcode' to TV
DEBUG:   [          131063]	<< transmitting abort message
TRAFFIC: [          131063]	<< 50:00:a4:00
DEBUG:   [          131071]	>> TV (0) -> Audio (5): UNKNOWN (A4)
DEBUG:   [          131174]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
DEBUG:   [          134063]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=5 addr=05 opcode=a4
TRAFFIC: [          134064]	>> 05:a4:07:0a:02
DEBUG:   [          134065]	sending abort with opcode a4 and reason 'unrecognised opcode' to TV
DEBUG:   [          134065]	<< transmitting abort message
TRAFFIC: [          134065]	<< 50:00:a4:00
DEBUG:   [          134071]	>> TV (0) -> Audio (5): UNKNOWN (A4)
DEBUG:   [          134174]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
DEBUG:   [          134393]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=7 addr=05 opcode=a0
TRAFFIC: [          134393]	>> 05:a0:8a:c7:2e:10:18
DEBUG:   [          134393]	sending abort with opcode a0 and reason 'invalid operand' to TV
DEBUG:   [          134393]	<< transmitting abort message
TRAFFIC: [          134393]	<< 50:00:a0:03
DEBUG:   [          134397]	>> TV (0) -> Audio (5): vendor command with id (A0)
DEBUG:   [          134503]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
DEBUG:   [          135437]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=5 addr=4f opcode=84
TRAFFIC: [          135438]	>> 4f:84:10:00:04
DEBUG:   [          135446]	>> Playback 1 (4) -> Broadcast (F): report physical address (84)
DEBUG:   [          136626]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=5 addr=4f opcode=87
TRAFFIC: [          136627]	>> 4f:87:00:10:fa
DEBUG:   [          136627]	Playback 1 (4): vendor = Apple (0010fa)
DEBUG:   [          136633]	>> Playback 1 (4) -> Broadcast (F): device vendor id (87)
DEBUG:   [          137156]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=5 addr=05 opcode=a4
TRAFFIC: [          137158]	>> 05:a4:07:0a:02
DEBUG:   [          137158]	sending abort with opcode a4 and reason 'unrecognised opcode' to TV
DEBUG:   [          137158]	<< transmitting abort message
TRAFFIC: [          137158]	<< 50:00:a4:00
DEBUG:   [          137164]	>> TV (0) -> Audio (5): UNKNOWN (A4)
DEBUG:   [          137267]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
DEBUG:   [          142320]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=7 addr=05 opcode=a0
TRAFFIC: [          142322]	>> 05:a0:8a:c7:2e:10:18
DEBUG:   [          142322]	sending abort with opcode a0 and reason 'invalid operand' to TV
DEBUG:   [          142322]	<< transmitting abort message
TRAFFIC: [          142322]	<< 50:00:a0:03
DEBUG:   [          142330]	>> TV (0) -> Audio (5): vendor command with id (A0)
DEBUG:   [          142431]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
DEBUG:   [          158323]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=7 addr=05 opcode=a0
TRAFFIC: [          158324]	>> 05:a0:8a:c7:2e:10:18
DEBUG:   [          158324]	sending abort with opcode a0 and reason 'invalid operand' to TV
DEBUG:   [          158324]	<< transmitting abort message
TRAFFIC: [          158324]	<< 50:00:a0:03
DEBUG:   [          158330]	>> TV (0) -> Audio (5): vendor command with id (A0)
DEBUG:   [          158433]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00




# SLEEPING APPLE TV...




DEBUG:   [          178688]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=4f opcode=36
TRAFFIC: [          178689]	>> 4f:36
DEBUG:   [          178689]	Playback 1 (4): power status changed from 'on' to 'standby'
DEBUG:   [          178695]	>> Playback 1 (4) -> Broadcast (F): standby (36)
DEBUG:   [          180992]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=4 addr=0f opcode=82
TRAFFIC: [          180994]	>> 0f:82:00:00
DEBUG:   [          180994]	making TV (0) the active source
DEBUG:   [          180994]	marking Playback 1 (4) as inactive source
DEBUG:   [          181001]	>> TV (0) -> Broadcast (F): active source (82)
DEBUG:   [          181079]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=0f opcode=36
TRAFFIC: [          181079]	>> 0f:36
DEBUG:   [          181079]	TV (0): power status changed from 'on' to 'standby'
DEBUG:   [          181173]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=05 opcode=70
TRAFFIC: [          181173]	>> 05:70
DEBUG:   [          181173]	>> Audio (5): system audio mode status changed from on to off
DEBUG:   [          181173]	<< 5 -> 0: set system audio mode '7f'
TRAFFIC: [          181173]	<< 50:72:00
DEBUG:   [          181177]	>> TV (0) -> Audio (5): system audio mode request (70)
DEBUG:   [          181260]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=3 addr=50 opcode=72




# APPLE TV REMOTE STILL SHOWS THAT AUDIO CONTROL IS AVAILABLE.
# WAKING APPLE TV...




DEBUG:   [          233583]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=45 opcode=7d
TRAFFIC: [          233584]	>> 45:7d
DEBUG:   [          233585]	<< 5 -> 4: system audio mode 'off'
TRAFFIC: [          233585]	<< 54:7e:00
DEBUG:   [          233591]	>> Playback 1 (4) -> Audio (5): give audio mode status (7D)
DEBUG:   [          233670]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=3 addr=54 opcode=7e
DEBUG:   [          233962]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=4 addr=4f opcode=82
TRAFFIC: [          233963]	>> 4f:82:10:00
DEBUG:   [          233963]	Playback 1 (4): power status changed from 'standby' to 'on'
DEBUG:   [          233963]	making Playback 1 (4) the active source
DEBUG:   [          233963]	TV (0): power status changed from 'standby' to 'in transition from standby to on'
DEBUG:   [          233963]	marking TV (0) as inactive source
DEBUG:   [          233967]	>> Playback 1 (4) -> Broadcast (F): active source (82)
DEBUG:   [          234134]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=0f opcode=85
TRAFFIC: [          234135]	>> 0f:85
DEBUG:   [          234135]	>> 0 requests active source
DEBUG:   [          234135]	TV (0): power status changed from 'in transition from standby to on' to 'on'
DEBUG:   [          234135]	<< Audio (5) is not the active source
DEBUG:   [          234138]	>> TV (0) -> Broadcast (F): request active source (85)
DEBUG:   [          234267]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=4 addr=4f opcode=82
TRAFFIC: [          234268]	>> 4f:82:10:00
DEBUG:   [          234268]	Playback 1 (4) was already marked as active source
DEBUG:   [          234271]	>> Playback 1 (4) -> Broadcast (F): active source (82)
DEBUG:   [          234426]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=4 addr=05 opcode=70
TRAFFIC: [          234427]	>> 05:70:00:00
DEBUG:   [          234427]	>> Audio (5): system audio mode status changed from off to on
DEBUG:   [          234427]	making TV (0) the active source
DEBUG:   [          234427]	marking Playback 1 (4) as inactive source
DEBUG:   [          234427]	<< 5 -> 0: set system audio mode '7f'
TRAFFIC: [          234427]	<< 50:72:01
DEBUG:   [          234430]	>> TV (0) -> Audio (5): system audio mode request (70)
DEBUG:   [          234513]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=3 addr=50 opcode=72
DEBUG:   [          234589]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=05 opcode=7d
TRAFFIC: [          234589]	>> 05:7d
DEBUG:   [          234590]	<< 5 -> 0: system audio mode 'on'
TRAFFIC: [          234590]	<< 50:7e:01
DEBUG:   [          234593]	>> TV (0) -> Audio (5): give audio mode status (7D)
DEBUG:   [          234676]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=3 addr=50 opcode=7e
DEBUG:   [          234760]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=05 opcode=83
TRAFFIC: [          234760]	>> 05:83
DEBUG:   [          234760]	<< Audio (5) -> broadcast (F): physical address 2000
TRAFFIC: [          234760]	<< 5f:84:20:00:05
DEBUG:   [          234763]	>> TV (0) -> Audio (5): give physical address (83)
DEBUG:   [          234895]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=5 addr=5f opcode=84
DEBUG:   [          234971]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=05 opcode=8c
TRAFFIC: [          234971]	>> 05:8c
DEBUG:   [          234971]	<< Audio (5) -> TV (0): vendor id Pulse Eight (1582)
TRAFFIC: [          234971]	<< 5f:87:00:15:82
DEBUG:   [          234974]	>> TV (0) -> Audio (5): give device vendor id (8C)
DEBUG:   [          235105]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=5 addr=5f opcode=87
DEBUG:   [          235172]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=2 addr=05 opcode=46
TRAFFIC: [          235172]	>> 05:46
DEBUG:   [          235172]	<< Audio (5) -> TV (0): OSD name 'CECTester'
TRAFFIC: [          235173]	<< 50:47:43:45:43:54:65:73:74:65:72
DEBUG:   [          235175]	>> TV (0) -> Audio (5): give osd name (46)
DEBUG:   [          235451]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=11 addr=50 opcode=47
DEBUG:   [          235665]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=7 addr=05 opcode=a0
TRAFFIC: [          235666]	>> 05:a0:8a:c7:2e:10:18
DEBUG:   [          235666]	sending abort with opcode a0 and reason 'invalid operand' to TV
DEBUG:   [          235666]	<< transmitting abort message
TRAFFIC: [          235666]	<< 50:00:a0:03
DEBUG:   [          235669]	>> TV (0) -> Audio (5): vendor command with id (A0)
DEBUG:   [          235776]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
DEBUG:   [          236097]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=6 addr=0f opcode=80
TRAFFIC: [          236097]	>> 0f:80:00:00:10:00
DEBUG:   [          236101]	>> TV (0) -> Broadcast (F): routing change (80)
DEBUG:   [          237292]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=7 addr=05 opcode=a0
TRAFFIC: [          237292]	>> 05:a0:8a:c7:2e:10:18
DEBUG:   [          237292]	sending abort with opcode a0 and reason 'invalid operand' to TV
DEBUG:   [          237292]	<< transmitting abort message
TRAFFIC: [          237293]	<< 50:00:a0:03
DEBUG:   [          237300]	>> TV (0) -> Audio (5): vendor command with id (A0)
DEBUG:   [          237403]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
DEBUG:   [          238043]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=5 addr=05 opcode=a4
TRAFFIC: [          238043]	>> 05:a4:07:0a:02
DEBUG:   [          238043]	sending abort with opcode a4 and reason 'unrecognised opcode' to TV
DEBUG:   [          238043]	<< transmitting abort message
TRAFFIC: [          238043]	<< 50:00:a4:00
DEBUG:   [          238050]	>> TV (0) -> Audio (5): UNKNOWN (A4)
DEBUG:   [          238154]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
DEBUG:   [          241043]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=5 addr=05 opcode=a4
TRAFFIC: [          241044]	>> 05:a4:07:0a:02
DEBUG:   [          241045]	sending abort with opcode a4 and reason 'unrecognised opcode' to TV
DEBUG:   [          241045]	<< transmitting abort message
TRAFFIC: [          241045]	<< 50:00:a4:00
DEBUG:   [          241052]	>> TV (0) -> Audio (5): UNKNOWN (A4)
DEBUG:   [          241154]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
DEBUG:   [          241373]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=7 addr=05 opcode=a0
TRAFFIC: [          241373]	>> 05:a0:8a:c7:2e:10:18
DEBUG:   [          241373]	sending abort with opcode a0 and reason 'invalid operand' to TV
DEBUG:   [          241373]	<< transmitting abort message
TRAFFIC: [          241373]	<< 50:00:a0:03
DEBUG:   [          241377]	>> TV (0) -> Audio (5): vendor command with id (A0)
DEBUG:   [          241484]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
DEBUG:   [          242420]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=5 addr=4f opcode=84
TRAFFIC: [          242421]	>> 4f:84:10:00:04
DEBUG:   [          242428]	>> Playback 1 (4) -> Broadcast (F): report physical address (84)
DEBUG:   [          243606]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=5 addr=4f opcode=87
TRAFFIC: [          243608]	>> 4f:87:00:10:fa
DEBUG:   [          243614]	>> Playback 1 (4) -> Broadcast (F): device vendor id (87)
DEBUG:   [          244135]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=5 addr=05 opcode=a4
TRAFFIC: [          244136]	>> 05:a4:07:0a:02
DEBUG:   [          244136]	sending abort with opcode a4 and reason 'unrecognised opcode' to TV
DEBUG:   [          244136]	<< transmitting abort message
TRAFFIC: [          244136]	<< 50:00:a4:00
DEBUG:   [          244142]	>> TV (0) -> Audio (5): UNKNOWN (A4)
DEBUG:   [          244246]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
DEBUG:   [          249300]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=7 addr=05 opcode=a0
TRAFFIC: [          249302]	>> 05:a0:8a:c7:2e:10:18
DEBUG:   [          249302]	sending abort with opcode a0 and reason 'invalid operand' to TV
DEBUG:   [          249302]	<< transmitting abort message
TRAFFIC: [          249302]	<< 50:00:a0:03
DEBUG:   [          249308]	>> TV (0) -> Audio (5): vendor command with id (A0)
DEBUG:   [          249411]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00
DEBUG:   [          265305]	CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=7 addr=05 opcode=a0
TRAFFIC: [          265306]	>> 05:a0:8a:c7:2e:10:18
DEBUG:   [          265306]	sending abort with opcode a0 and reason 'invalid operand' to TV
DEBUG:   [          265306]	<< transmitting abort message
TRAFFIC: [          265306]	<< 50:00:a0:03
DEBUG:   [          265307]	>> TV (0) -> Audio (5): vendor command with id (A0)
DEBUG:   [          265416]	CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=4 addr=50 opcode=00




# VOLUME CONTROL NO LONGER AVAILABLE FROM APPLE TV... ENDING TRACE.




q
DEBUG:   [          296006]	unregistering all CEC clients
NOTICE:  [          296011]	unregistering client: libCEC version = 6.0.2, client version = 6.0.2, firmware version = 0, logical address(es) = Audio (5) , physical address: 2.0.0.0, compiled on Linux-5.10.63-v8+ ... , features: P8_USB, DRM, P8_detect, randr, RPi, Exynos, Linux, AOCEC
DEBUG:   [          296014]	Audio (5): power status changed from 'on' to 'unknown'
DEBUG:   [          296016]	Audio (5): vendor = Unknown (000000)
DEBUG:   [          296018]	Audio (5): CEC version unknown
DEBUG:   [          296018]	Audio (5): osd name set to 'Audio'
DEBUG:   [          296019]	Audio (5): device status changed into 'unknown'
DEBUG:   [          296022]	CLinuxCECAdapterCommunication::Process - CEC_DQEVENT - CEC_EVENT_STATE_CHANGE - log_addr_mask=0000 phys_addr=2000
DEBUG:   [          296022]	CLinuxCECAdapterCommunication::SetLogicalAddresses - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=0000 num_log_addrs=0
DEBUG:   [          296026]	CLinuxCECAdapterCommunication::SetLogicalAddresses - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=0000 num_log_addrs=0
DEBUG:   [          296026]	unregistering all CEC clients
DEBUG:   [          296028]	CLinuxCECAdapterCommunication::Process - CEC_DQEVENT - CEC_EVENT_STATE_CHANGE - log_addr_mask=0000 phys_addr=2000
DEBUG:   [          296028]	CLinuxCECAdapterCommunication::SetLogicalAddresses - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=0000 num_log_addrs=0
DEBUG:   [          297034]	CLinuxCECAdapterCommunication::Process - stopped - m_path=/dev/cec0 m_fd=4
```
