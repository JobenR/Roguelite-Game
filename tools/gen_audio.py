"""Generates every sound in the game as small WAV files, in code.

The palette is Japanese: taiko drums for impacts and warnings, plucked koto
strings for rewards, breathy brush noise for shots and splats. Re-run to
regenerate after changing a recipe:

    python3 tools/gen_audio.py

Needs only numpy. Output: assets/audio/*.wav (mono, 22050 Hz, 16-bit).
"""
import os
import wave
import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack=0.005, decay=6.0):
    x = np.arange(n) / RATE
    return np.minimum(1.0, x / max(attack, 1e-4)) * np.exp(-decay * x)


def lowpass(x, alpha):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def noise(seconds):
    return rng.uniform(-1.0, 1.0, int(RATE * seconds))


def pluck(freq, seconds, bright=0.5):
    """Karplus-Strong plucked string: the koto."""
    n = int(RATE * seconds)
    period = max(2, int(RATE / freq))
    buf = rng.uniform(-1.0, 1.0, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = (bright * buf[i % period] + (1.0 - bright) * buf[(i + 1) % period]) * 0.996
    return out * env(n, 0.002, 2.5)


def taiko(seconds=0.7, pitch=92.0, punch=1.0):
    """A drum: a sine that drops in pitch, with a noisy stick attack."""
    x = t(seconds)
    freq = pitch * (0.5 + 0.5 * np.exp(-9.0 * x))
    body = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-5.0 * x)
    stick = lowpass(noise(seconds), 0.35) * np.exp(-60.0 * x) * 0.6 * punch
    return body + stick


def bell(freq, seconds):
    x = t(seconds)
    out = np.zeros_like(x)
    for mult, amp, decay in [(1.0, 1.0, 2.2), (2.76, 0.5, 3.5), (5.4, 0.25, 5.0), (8.93, 0.12, 7.0)]:
        out += amp * np.sin(2 * np.pi * freq * mult * x) * np.exp(-decay * x)
    return out


def place(dst, src, at_seconds, gain=1.0):
    start = int(at_seconds * RATE)
    end = min(len(dst), start + len(src))
    if end > start:
        dst[start:end] += src[: end - start] * gain


def save(name, data, peak=0.8):
    data = np.asarray(data, dtype=np.float64)
    m = np.max(np.abs(data))
    if m > 0:
        data = data / m * peak
    pcm = (data * 32767.0).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())


# Pentatonic scale (D minor pentatonic), the notes every tune here uses.
PENTA = [146.83, 174.61, 196.0, 220.0, 261.63, 293.66, 349.23, 392.0, 440.0, 523.25, 587.33]

# --- one-shot effects -------------------------------------------------------
x = t(0.07)
save("shoot", lowpass(noise(0.07), 0.5) * np.exp(-55.0 * x) + 0.4 * np.sin(2 * np.pi * 520 * x) * np.exp(-70.0 * x), 0.5)

x = t(0.06)
save("hit", np.sin(2 * np.pi * (220 - 1400 * x) * x) * np.exp(-45.0 * x), 0.45)

x = t(0.22)
wet = lowpass(noise(0.22), 0.18) * np.exp(-14.0 * x)
save("splat", wet + 0.5 * np.sin(2 * np.pi * (160 - 380 * x) * x) * np.exp(-18.0 * x), 0.7)

save("gem", pluck(880.0, 0.16, 0.6), 0.35)
save("click", pluck(1320.0, 0.05, 0.3) + 0.3 * lowpass(noise(0.05), 0.6) * np.exp(-90.0 * t(0.05)), 0.4)

card = np.zeros(int(RATE * 0.5))
place(card, pluck(PENTA[6], 0.45), 0.0)
place(card, pluck(PENTA[8], 0.4), 0.06, 0.7)
save("card", card, 0.6)

levelup = np.zeros(int(RATE * 0.9))
for i, note in enumerate([PENTA[4], PENTA[6], PENTA[8], PENTA[10]]):
    place(levelup, pluck(note, 0.6), i * 0.09)
save("levelup", levelup, 0.75)

