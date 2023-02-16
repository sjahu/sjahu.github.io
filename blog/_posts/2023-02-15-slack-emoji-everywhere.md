---
title: Slack emoji everywhere
---

[According to CNN](https://www.cnn.com/2023/01/03/tech/shopify-meetings/index.html), the company I work for recently began "splitting internal communication between Slack and [Workplace by Meta](https://www.workplace.com/) to be "super intentional" about how employees are receiving and sharing different kinds of information". Commenting on the super-intentionality of information reception is above my pay grade, but one thing I can say is that Slack has built-in support for custom emoji (emojis? 🤷) and Workplace by Meta (for those unfamiliar: Facebook, but with your coworkers) does not.

Custom emoji add a certain *je ne sais quoi* to messages on Slack that can make conversations on other platforms feel shallow in comparison. The Unicode emoji built in to most modern operating systems are great, but sometimes a feeling can only be perfectly expressed with a custom 22×22-CSS-pixel image not defined by a committee. Every time I reach for a custom emoji while composing a text message, email, Messenger reply, Workplace post, GitHub issue, etc, only to remember that they're not available, their absence makes me sad.

Slack runs in the browser; several of these other platforms run in the browser; I control the browser... so why not break Slack emoji out of their tab and unleash them on the rest of the Internet? I don't do much web development, so this seemed like a fun excuse to play around with the WebExtensions APIs and see what I could build.

Introducing: the creatively named cross-compatible browser extension, [`slack-emoji-everywhere`](https://github.com/sjahu/slack-emoji-everywhere).

There's more info in the linked GitHub repo's readme, but, as a TL;DR, the extension uses a signed-in Slack workspace to automagically download emoji and injects them into non-Slack webpages in place of text `:emoji:` tokens. It uses the same undocumented (publicly, at least) API endpoints that Slack's web client uses for looking up and searching emoji; it automatically authenticates these API requests using the logged-in users's credentials; it does some caching to avoid looking up the same emoji every time it sees a token; and it optionally supports communicating with a custom, non-Slack emoji server that implements the same API.

I probably won't officially release this extension publicly since I don't want the support burden and I'm sure it violates Slack's EULA, but it was a fun experiment.

{% image /assets/images/blog/2023-02-15/slack-emoji-everywhere.png medium %}
