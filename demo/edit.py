"""Edits the recorded frames into the 1080p demo video.

    python demo/edit.py <ffmpeg bin dir>

Inputs (all in demo/out/): frames/ + frames.json + marks.json from record.mjs,
vo/*.wav from Piper, music.wav from music.py.
Output: demo/out/savanna-grass-demo.mp4

Layout: the app runs inside a phone frame on the left; the right side carries
a step label, a headline and one honest line about what is happening —
including how much a segment was sped up.
"""
import json
import math
import subprocess
import sys
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FF = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("")
OUT = Path(__file__).parent / "out"
BUILD = OUT / "build"
BUILD.mkdir(exist_ok=True)
W, H, FPS = 1920, 1080, 30

FONTS = Path("C:/Windows/Fonts")
def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size)

CREAM = (247, 241, 222)
GOLD = (226, 178, 74)
MUTED = (190, 205, 180)
GREEN_DARK = (16, 34, 18)
GREEN = (34, 66, 32)

# Phone geometry: the 412x870 viewport scaled to fit a 960-px-tall screen.
SCREEN_H = 940
SCREEN_W = round(412 * SCREEN_H / 870) // 2 * 2
PHONE_X, PHONE_Y = 300, (H - SCREEN_H) // 2
BEZEL = 16
TEXT_X = PHONE_X + SCREEN_W + 150


def ff(*args: str) -> None:
    cmd = [str(FF / "ffmpeg"), "-hide_banner", "-loglevel", "error", "-y", *args]
    subprocess.run(cmd, check=True)


def wav_len(p: Path) -> float:
    with wave.open(str(p)) as w:
        return w.getnframes() / w.getframerate()


# --- static art --------------------------------------------------------------
def background() -> Image.Image:
    img = Image.new("RGB", (W, H), GREEN_DARK)
    px = img.load()
    for y in range(H):
        k = y / H
        row = tuple(int(GREEN[i] * (1 - k) + GREEN_DARK[i] * k) for i in range(3))
        for x in range(W):
            px[x, y] = row
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((1300, -500, 2300, 500), fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    sun = Image.new("RGB", (W, H), GOLD)
    img = Image.composite(sun, img, glow)
    # Grass silhouettes along the bottom.
    d = ImageDraw.Draw(img)
    import random
    r = random.Random(3)
    for _ in range(420):
        x = r.randint(0, W)
        h = r.randint(30, 120)
        lean = r.randint(-25, 25)
        d.line((x, H, x + lean, H - h), fill=(12, 26, 13), width=r.randint(2, 4))
    return img


def phone_base(bg: Image.Image) -> Image.Image:
    img = bg.copy()
    x0, y0 = PHONE_X - BEZEL, PHONE_Y - BEZEL
    x1, y1 = PHONE_X + SCREEN_W + BEZEL, PHONE_Y + SCREEN_H + BEZEL
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((x0 + 14, y0 + 24, x1 + 14, y1 + 24), 64, fill=160)
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    img = Image.composite(Image.new("RGB", (W, H), (0, 0, 0)), img, shadow)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((x0, y0, x1, y1), 60, fill=(14, 14, 14), outline=(60, 64, 58), width=3)
    d = ImageDraw.Draw(img)
    brand, tag = "Savanna Grass", "on-device Gemma  ·  SavannaTime"
    bf, tf = font("seguisb.ttf", 30), font("segoeui.ttf", 22)
    d.text((W - 70 - d.textlength(brand, font=bf), 50), brand, font=bf, fill=CREAM)
    d.text((W - 70 - d.textlength(tag, font=tf), 90), tag, font=tf, fill=MUTED)
    return img


def screen_mask() -> Image.Image:
    m = Image.new("L", (SCREEN_W, SCREEN_H), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, SCREEN_W - 1, SCREEN_H - 1), 46, fill=255)
    return m


