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


def fft_filter(x, lo=None, hi=None):
    """Band-limits a whole buffer at once (much faster than lowpass())."""
    spectrum = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    if hi:
        spectrum *= 1.0 / np.sqrt(1.0 + (f / hi) ** 8)
    if lo:
        ratio = (f / lo) ** 4
        spectrum *= ratio / np.sqrt(1.0 + ratio ** 2)
    return np.fft.irfft(spectrum, len(x))


def fft_eq(x, bands):
    """Boosts or cuts frequency bands. bands: (low Hz, high Hz, gain in dB)."""
    spectrum = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    for lo, hi, db in bands:
        centre = np.sqrt(lo * hi)
        width = np.log2(hi / lo)
        spectrum *= 10.0 ** (db / 20.0 * np.exp(-0.5 * (np.log2(np.maximum(f, 1.0) / centre) / (width * 0.6)) ** 2))
    return np.fft.irfft(spectrum, len(x))


_string_cache = {}


def string(freq, seconds, damp=0.997, bright=0.5, variant=0):
    """A raw plucked string with no envelope, cached: the guitar's voice."""
    key = (round(freq, 2), round(seconds, 3), damp, bright, variant)
    if key not in _string_cache:
        n = int(RATE * seconds)
        period = max(2, int(RATE / freq))
        buf = np.random.default_rng(1000 + variant * 77 + int(freq * 10)).uniform(-1.0, 1.0, period)
        out = np.zeros(n)
        for i in range(n):
            out[i] = buf[i % period]
            buf[i % period] = (bright * buf[i % period] + (1.0 - bright) * buf[(i + 1) % period]) * damp
        _string_cache[key] = out
    return _string_cache[key]


def noise(seconds):
    return rng.uniform(-1.0, 1.0, int(RATE * seconds))


_pluck_cache = {}


def pluck(freq, seconds, bright=0.5):
    """Karplus-Strong plucked string: the koto. Cached, since tunes repeat notes."""
    key = (round(freq, 2), round(seconds, 3), bright)
    if key not in _pluck_cache:
        _pluck_cache[key] = _pluck(freq, seconds, bright)
    return _pluck_cache[key]


def _pluck(freq, seconds, bright=0.5):
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
# The sounds heard most often come in several variants, so they do not drone.
for i, (colour, tone, decay) in enumerate([(0.5, 520, 55.0), (0.38, 470, 62.0), (0.62, 600, 50.0), (0.45, 430, 70.0), (0.55, 560, 58.0)]):
    x = t(0.07)
    save("shoot%d" % (i + 1), lowpass(noise(0.07), colour) * np.exp(-decay * x) + 0.35 * np.sin(2 * np.pi * tone * x) * np.exp(-70.0 * x), 0.5)

for i, (start, drop) in enumerate([(220, 1400), (260, 1700), (190, 1100), (240, 2000)]):
    x = t(0.06)
    save("hit%d" % (i + 1), np.sin(2 * np.pi * (start - drop * x) * x) * np.exp(-45.0 * x), 0.45)

for i, (colour, low, length) in enumerate([(0.18, 160, 0.22), (0.12, 130, 0.26), (0.25, 190, 0.18), (0.15, 110, 0.3), (0.22, 150, 0.2)]):
    x = t(length)
    wet = lowpass(noise(length), colour) * np.exp(-14.0 * x)
    save("splat%d" % (i + 1), wet + 0.5 * np.sin(2 * np.pi * (low - 380 * x * 0.22 / length) * x) * np.exp(-18.0 * x), 0.7)

# Gems climb the scale when picked up in a quick run.
for i, note in enumerate([587.33, 698.46, 783.99, 880.0, 1046.5, 1174.66, 1396.91, 1567.98]):
    save("gem%d" % (i + 1), pluck(note, 0.16, 0.6), 0.35)

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

# --- music -------------------------------------------------------------------
# Two tracks of identical length that play in step, so the game can fade
# between them: a calm koto line, and the same melody as heavy metal.
BARS = 16
BEAT = 0.75
LENGTH = BARS * 4 * BEAT            # 48 seconds
mrng = np.random.default_rng(11)
melody = []                         # (time, scale index): shared by both tracks
idx = 5
for bar in range(BARS):
    for step in range(8):
        if mrng.random() < (0.55 if step % 2 == 0 else 0.22):
            idx = int(np.clip(idx + mrng.choice([-2, -1, -1, 0, 1, 1, 2]), 2, 9))
            at = (bar * 8 + step) * BEAT / 2
            if at < LENGTH - 2.0:   # leave the tail clear so the loop point is clean
                melody.append((at, idx))

