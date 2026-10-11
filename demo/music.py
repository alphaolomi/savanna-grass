"""Synthesises the demo's music bed from scratch, so there is nothing to license.

    python demo/music.py <seconds> <out.wav>

A slow Am-F-C-G pad (soft sines with a few harmonics and long swells), a bed
of filtered-noise wind, and the occasional synthesised bird chirp.
"""
import sys
import wave

import numpy as np

SR = 48_000
dur = float(sys.argv[1]) if len(sys.argv) > 1 else 90.0
out = sys.argv[2] if len(sys.argv) > 2 else "music.wav"
n = int(SR * dur)
t = np.arange(n) / SR
rng = np.random.default_rng(7)


def hz(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


# Am, F, C, G voiced low and open.
chords = [[45, 52, 57, 60, 64], [41, 48, 53, 57, 60], [48, 55, 60, 64, 67], [43, 50, 55, 59, 62]]
bar = 4.0
left = np.zeros(n)
right = np.zeros(n)
for i in range(int(dur / bar) + 2):
    start = i * bar - 0.8  # overlap for smooth crossfades
    length = bar + 1.6
    s0, s1 = max(0, int(start * SR)), min(n, int((start + length) * SR))
    if s1 <= s0:
        continue
    tt = t[s0:s1] - start
    env = np.sin(np.pi * np.clip(tt / length, 0, 1)) ** 1.6
    for j, note in enumerate(chords[i % 4]):
        f = hz(note)
        detune = 1 + (j - 2) * 0.0015
        tone = (
            np.sin(2 * np.pi * f * detune * tt)
            + 0.30 * np.sin(2 * np.pi * 2 * f * tt + 0.3)
            + 0.12 * np.sin(2 * np.pi * 3 * f * tt + 1.1)
        )
        pan = 0.3 + 0.1 * j
        left[s0:s1] += tone * env * (1 - pan) * 0.06
        right[s0:s1] += tone * env * pan * 0.06

# Wind: brown-ish noise, slowly breathing.
noise = np.cumsum(rng.normal(0, 1, n))
noise -= np.convolve(noise, np.ones(4800) / 4800, mode="same")
noise /= np.max(np.abs(noise)) + 1e-9
gust = 0.5 + 0.5 * np.sin(2 * np.pi * t / 11.0) * np.sin(2 * np.pi * t / 4.3 + 1)
left += noise * gust * 0.025
right += np.roll(noise, 2400) * gust * 0.025

# Birds: short downward-then-up frequency sweeps, sparse and quiet.
for when in np.arange(6.0, dur - 2, 7.3) + rng.uniform(-1.5, 1.5, int((dur - 8) / 7.3) + 1)[: len(np.arange(6.0, dur - 2, 7.3))]:
    for k in range(rng.integers(2, 5)):
        c0 = int((when + k * 0.16) * SR)
        ln = int(0.09 * SR)
        if c0 + ln >= n:
            break
        tt = np.arange(ln) / SR
        f = 3200 + 900 * np.sin(np.pi * tt / tt[-1]) * (1 if k % 2 else -1)
        phase = 2 * np.pi * np.cumsum(f) / SR
        chirp = np.sin(phase) * np.sin(np.pi * tt / tt[-1]) ** 2 * 0.035
        side = rng.uniform(0.2, 0.8)
        left[c0 : c0 + ln] += chirp * (1 - side)
        right[c0 : c0 + ln] += chirp * side

# Fade in/out and normalise.
fade = np.minimum(1, np.minimum(t / 2.5, (dur - t) / 3.0)).clip(0, 1)
stereo = np.stack([left * fade, right * fade], axis=1)
stereo /= np.max(np.abs(stereo)) + 1e-9
stereo *= 0.6
pcm = (stereo * 32767).astype("<i2")
with wave.open(out, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print(f"wrote {out} ({dur:.1f}s)")