def wrap(d: ImageDraw.ImageDraw, text: str, f: ImageFont.FreeTypeFont, width: int) -> list[str]:
    lines, cur = [], ""
    for word in text.split():
        trial = f"{cur} {word}".strip()
        if d.textlength(trial, font=f) <= width:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def caption(eyebrow: str, title: str, body: str, note: str = "") -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    width = W - TEXT_X - 120
    y = 330
    d.text((TEXT_X, y), eyebrow.upper(), font=font("seguisb.ttf", 28), fill=GOLD)
    y += 58
    tf = font("seguibl.ttf", 66)
    for line in wrap(d, title, tf, width):
        d.text((TEXT_X, y), line, font=tf, fill=CREAM)
        y += 82
    y += 18
    bf = font("segoeui.ttf", 34)
    for line in wrap(d, body, bf, width):
        d.text((TEXT_X, y), line, font=bf, fill=MUTED)
        y += 48
    if note:
        y += 26
        nf = font("seguisb.ttf", 26)
        tw = d.textlength(note, font=nf)
        d.rounded_rectangle((TEXT_X, y, TEXT_X + tw + 36, y + 46), 23, fill=(226, 178, 74, 235))
        d.text((TEXT_X + 18, y + 7), note, font=nf, fill=GREEN_DARK)
    return img


def card(bg: Image.Image, big: str, sub: str, chips: list[str], foot: str) -> Image.Image:
    img = bg.copy()
    d = ImageDraw.Draw(img)
    bf = font("seguibl.ttf", 128)
    d.text(((W - d.textlength(big, font=bf)) / 2, 330), big, font=bf, fill=CREAM)
    sf = font("segoeuisl.ttf", 44)
    d.text(((W - d.textlength(sub, font=sf)) / 2, 500), sub, font=sf, fill=MUTED)
    cf = font("seguisb.ttf", 30)
    widths = [d.textlength(c, font=cf) + 48 for c in chips]
    x = (W - sum(widths) - 20 * (len(chips) - 1)) / 2
    for c, w in zip(chips, widths):
        d.rounded_rectangle((x, 610, x + w, 664), 27, outline=GOLD, width=2)
        d.text((x + 24, 618), c, font=cf, fill=GOLD)
        x += w + 20
    ff_ = font("segoeui.ttf", 24)
    d.text(((W - d.textlength(foot, font=ff_)) / 2, 960), foot, font=ff_, fill=MUTED)
    return img


# --- timeline ----------------------------------------------------------------
marks = {m["name"]: m["t"] for m in json.loads((OUT / "marks.json").read_text())}
frames = json.loads((OUT / "frames.json").read_text())
vo = {p.stem: p for p in sorted((OUT / "vo").glob("*.wav"))}

# (start mark, end mark, max seconds on screen or None for 1x, caption, vo)
plan = [
    ("login", "home", None, ("01 · Connect", "Sign in with SavannaTime",
        "The privacy-first screen-time tracker measures your day on the desktop. This app sends you outside."), None),
    ("home", "model-ready" if "download" not in marks else "download", None, ("02 · Grass debt", "Screen time becomes grass debt",
        "10 minutes outside per hour on screens. Distracting time counts 1.5×. Capped at an hour a day."), "02-debt"),
]
if "download" in marks:
    plan.append(("download", "model-ready", 3.0, ("03 · One-time setup", "Download Gemma 3 1B once",
        "About 550 MB of open weights. After that, every quest is generated locally."), None))
plan += [
    ("generating", "quest", 3.5, ("03 · On-device AI", "Gemma writes a quest",
        "Gemma 3 1B runs locally — WebGPU in this browser, LiteRT on a phone."), "03-gemma"),
    ("quest", "offline", None, ("03 · On-device AI", "Specific. Sensory. Outside.",
        "The prompt holds aggregates only: totals, the productivity mix, top app names."), None),
    ("offline", "quest-offline", 3.5, ("04 · Offline", "Network off",
        "No API, no vendor, no key. Your day never leaves the device for the AI."), "04-offline"),
    ("quest-offline", "online", None, ("04 · Offline", "Still writing quests",
        "Outside is where the signal drops. That is exactly where this has to work."), None),
    ("break", "later", None, ("05 · Go outside", "Phone in pocket. Eyes up.",
        "A deliberately boring timer. The app's job now is to be ignored."), "05-break"),
    ("later", "logged", None, ("05 · Go outside", "21 minutes later",
        "The page clock is shifted for the video. The break that gets logged is a real 21-minute interval."), None),
    ("logged", "end", None, ("06 · Pay it back", "Logged to SavannaTime",
        "A time entry with a client-generated id: queued on the phone, synced exactly once. The debt goes down."), "06-logged"),
]
NOTES = {"later": "TIME-LAPSE"}