calm = np.zeros(int(RATE * LENGTH))
x = t(LENGTH)
for freq, amp in [(73.42, 0.22), (110.0, 0.14), (146.83, 0.08)]:
    cycles = round(freq * LENGTH)   # whole cycles, so the drone loops cleanly
    calm += amp * np.sin(2 * np.pi * cycles * x / LENGTH) * (0.75 + 0.25 * np.sin(2 * np.pi * 2 * x / LENGTH))
for at, i in melody:
    place(calm, pluck(PENTA[i], 1.8, 0.45), at, 0.5)
for bar in range(0, BARS, 4):
    place(calm, taiko(0.9, 60.0, 0.6), bar * 4 * BEAT, 0.35)
    place(calm, pluck(PENTA[0], 2.2, 0.3), bar * 4 * BEAT, 0.45)
save("music", calm, 0.6)

# Pressure: the same plucked melody, faster and busier, for boss fights. Three
# tiers, one per boss met in a run, each quicker and more insistent than the last.
def pressure(tier):
    beat = [0.625, 0.555, 0.5][tier - 1]            # 96, 108, 120 beats a minute
    length = BARS * 4 * beat
    scale = beat / BEAT
    out = np.zeros(int(RATE * length))
    xx = t(length)
    # Drone with a tremolo that quickens with the tier.
    for freq, amp_ in [(73.42, 0.2), (110.0, 0.16), (146.83, 0.1)]:
        cycles = round(freq * length)
        wobble = 0.7 + 0.3 * np.sin(2 * np.pi * round(length / beat / (4 - tier)) * xx / length)
        out += amp_ * np.sin(2 * np.pi * cycles * xx / length) * wobble
    # The melody, brighter, doubled an octave up from tier two.
    for at, i in melody:
        when = at * scale
        if when < length - 1.5:
            place(out, pluck(PENTA[i], 1.2, 0.5 + 0.06 * tier), when, 0.55)
            if tier >= 2:
                place(out, pluck(PENTA[i] * 2.0, 0.7, 0.6), when + beat / 4, 0.22)
    # A low plucked ostinato: eighths, then sixteenths at the top tier.
    step = beat / (4 if tier == 3 else 2)
    pattern = [0, 0, 2, 0, 4, 0, 2, 3] if tier < 3 else [0, 0, 4, 0, 2, 0, 4, 0, 0, 0, 5, 0, 4, 2, 3, 2]
    count = int(length / step)
    for k in range(count):
        if k * step < length - 0.3:
            accent = 1.0 if k % (len(pattern)) == 0 else 0.6
            place(out, pluck(PENTA[pattern[k % len(pattern)]], 0.22, 0.7), k * step, 0.38 * accent)
    # Taiko: a pulse that fills in as the tier rises.
    beats = int(length / beat)
    for k in range(beats):
        at = k * beat
        if at > length - 0.7:
            break
        if k % 4 == 0:
            place(out, taiko(0.6, 62.0, 1.0), at, 0.6)
        elif k % 2 == 0:
            place(out, taiko(0.45, 78.0, 0.9), at, 0.42)
        elif tier >= 2:
            place(out, taiko(0.3, 104.0, 0.8), at, 0.3)
        if tier == 3:
            place(out, taiko(0.2, 140.0, 0.7), at + beat / 2, 0.24)
    # Rim clicks keep time between drum hits.
    click_step = beat / 2
    for k in range(int(length / click_step)):
        if k % 2 == 1 and k * click_step < length - 0.2:
            cx = t(0.03)
            place(out, np.sin(2 * np.pi * 1800 * cx) * np.exp(-140.0 * cx), k * click_step, 0.1 + 0.04 * tier)
    return out


for tier in (1, 2, 3):
    save("music_pressure%d" % tier, pressure(tier), 0.66)
print("wrote", len(os.listdir(OUT)), "files to", os.path.normpath(OUT))
