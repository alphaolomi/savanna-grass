# 🌿 Savanna Grass

**Your screen time, turned into reasons to go outside — written by an open-weight model running on your phone.**

Savanna Grass is a Flutter companion to [SavannaTime](https://savannatime.com), the privacy-first
screen-time tracker. SavannaTime already knows how long you have been on screens today. Savanna
Grass turns that into **grass debt** and pays it back one small outdoor quest at a time.

- **Grass debt** — every hour on screens owes 10 minutes outside; distracting time counts 1.5×;
  capped at an hour a day. A plain formula you can check by hand.
- **Quests** — [Gemma 3 1B](https://huggingface.co/litert-community/Gemma3-1B-IT) runs **on the
  device** (MediaPipe / LiteRT via `flutter_gemma`) and writes a specific, sensory outdoor quest
  from your day: how long, how distracting, which apps, what time it is, where you are.
- **Go outside** — a deliberately boring timer. Phone in pocket. When you are back, the break is
  logged to SavannaTime as a time entry (`🌿 Touch grass · …`), so it shows up next to your
  screen time on the web dashboard and pays off the debt.

Built for the [DEV Hacktoberfest Open-Source AI Challenge — Week 1: Touch Grass](https://dev.to/devteam/join-the-hacktoberfest-open-source-ai-challenge-week-1-touch-grass-2450-in-prizes-across-17-4pom).

## Why on-device, open-weight

SavannaTime has one hard rule: **no activity data ever reaches an external AI vendor.** Screen
time is intimate — which apps, how long, when. A closed AI API would mean shipping that to a third
party just to be told to go for a walk.

An open-weight model running locally changes the deal:

| | Closed API | Gemma on-device |
|---|---|---|
| Your app usage leaves the phone | yes | **no** |
| Works with no signal (i.e. outside) | no | **yes** |
| Per-request cost / API key in the app | yes | **no** |
| You can inspect, swap or fine-tune the model | no | **yes** |

Only aggregates reach the prompt — totals, the productivity mix and top app *names*. Window titles
never leave the SavannaTime server, and nothing leaves the phone for the AI. See
[`buildQuestPrompt`](lib/domain/quest.dart).

The model is never load-bearing: the debt is deterministic, and if the model is not downloaded or
its answer does not parse, a hand-written quest is shown instead. You always get sent outside.

## Run it

Requires Flutter 3.24+ and an Android (API 24+) or iOS device. A physical phone is strongly
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
   [desktop tracker](https://savannatime.com)), tap **Download on Wi-Fi** once (~550 MB), then
   **Give me a quest**.

| `--dart-define` | Default | |
|---|---|---|
| `HF_TOKEN` | *(empty)* | Only used to download the model once. Never committed. |
| `SAVANNA_API_URL` | `https://api.savannatime.com` | Point at a local SavannaTime server for development. |
| `GEMMA_MODEL_URL` | Gemma 3 1B IT int4 `.task` | Any MediaPipe `.task` Gemma build. |

```bash
flutter test      # grass-debt formula, prompt, output parser, fallback, API client
flutter analyze
```

## How it is built

```
lib/
  domain/grass_debt.dart   deterministic debt formula (pure, tested)
  domain/quest.dart        prompt builder, tolerant line parser, template fallbacks
  ai/gemma_runtime.dart    download / activate / generate with flutter_gemma (GPU → CPU)
  ai/quest_writer.dart     model-first, template-fallback quest writer
  api/savanna_api.dart     SavannaTime /api/v1 client (login, stats, time entries)
  app_state.dart           one ChangeNotifier; offline queue for finished breaks
  ui/                      login, home (debt ring, model card, quest), break timer
```

**Talking to SavannaTime.** `GET /stats/summary?from=today&to=today` gives the day's totals and
productivity mix (bucketed in the user's own timezone server-side). A finished break is
`POST /time-entries` with a **client-generated UUID**, the same idempotency contract SavannaTime's
desktop sync uses: a break is queued on the phone first, then sent, and a retry after a dropped
connection lands exactly once. Sessions use SavannaTime's 7-day JWT, stored in the
Keychain/Keystore and renewed in place inside its last day.

**Prompting a 1B model.** Small models follow a rigid labelled-line format far more reliably than
JSON, so the model answers `TITLE: / MINUTES: / STEPS: / WHY:` and a tolerant parser accepts
markdown bold, chatter before the answer and "15 minutes" for a number. After dark the prompt asks
for a safe, lit spot.

## Licence

MIT. Gemma weights are subject to the [Gemma Terms of Use](https://ai.google.dev/gemma/terms).
