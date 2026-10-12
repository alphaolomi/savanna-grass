---
title: "Savanna Grass: my screen-time tracker now sends me outside, and the AI never sees my day"
published: true
tags: devchallenge, hf26challenge, flutter, gemma
---

*This is a submission for the [Hacktoberfest Open-Source AI Challenge — Week 1: Touch Grass](https://dev.to/devteam/join-the-hacktoberfest-open-source-ai-challenge-week-1-touch-grass-2450-in-prizes-across-17-4pom).*

## What I Built

I build [SavannaTime](https://savannatime.com), a privacy-first screen-time tracker. It is very
good at telling me I spent five hours in VS Code and forty minutes on YouTube. It has never once
made me stand up.

**Savanna Grass** is the missing half: a Flutter app that reads today's screen time from
SavannaTime, turns it into **grass debt**, and pays that debt off with small outdoor quests
planned by **Twiga** 🦒 (Swahili for giraffe, the one who sees over the grass). Twiga is
**Gemma 3 1B**, running on the device.

- **Grass debt.** Every hour on screens owes 10 minutes outside. Distracting time counts 1.5×.
  Capped at an hour a day, because the goal is a walk, not guilt.
- **A quest, not a nag.** "Go for a walk" is easy to ignore. "Step outside and count the
  constellations you can find" is not. Twiga writes one from the shape of your day: how long, how
  distracting, which apps, the time, whether it's dark, and whether you're at home, at work or out.
- **Then the phone gets boring.** A big timer, one line of instructions, and "phone in pocket,
  eyes up." When you come back you can jot down what you noticed, and the break is logged to
  SavannaTime, where it sits next to your screen time and pays off the debt.

- **It survives your pocket.** The break is saved the moment it starts, so when Android closes the
  app while you're outside (on my phone it does, the moment you press Home), reopening it brings
  the timer straight back. A running timer sits in your notifications, your phone rings at quest
  time, and a daily nudge reminds you when the day still owes grass.
- **Every number opens up.** Tap the debt to see the day worked out line by line, hour by hour with
  your time outside marked, and the apps and categories behind it. Tap the week to see which days
  you paid off. Tap a break to see what it paid.
- **Midnight is real.** A break from 23:50 to 00:10 pays ten minutes of each day's debt, and the
  app starts the new day by itself.
- **A week you can see.** A 7-day chart of time outside, a streak, and today's breaks with the
  notes you left. Light and dark mode, in SavannaTime's own palette with its green as the accent.

It's for people like me: developers and students whose day disappears into a monitor, and who
already have a tracker telling them so.

**Try it:** [download the signed Android APK](https://alphaolomi.github.io/savanna-grass/) (58 MB,
Android 7.0+, 64-bit). The latest is
[1.2.0](https://github.com/alphaolomi/savanna-grass/releases/tag/v1.2.0).

## Demo

{% embed https://youtu.be/zt68LUsdivA %}

80 seconds, nothing mocked: the real app against a local SavannaTime server with a seeded test
account. Twiga writes two quests, the second with the **network switched off**. The break's 21
minutes are a clearly labelled time-lapse; everything else is real time or marked as sped up.
Narration is Piper, an open-source offline TTS, and the music bed is synthesised in code, so even
the video is built from open tools (`demo/` in the repo rebuilds it end to end).

*The video shows 1.0. Since then, 1.1 made breaks survive the pocket and added reminders, and 1.2
made every number open up. Both are in the screenshots below, taken on my phone.*

## Code

{% github alphaolomi/savanna-grass %}

## How I Built It

**Flutter + `flutter_gemma`.** Gemma 3 1B instruction-tuned, int4, as a MediaPipe `.task` file
(~555 MB). It downloads once over Wi-Fi, then runs on the phone's GPU through LiteRT, falling back
to the CPU on phones without a GPU delegate. The same app runs in Chrome on WebGPU, with MediaPipe
vendored into the build, not loaded from a CDN, so it still works offline.

**Prompting a 1B model, the hard way.** Four lessons, each learned from a failed take:

1. **Labelled lines beat JSON.** `TITLE: / STEPS: / WHY:` comes back far more reliably than JSON
   does from a model this small.
2. **Never give it an example.** I added one worked example to the prompt and Gemma returned it
   word for word, six times out of six. Placeholders only.
3. **The chat template is not optional.** MediaPipe applies Gemma's template on Android but not
   in the browser. Without `<start_of_turn>` markers the model spent 43 seconds printing empty
   code fences. With them: 3 seconds and a real quest. I also pre-fill the answer with `TITLE:` so
   it can only continue in format.
4. **The model writes words, the app owns numbers.** It ignored "30 minutes" and asked for 60. Now
   the duration is always the app's figure from the debt, and if Twiga forgets the WHY line it is
   filled from real data: "5h 46m on screens today. This pays back 30 of your 60 minutes."

The parser stays forgiving anyway: numbered steps, an unlabelled first line as the title, ALL-CAPS
titles calmed down. After dark the prompt asks for somewhere close, safe and lit, and no sunshine.

**Built to survive a pocket.** Android reclaims backgrounded apps freely, and one holding a 550 MB
model in memory is first in line: on my 4 GB test phone the process was gone the moment I pressed
Home. So the running break is written to secure storage the moment it starts and restored on
launch, with the note typed so far. The countdown in the notification shade is a chronometer that
Android draws itself from the start time, so it keeps ticking with no app to tick it. The
quest-time alarm is booked with the OS, which books it again after a reboot. Midnight got the same
care: time outside is credited by the seconds that fall on each local day, and the day rolls over
on resume as well as on a timer, which also catches a timezone or clock change.

**The model is never load-bearing.** The debt is a plain formula a person can check by hand.
Gemma only writes the invitation. If the model isn't downloaded yet, or its answer doesn't parse,
the app shows a hand-written quest and says so. You always get sent outside.

**Talking to SavannaTime.** The app is a client of SavannaTime's existing API:
`GET /stats/summary` for today, `POST /time-entries` for a finished break. Each break gets a
**client-generated UUID** and is queued on the phone before it's sent. That's the same contract
the desktop tracker uses for offline sync, so a break logged with no signal syncs later, and a
retry after a dropped connection can never count the same walk twice.

**What else was hard.** Browser storage: a fresh browser profile has too little quota for a 700 MB
model, and reading it back as a Blob more than once exhausted Chrome's blob store ("Failed to
fetch"). Streaming the weights straight from the Cache API into MediaPipe fixed both. And
`flutter_gemma`'s web session never clears its prompt, so the second quest crashed the graph. The
fix was a thin engine of my own that loads Gemma once and makes each quest a stateless call: the
second quest dropped from 65 seconds to about 5, offline.

## Why Open Innovation Matters Here

SavannaTime has one rule I won't bend: **no activity data ever reaches an external AI vendor.**
Screen time is intimate: which apps, for how long, at 2 a.m. Sending that to a closed API just to
be told to take a walk would break the promise the whole product is built on.

An open-weight model running on the device changes the deal:

- **Your day never leaves the phone.** The prompt is built from aggregates only (totals, the
  productivity mix, top app names) and goes to a model in local memory. No window titles, no
  URLs, no third party.
- **It works where you're going.** The point is to go outside, and outside is where signal
  drops. Gemma runs in airplane mode.
- **No key to leak, no bill per walk.** No API key ships in the app and there's no per-request
  cost, so a free app can stay free.
- **It's mine to change.** I can read the model card, swap Gemma for another open model with one
  `--dart-define`, or fine-tune it on quests people actually finished. A closed API allows none
  of that.

## I Took It Outside

Not at golden hour. It was just before 1 a.m. on Monday 12 October, in the middle of a late coding
session: exactly the kind of day SavannaTime exists to notice.

I asked Twiga for a quest, and Gemma, running on the phone, wrote **"Autumn's Whispering Leaves"**.
Phone in pocket, out at 00:59, back in at 01:07. Then I asked for another: **"The Whispering
Willow"**, out from 01:15 to 01:21.

![The break detail page: Autumn's Whispering Leaves, 00:59 to 01:07, 7 min outside, paid 7 of the 23 minutes owed that day, synced to SavannaTime](https://raw.githubusercontent.com/alphaolomi/savanna-grass/main/docs/img/break-autumn.png)

That's thirteen minutes outside in two short loops, at an hour when a generic "go for a walk"
reminder is the easiest thing in the world to ignore. Both quests were Gemma's own (neither title
is one of the app's hand-written fallbacks), and both breaks reached SavannaTime by themselves,
as time entries sitting next to the screen time they were paying for.

By the morning the day's numbers were in: 2 h 13 m on screens owed 23 minutes, and those two night
breaks had already paid 13 of them. The Day page shows it worked out, with a leaf at 01:00 for the
time I was outside:

![The Day page: 2h 13m on screens times 10 min per hour is 22 min, plus 1 for distracting time, 23 owed, minus 13 outside, 10 left; below it an hour-by-hour chart with a leaf at 01:00](https://raw.githubusercontent.com/alphaolomi/savanna-grass/main/docs/img/day-worked-out.png)

I didn't type a note on either break, so what I noticed stays out of this post. The same phone also
showed the safety net working the next morning: one quest came back as a hand-written fallback
("Twiga was lost for words") after a minute of thinking, and the timer was still there after
Android killed the app mid-break.

## Prize Categories

**Gemma**: Gemma 3 1B is Twiga, the core of the app, running fully on-device: LiteRT on Android
via `flutter_gemma`, and MediaPipe on WebGPU in the browser.
