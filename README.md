# Savanna Grass

<img src="brand/png/icon-rounded-192.png" width="96" align="right" alt="">

**Your screen time, turned into reasons to go outside — planned by Twiga, an open-weight model running on your device.**

Savanna Grass is a Flutter companion to [SavannaTime](https://savannatime.com), the privacy-first
screen-time tracker. SavannaTime already knows how long you have been on screens today. Savanna
Grass turns that into **grass debt** and pays it back one small outdoor quest at a time.

- **Grass debt** — every hour on screens owes 10 minutes outside; distracting time counts 1.5×;
  capped at an hour a day. A plain formula you can check by hand.
- **Twiga, your outdoor guide** — *twiga* is Swahili for giraffe, the one who sees over the
  grass. Under the hood Twiga is [Gemma 3 1B](https://huggingface.co/litert-community/Gemma3-1B-IT)
  running **on the device** (LiteRT on a phone, MediaPipe on WebGPU in a browser). It writes a
  specific, sensory outdoor quest from your day: how long, how distracting, which apps, the time,
  whether it is dark, and where you are.
- **This week outside** — a 7-day chart of time outside, a streak, and today's breaks with the
  notes you wrote when you came back in.
- **Light and dark** — SavannaTime's own palette with its green as the accent; follows the system
  or a toggle.
- **Go outside** — a deliberately boring timer. Phone in pocket. When you are back, the break is
  logged to SavannaTime as a time entry (`🌿 Touch grass · …`), so it shows up next to your
  screen time on the web dashboard and pays off the debt.

**[Download for Android](https://alphaolomi.github.io/savanna-grass/)** · [Demo video](https://youtu.be/zt68LUsdivA) · [Releases](https://github.com/alphaolomi/savanna-grass/releases)

Built for the [DEV Hacktoberfest Open-Source AI Challenge — Week 1: Touch Grass](https://dev.to/devteam/join-the-hacktoberfest-open-source-ai-challenge-week-1-touch-grass-2450-in-prizes-across-17-4pom).

## Why on-device, open-weight

SavannaTime has one hard rule: **no activity data ever reaches an external AI vendor.** Screen
time is intimate — which apps, how long, when. A closed AI API would mean shipping that to a third
party just to be told to go for a walk.

An open-weight model running locally changes the deal:

| | Closed API | Twiga (Gemma, on-device) |
|---|---|---|
| Your app usage leaves the phone | yes | **no** |
| Works with no signal (i.e. outside) | no | **yes** |
| Per-request cost / API key in the app | yes | **no** |
| You can inspect, swap or fine-tune the model | no | **yes** |

Only aggregates reach the prompt — totals, the productivity mix and top app *names*. Window titles
never leave the SavannaTime server, and nothing leaves the phone for the AI. See
[`buildQuestPrompt`](lib/domain/quest.dart).

The model is never load-bearing. The debt — and how long each quest lasts — is a formula, not a
model's guess; Twiga only writes the words. If the model is not downloaded yet, or its answer does
not parse, a classic quest is shown instead. You always get sent outside.

## Run it

Requires Flutter 3.38+ (for `flutter_local_notifications`) and an Android (API 24+) or iOS device. A physical phone is strongly
recommended — emulators rarely have a GPU delegate.

1. Gemma's weights are gated: sign in to Hugging Face, accept the licence on
   [litert-community/Gemma3-1B-IT](https://huggingface.co/litert-community/Gemma3-1B-IT), and create a
   **read** token.
2. Run:

   ```bash
   flutter pub get
   flutter run --dart-define=HF_TOKEN=hf_xxx
   ```

3. Sign in with your SavannaTime account (data comes from the
   [desktop tracker](https://savannatime.com)), tap **Bring Twiga home** once (~555 MB on a phone),
   then **Give me a quest**.

### In a browser

The web build runs the same model on WebGPU (Chrome/Edge). MediaPipe's runtime is vendored rather
than loaded from a CDN, so quests keep working with the network off:

```bash
bash tool/vendor_mediapipe.sh          # pinned npm tarball, integrity-checked → web/mediapipe/
flutter build web --release --dart-define=HF_TOKEN=hf_xxx
```

| `--dart-define` | Default | |
|---|---|---|
| `HF_TOKEN` | *(empty)* | Only used to download the model once. Never committed. |
| `SAVANNA_API_URL` | `https://api.savannatime.com` | Point at a local SavannaTime server for development. |
| `GEMMA_MODEL_URL` | Gemma 3 1B IT int4 `.task` (`-web.task` on web) | Any MediaPipe `.task` Gemma build. |
| `DEBUG_QUESTS` | `false` | Print the model's raw answers to the console. |

```bash
flutter test      # debt formula, week/streak, prompt, parser, fallbacks, API client,
                  # midnight rollover, restarts mid-break, sync races, reminder plans
flutter analyze
```

## How it is built

```
lib/
  domain/grass_debt.dart   deterministic debt formula (pure, tested)
  domain/quest.dart        prompt builder, tolerant line parser, template fallbacks
  domain/outdoor_log.dart  the 7-day chart and streak (pure, tested)
  domain/local_day.dart    local-midnight days; a break across midnight pays both
  domain/active_break.dart the running break, saved so it survives Android killing the app
  domain/reminder_plan.dart which daily nudges to book, from the last known debt (pure, tested)
  domain/profile.dart      the SavannaTime account (GET /me) and the time-zone mismatch check
  persona.dart             Twiga's name and voice
  ai/gemma_runtime.dart    download / activate / generate with flutter_gemma (GPU → CPU)
  ai/web_llm.dart          browser engine: one MediaPipe instance, weights streamed from cache
  ai/quest_writer.dart     model-first, classic-quest fallback writer
  api/savanna_api.dart     SavannaTime /api/v1 client (login, profile, stats, time entries)
  app_state.dart           one ChangeNotifier: day rollover, foreground/background, offline queue
  reminders.dart           break timer, quest-time alarm and daily nudge (local notifications)
  ui/                      login, home (debt hero, Twiga, week, today), break timer, profile, reminders, theme
demo/                      reproducible demo video: seed → record → narrate → edit
```

**Talking to SavannaTime.** `GET /stats/summary?from=today&to=today` gives the day's totals and
productivity mix (bucketed in the user's own timezone server-side). A finished break is
`POST /time-entries` with a **client-generated UUID**, the same idempotency contract SavannaTime's
desktop sync uses: a break is queued on the phone first, then sent, and a retry after a dropped
connection lands exactly once. Sessions use SavannaTime's 7-day JWT, stored in the
Keychain/Keystore and renewed in place inside its last day.

**Prompting a 1B model.** Lessons learned the hard way:

- Small models follow labelled lines (`TITLE: / STEPS: / WHY:`) far more reliably than JSON.
- Give it a concrete example and it copies the example word for word, every time. Placeholders
  only.
- MediaPipe applies Gemma's chat template on Android but **not on the web** — without
  `<start_of_turn>` markers the model loops on empty code fences. The web engine adds the template
  and pre-fills the answer with `TITLE:`, so the model can only continue in format.
- The parser is forgiving anyway: multi-line and numbered steps, an unlabelled first line as the
  title, ALL-CAPS titles calmed down, echoed placeholders rejected. A missing WHY is filled from
  the real numbers ("5h 46m on screens today. This pays back 30 of your 60 minutes.").
- After dark the prompt asks for somewhere close, safe and lit — and no sunshine.

## Demo video

▶ **[Watch the 80-second demo on YouTube](https://youtu.be/zt68LUsdivA)**

`demo/` rebuilds the submission video end to end, nothing mocked: `seed.ts` creates a test account
on a **local** SavannaTime server through the real API; `record.mjs` drives the real web build in
Chromium with Playwright and captures frames over the DevTools screencast (the break's 21 minutes
are a page-clock time-lapse, labelled as such); narration is [Piper](https://github.com/rhasspy/piper)
(open-source, offline TTS); `music.py` synthesises the music bed; `edit.py` composes the 1080p cut
with ffmpeg.

## Brand

One drawing, every surface: Twiga the giraffe rising out of the grass towards the sun, on
SavannaTime green. `brand/make_svgs.py` writes the SVGs (full icon, Android adaptive background /
foreground / themed-monochrome layers, Twiga's head for in-app avatars); `brand/render.mjs`
renders them with Chromium. Icons and launch screens for Android, iOS and web are generated from
those PNGs:

```bash
python brand/make_svgs.py && PLAYWRIGHT_DIR=… node brand/render.mjs
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Releasing

The website in `site/` deploys to GitHub Pages on every push that touches it
(`.github/workflows/pages.yml`). Its download buttons find the newest release carrying
`savanna-grass.apk` (the model mirror is a release too, so "latest" is not enough).

- **The model** is mirrored once, on its own release tag `model-gemma3-1b`, with the Gemma terms —
  so the public app needs no Hugging Face token and app releases never re-upload 555 MB.
- **The APK** is signed with a release key kept outside the repo: `android/key.properties`
  (gitignored) points at the keystore. Without it, release builds fall back to the debug key.

```bash
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk savanna-grass.apk
gh release create v1.0.1 savanna-grass.apk --title "Savanna Grass 1.0.1" --notes "…"
```

## Licence

MIT. Gemma weights are subject to the [Gemma Terms of Use](https://ai.google.dev/gemma/terms).