milestone = np.zeros(int(RATE * 1.0))
place(milestone, pluck(PENTA[5], 0.8), 0.0)
place(milestone, pluck(PENTA[8], 0.8), 0.14)
place(milestone, bell(PENTA[10], 0.8), 0.14, 0.25)
save("milestone", milestone, 0.7)

x = t(0.7)
whoosh = lowpass(noise(0.7), 0.08) * np.sin(np.pi * np.minimum(1.0, x / 0.7)) ** 2
tone = np.sin(2 * np.pi * (110 + 180 * x) * x) * np.exp(-3.0 * x)
save("pulse", whoosh * 1.4 + tone * 0.6, 0.8)

x = t(0.25)
save("fizzle", lowpass(noise(0.25), 0.1) * np.exp(-16.0 * x) + 0.4 * np.sin(2 * np.pi * (180 - 300 * x) * x) * np.exp(-14.0 * x), 0.4)

save("bomb", taiko(0.8, 80.0, 1.4) + 0.4 * lowpass(noise(0.8), 0.06) * np.exp(-5.0 * t(0.8)), 0.9)

x = t(0.28)
save("hurt", taiko(0.28, 130.0, 1.6) + 0.35 * np.sin(2 * np.pi * 311 * x) * np.exp(-16.0 * x), 0.8)

warning = np.zeros(int(RATE * 1.0))
place(warning, taiko(0.6, 104.0), 0.0)
place(warning, taiko(0.6, 104.0), 0.28)
save("warning", warning, 0.85)

boss = np.zeros(int(RATE * 2.2))
place(boss, taiko(1.2, 62.0, 1.2), 0.0)
place(boss, bell(73.4, 2.0), 0.05, 0.9)
place(boss, taiko(1.0, 62.0, 1.2), 0.55, 0.8)
save("boss", boss, 0.9)

save("glyph", bell(PENTA[8], 1.4) + 0.5 * bell(PENTA[10], 1.4), 0.7)

victory = np.zeros(int(RATE * 2.6))
for i, note in enumerate([PENTA[4], PENTA[5], PENTA[6], PENTA[8], PENTA[10]]):
    place(victory, pluck(note, 1.4), i * 0.16)
place(victory, bell(PENTA[5] * 2, 1.6), 0.8, 0.35)
place(victory, taiko(0.9, 74.0), 0.8, 0.8)
save("victory", victory, 0.85)

death = np.zeros(int(RATE * 2.0))
for i, note in enumerate([PENTA[6], PENTA[4], PENTA[2], PENTA[0]]):
    place(death, pluck(note, 1.3, 0.35), i * 0.28)
place(death, taiko(1.0, 55.0), 0.95, 0.7)
save("death", death, 0.8)

# --- music: a sparse koto line over a soft drone, loopable -------------------
BARS = 16
BEAT = 0.75
LENGTH = BARS * 4 * BEAT
music = np.zeros(int(RATE * LENGTH))
mrng = np.random.default_rng(11)
x = t(LENGTH)
# Drone: two detuned low sines with a slow swell, whole periods so it loops.
for freq, amp in [(73.42, 0.22), (110.0, 0.14), (146.83, 0.08)]:
    cycles = round(freq * LENGTH)
    music += amp * np.sin(2 * np.pi * cycles * x / LENGTH) * (0.75 + 0.25 * np.sin(2 * np.pi * 2 * x / LENGTH))
# Melody: a phrase per two bars, wandering stepwise around the scale.
idx = 5
for bar in range(BARS):
    for step in range(8):
        if mrng.random() < (0.55 if step % 2 == 0 else 0.22):
            idx = int(np.clip(idx + mrng.choice([-2, -1, -1, 0, 1, 1, 2]), 2, 9))
            at = (bar * 8 + step) * BEAT / 2
            if at < LENGTH - 2.0:  # leave the tail clear so the loop point is clean
                place(music, pluck(PENTA[idx], 1.8, 0.45), at, 0.5)
    if bar % 4 == 0:
        place(music, taiko(0.9, 60.0, 0.6), bar * 4 * BEAT, 0.35)
        place(music, pluck(PENTA[0], 2.2, 0.3), bar * 4 * BEAT, 0.45)
save("music", music, 0.6)
print("wrote", len(os.listdir(OUT)), "files to", os.path.normpath(OUT))