def raw_video() -> Path:
    """Variable-rate screencast frames → constant 30 fps, scaled to the screen."""
    lst = BUILD / "frames.ffconcat"
    end = marks["end"] + 0.5
    lines = ["ffconcat version 1.0"]
    for i, f in enumerate(frames):
        nxt = frames[i + 1]["t"] if i + 1 < len(frames) else end
        lines.append(f"file '{(OUT / 'frames' / f['name']).as_posix()}'")
        lines.append(f"duration {max(nxt - f['t'], 0.001):.4f}")
    lines.append(f"file '{(OUT / 'frames' / frames[-1]['name']).as_posix()}'")
    lst.write_text("\n".join(lines))
    out = BUILD / "raw.mp4"
    ff("-f", "concat", "-safe", "0", "-i", str(lst),
       "-vf", f"fps={FPS},scale={SCREEN_W}:{SCREEN_H}:flags=lanczos,format=yuv420p",
       "-c:v", "libx264", "-crf", "14", "-preset", "medium", str(out))
    return out


def main() -> None:
    bg = background()
    base = phone_base(bg)
    base.save(BUILD / "base.png")
    screen_mask().save(BUILD / "mask.png")
    raw = raw_video()

    segments: list[tuple[Path, float]] = []
    vo_at: list[tuple[str, float]] = []
    t = 0.0

    # Title card: the intro narration starts over it and runs into sign-in.
    title = card(bg, "Savanna Grass", "Your screen time, turned into reasons to go outside.",
                 ["Gemma 3 1B", "on-device", "Flutter", "SavannaTime"],
                 "Hacktoberfest Open-Source AI Challenge  ·  Week 1: Touch Grass")
    title.save(BUILD / "title.png")
    seg = BUILD / "s00-title.mp4"
    ff("-loop", "1", "-t", "3.2", "-i", str(BUILD / "title.png"),
       "-vf", f"fps={FPS},fade=t=in:st=0:d=0.6,format=yuv420p", "-c:v", "libx264", "-crf", "16", str(seg))
    segments.append((seg, 3.2))
    vo_at.append(("01-intro", 0.6))
    vo_end = 0.6 + wav_len(vo["01-intro"])
    t = 3.2

    cursor = 0.0
    for i, (m0, m1, max_len, cap, v) in enumerate(plan, start=1):
        a = max(marks[m0], cursor)
        b = max(marks[m1], a + 0.5)  # never trim to zero frames
        natural = b - a
        speed = 1.0 if max_len is None or natural <= max_len else natural / max_len
        shown = natural / speed
        # Narration starts with its clip (or after the previous line ends) and
        # the clip holds its last frame until the line is finished.
        need = 0.0
        if v:
            start = max(t + 0.25, vo_end + 0.35)
            vo_at.append((v, start))
            vo_end = start + wav_len(vo[v])
            need = vo_end + 0.4 - t
        if i < len(plan) and plan[i][4] is None:
            need = max(0.0, need - 3.0)  # the next clip can carry the tail
        dur = max(shown, need, 1.5)
        cursor = b
        eyebrow, head, body = cap
        note = NOTES.get(m0, "")
        if speed > 1.05:
            note = f"SPED UP {speed:.0f}×  ·  {natural:.0f} S REAL TIME"
        cap_png = BUILD / f"cap{i:02d}.png"
        caption(eyebrow, head, body, note).save(cap_png)
        seg = BUILD / f"s{i:02d}.mp4"
        flt = (
            f"[0:v]trim=start={a:.3f}:end={b:.3f},setpts=(PTS-STARTPTS)/{speed:.4f},"
            f"tpad=stop_mode=clone:stop_duration={dur:.3f},trim=duration={dur:.3f},fps={FPS}[scr];"
            f"[scr][3:v]alphamerge[scrm];"
            f"[1:v][scrm]overlay={PHONE_X}:{PHONE_Y}[ph];"
            f"[ph][2:v]overlay=0:0,format=yuv420p[v]"
        )
        ff("-i", str(raw), "-loop", "1", "-i", str(BUILD / "base.png"),
           "-loop", "1", "-i", str(cap_png), "-loop", "1", "-i", str(BUILD / "mask.png"),
           "-filter_complex", flt, "-map", "[v]", "-t", f"{dur:.3f}",
           "-c:v", "libx264", "-crf", "16", "-preset", "medium", str(seg))
        segments.append((seg, dur))
        t += dur
        print(f"{m0:>14}: raw {natural:5.1f}s ×{speed:4.1f} → {dur:4.1f}s  (t={t:5.1f})")

    # End card carries the outro line.
    end = card(bg, "Savanna Grass", "github.com/alphaolomi/savanna-grass",
               ["open source", "on-device", "no AI vendor", "go outside"],
               "Recorded against a local SavannaTime server with a seeded test account. Nothing mocked.")
    end.save(BUILD / "end.png")
    start = max(t + 0.4, vo_end + 0.4)
    vo_at.append(("07-outro", start))
    end_len = start - t + wav_len(vo["07-outro"]) + 2.2
    seg = BUILD / "s99-end.mp4"
    ff("-loop", "1", "-t", f"{end_len:.3f}", "-i", str(BUILD / "end.png"),
       "-vf", f"fps={FPS},fade=t=in:st=0:d=0.5,fade=t=out:st={end_len - 1.2:.3f}:d=1.2,format=yuv420p",
       "-c:v", "libx264", "-crf", "16", str(seg))
    segments.append((seg, end_len))
    total = t + end_len

    concat = BUILD / "segments.txt"
    concat.write_text("\n".join(f"file '{s.as_posix()}'" for s, _ in segments))
    video = BUILD / "video.mp4"
    # Re-encode the join: stream-copying segments built from different
    # sources (still cards vs. app footage) turns the tail of the video black.
    ff("-f", "concat", "-safe", "0", "-i", str(concat), "-vf", f"fps={FPS},format=yuv420p",
       "-c:v", "libx264", "-crf", "17", "-preset", "medium", str(video))

    # Narration on its own bus; music ducks under it.
    inputs, parts = [], []
    for k, (name, at) in enumerate(vo_at):
        inputs += ["-i", str(vo[name])]
        ms = int(at * 1000)
        parts.append(f"[{k}:a]aresample=48000,aformat=channel_layouts=stereo,adelay={ms}|{ms}[v{k}]")
    nv = len(vo_at)
    inputs += ["-i", str(OUT / "music.wav")]
    labels = "".join(f"[v{k}]" for k in range(nv))
    flt = ";".join(parts) + (
        f";{labels}amix=inputs={nv}:normalize=0,apad,atrim=duration={total:.3f},asplit=2[voice][key];"
        f"[{nv}:a]atrim=duration={total:.3f},volume=0.55,afade=t=out:st={total - 2.5:.3f}:d=2.5[mus];"
        f"[mus][key]sidechaincompress=threshold=0.02:ratio=8:attack=60:release=600[duck];"
        f"[voice][duck]amix=inputs=2:normalize=0,loudnorm=I=-16:TP=-1.5:LRA=9,aresample=48000[a]"
    )
    ff(*inputs, "-filter_complex", flt, "-map", "[a]", "-c:a", "pcm_s16le", str(BUILD / "audio.wav"))

    final = OUT / "savanna-grass-demo.mp4"
    ff("-i", str(video), "-i", str(BUILD / "audio.wav"), "-map", "0:v", "-map", "1:a",
       "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", str(final))
    print(f"→ {final}  ({total:.1f}s)")


if __name__ == "__main__":
    main()
