---
title: "Savanna Grass: my screen-time tracker now sends me outside, and the AI never sees my day"
published: false
tags: devchallenge, hf26challenge, flutter, gemma
---

<!-- Before publishing: fill in "I Took It Outside" from a real break, then delete this comment. -->

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

- **A week you can see.** A 7-day chart of time outside, a streak, and today's breaks with the
  notes you left. Light and dark mode, in SavannaTime's own palette with its green as the accent.

It's for people like me: developers and students whose day disappears into a monitor, and who
already have a tracker telling them so.

## Demo

{% embed https://youtu.be/zt68LUsdivA %}

80 seconds, nothing mocked: the real app against a local SavannaTime server with a seeded test
account. Twiga writes two quests, the second with the **network switched off**. The break's 21
minutes are a clearly labelled time-lapse; everything else is real time or marked as sped up.
Narration is Piper, an open-source offline TTS, and the music bed is synthesised in code, so even
the video is built from open tools (`demo/` in the repo rebuilds it end to end).

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

TODO: a real break. Where you went, what quest Gemma gave you, what you noticed (the note you
typed), how long you stayed, and one photo.

## Prize Categories

**Gemma**: Gemma 3 1B is Twiga, the core of the app, running fully on-device: LiteRT on Android
via `flutter_gemma`, and MediaPipe on WebGPU in the browser.
