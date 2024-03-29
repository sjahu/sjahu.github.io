---
title: Electric kettle teardown
---

I retired my 8-year-old electric kettle the other day because, though it still boiled water, the auto-shutoff feature had begun to malfunction, often (but not always) causing it to continue to heat water long after it had reached 100 degrees. Besides that, the inside of the kettle had long been rusting, it sometimes leaked, and I had already had to jury-rig a fix for its broken lid-release button-- it had served me well, but an upgrade was well justified.

8 years is pretty good for an electric kettle, but it really shouldn't be. These are simple devices. Electricity goes in, heat comes out... Why are throw-away appliances the norm? In reading reviews online, there really isn't much to recommend any particular electric kettle brand over any other: a near universal theme is 90 percent of reviews saying "5 stars, boils water perfectly" and 10 percent saying "worked great, but it broke after 2 weeks/1 month/2 years/5 years/etc".

I'd like to just buy a whistling stove-top kettle and not have to think about the inevitability of throwing out another mostly-fine but non-functioning appliance in a few years, but -- alas -- it takes ~5 1/2 minutes to boil a litre of water in a 1500W plug-in kettle versus ~7 1/2 minutes on my anaemic electric range, and every second counts. (I covet the more powerful 2-3kW kettles available in countries with 230V power grids.)

So, in the end, I bought a new $95 Zwilling kettle with essentially the same specs as the $20 (discontinued) Hamilton Beach kettle it was replacing: 1L, 1500W, auto-shutoff, no variable temperature control (a microcontroller in a kettle? Just another thing to break). $95 is certainly steep for a basic kettle, but pickings for 1500W kettles that are only 1L in volume are pretty slim. The Zwilling looks nice and it has a "seamless stainless-steel design" which should make keeping the inside of the boiler free of scale easy.

---

Other than looks, I wondered, what's the difference between a cheap kettle and one five times the price? I unscrewed the bases of the two kettles to find out.

As it turns out, not much. Without the labels, could you even tell which base photo is of which kettle?

{% figure /assets/images/blog/2023-10-18/hamilton_beach.jpg medium %}
  Hamilton Beach
{% endfigure %}

{% figure /assets/images/blog/2023-10-18/hamilton_beach_base.jpg medium %}
  Hamilton Beach element and control mechanism (Strix U1852)
{% endfigure %}

{% figure /assets/images/blog/2023-10-18/zwilling.jpg medium %}
  Zwilling
{% endfigure %}

{% figure /assets/images/blog/2023-10-18/zwilling_base.jpg medium %}
  Zwilling element and control mechanism (Strix U9099)
{% endfigure %}

Interesting fact: [Strix](https://strix.com/), a British company you have probably never heard of, designs and manufactures [56% (by value)](https://www.strixplc.com/docs/2023/img_442b0752b4.pdf) of the kettle control mechanisms sold globally. Many (most?) kettle brands use Strix's off-the-shelf controls, so if you buy an electric kettle, chances are good it runs on Strix.

---

The way the standard control mechanism works is that steam is piped down from the top of the kettle onto a [bimetallic](https://en.wikipedia.org/wiki/Bimetal) disc (bottom-centre in the photos) which changes shape as it heats up. When the disc gets hot enough, which can only happen after a lot of steam has been produced and, therefore, after the water has boiled, it snaps into a different shape and breaks the circuit.

[This CAD rendering](https://grabcad.com/library/strix-u1855-control-system-for-electric-kettles) of a nearly identical Strix control shows how all the pieces fit together. Notice, in addition to the main circuit-breaking thermostat, the dual switches positioned right against the boiler bottom for boil-dry protection.

My best guess as to why my old kettle stopped working properly is that the bimetallic disc had become warped and this made it behave inconsistently. It's also possible that some invisible wear to the plastic mechanism meant that the disc was no longer always able to actuate it effectively-- I'm not totally sure. Other than these two potential causes, there's not much that can go wrong with the Strix control.

One questionable design element, as pointed out by the author of the linked CAD model, is that the steam shutoff requires steam to be piped directly into the base compartment containing the heating element and electrical connections. As you can see in my photo of the old kettle, this results in rust that would have eventually caused the element's connections to fail if something else hadn't broken first.

---

What's the point of this post? Well, partly to complain about the low bar for reliability of electric kettles; partly to appreciate the neat control mechanism that makes these cheap kettles work.

I'd like to see household appliances like electric kettles be built to last. This is mostly on the kettle manufacturers; they should choose better materials and repairable designs. Unfortunately, there's little incentive for them to do that when low prices and max profits are apparently all that matter. It's too bad that manufacturers (and, ultimately, consumers) aren't made to foot the bill for waste disposal at the time of purchase-- maybe if we were, we'd think harder about buying junk.
