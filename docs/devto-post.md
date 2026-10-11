---
title: "Savanna Grass: my screen-time tracker now sends me outside, and the AI never sees my day"
published: false
tags: devchallenge, hf26challenge, flutter, gemma
---

<!-- Before publishing: replace every TODO, paste the demo video URL, and fill in the
     "I took it outside" section from a real break. Delete this comment. -->

*This is a submission for the [Hacktoberfest Open-Source AI Challenge — Week 1: Touch Grass](https://dev.to/devteam/join-the-hacktoberfest-open-source-ai-challenge-week-1-touch-grass-2450-in-prizes-across-17-4pom).*

## What I Built

I build [SavannaTime](https://savannatime.com), a privacy-first screen-time tracker. It is very
good at telling me I spent five hours in VS Code and forty minutes on YouTube. It has never once
made me stand up.

**Savanna Grass** is the missing half: a Flutter app that reads today's screen time from
SavannaTime, turns it into **grass debt**, and pays that debt off with small outdoor quests,
written on the phone by **Gemma 3 1B**.

- **Grass debt.** Every hour on screens owes 10 minutes outside. Distracting time counts 1.5×.
  Capped at an hour a day, because the goal is a walk, not guilt.
- **A quest, not a nag.** "Go for a walk" is easy to ignore. "Find five shades of green and touch
  the softest one" is not. Gemma writes one from the shape of your day: how long, how distracting,
  which apps, the time, and whether you're at home, at work or out.
- **Then the phone gets boring.** A big timer, one line of instructions, and "phone in pocket,
  eyes up." When you come back you can jot down what you noticed, and the break is logged to
  SavannaTime, where it sits next to your screen time and pays off the debt.

It's for people like me: developers and students whose day disappears into a monitor, and who
already have a tracker telling them so.

## Demo

TODO: embed the video. Suggested 60-second cut: the debt ring at 40 min → tap "Give me a quest" →
Gemma's quest appears with "Written on-device by Gemma 3 1B" → **turn on airplane mode** → another
quest still generates → walk out the door → back → the ring fills and the entry appears on the
SavannaTime web dashboard.

## Code

{% github alphaolomi/savanna-grass %}

## How I Built It

**Flutter + `flutter_gemma`.** Gemma 3 1B instruction-tuned, int4, as a MediaPipe `.task` file
(~550 MB). It downloads once over Wi-Fi, then runs on the phone's GPU through LiteRT, falling back
to the CPU on phones without a GPU delegate.

**Prompting a 1B model.** My first prompt asked for JSON. A 1B model sometimes produces JSON and
often doesn't. Labelled lines work much better:

```
TITLE: <a fun title, at most 6 words>
MINUTES: <a number>
STEPS: <one or two sentences saying exactly what to do>
WHY: <one short sentence linking it to their screen time today>
```

The parser is tolerant on purpose. It accepts `**TITLE:**`, chatter like "Sure! Here's your
quest:", and "15 minutes" where a number should be. After dark the prompt asks for a safe, lit
spot: a doorstep, a balcony, a lit street.

**The model is never load-bearing.** The debt is a plain formula a person can check by hand.
Gemma only writes the invitation. If the model isn't downloaded yet, or its answer doesn't parse,
the app shows a hand-written quest and says so. You always get sent outside.

**Talking to SavannaTime.** The app is a client of SavannaTime's existing API:
`GET /stats/summary` for today, `POST /time-entries` for a finished break. Each break gets a
**client-generated UUID** and is queued on the phone before it's sent. That's the same contract
the desktop tracker uses for offline sync, so a break logged with no signal syncs later, and a
retry after a dropped connection can never count the same walk twice.

TODO: one honest paragraph on what was hard (first model download, GPU vs CPU speed on your
phone, a funny quest Gemma wrote).

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

TODO: a real break. Where you went, what quest Gemma gave you, what you noticed (the note you
typed), how long you stayed, and one photo.

## Prize Categories

**Gemma**: Gemma 3 1B is the core of the app, running fully on-device through `flutter_gemma`
(MediaPipe / LiteRT).
