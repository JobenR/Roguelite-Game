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
# A little room around the koto, so it does not sound bone dry.
_n = int(RATE * 1.3)
_tail = np.random.default_rng(9).normal(0.0, 1.0, _n) * np.exp(-6.5 * np.arange(_n) / RATE)
_tail = fft_filter(_tail, lo=250.0, hi=4500.0)
_size = len(calm) + _n
_echo = np.fft.irfft(np.fft.rfft(calm, _size) * np.fft.rfft(_tail, _size), _size)[: len(calm)]
calm = 0.8 * calm + 0.2 * _echo * np.max(np.abs(calm)) / np.max(np.abs(_echo))
save("music", calm, 0.6)

# --- boss music: a slow, heavy, down-tuned guitar riff -----------------------
# Rendered at a higher sample rate than the effects, with the distortion run
# at four times that rate. Clipping creates overtones far above what a low
# sample rate can hold; without oversampling they fold back down as a harsh
# digital fizz, which is what made the earlier attempt sound artificial.
MR = 32000
TEMPO = 76.0
STEP = 60.0 / TEMPO / 4.0           # one sixteenth note
BAR = STEP * 16
BOSS_BARS = 8
BOSS_LEN = BAR * BOSS_BARS
LOW_B = 61.74                       # B1: the riff sits a fourth below a normal guitar


def mt(seconds):
    return np.arange(int(MR * seconds)) / MR


def mfilter(x, lo=None, hi=None, order=8, rate=MR):
    spectrum = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / rate)
    if hi:
        spectrum *= 1.0 / np.sqrt(1.0 + (f / hi) ** order)
    if lo:
        ratio = (np.maximum(f, 1e-6) / lo) ** (order // 2)
        spectrum *= ratio / np.sqrt(1.0 + ratio ** 2)
    return np.fft.irfft(spectrum, len(x))


def meq(x, bands, rate=MR):
    spectrum = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / rate)
    for lo, hi, db in bands:
        centre = np.sqrt(lo * hi)
        width = np.log2(hi / lo)
        spectrum *= 10.0 ** (db / 20.0 * np.exp(-0.5 * (np.log2(np.maximum(f, 1.0) / centre) / (width * 0.6)) ** 2))
    return np.fft.irfft(spectrum, len(x))


def oversample(x, factor):
    spectrum = np.fft.rfft(x)
    padded = np.zeros(len(x) * factor // 2 + 1, dtype=complex)
    padded[: len(spectrum)] = spectrum
    return np.fft.irfft(padded, len(x) * factor) * factor


def downsample(x, factor):
    spectrum = np.fft.rfft(x)
    n = len(x) // factor
    return np.fft.irfft(spectrum[: n // 2 + 1], n) / factor


_gstring_cache = {}


def gstring(freq, seconds, take):
    """A heavy-gauge guitar string: plucked near the bridge, slow to die away."""
    key = (round(freq, 3), round(seconds, 3), take)
    if key not in _gstring_cache:
        n = int(MR * seconds)
        period = max(2, int(round(MR / freq)))
        burst = np.random.default_rng(500 + take * 31 + int(freq * 7)).uniform(-1.0, 1.0, period)
        # Picking near the bridge cancels some overtones; a comb models that.
        pick = max(1, period // 7)
        burst = burst - 0.6 * np.roll(burst, pick)
        out = np.zeros(n)
        buf = burst.copy()
        for i in range(n):
            k = i % period
            out[i] = buf[k]
            buf[k] = (0.52 * buf[k] + 0.48 * buf[(k + 1) % period]) * 0.9992
        _gstring_cache[key] = out
    return _gstring_cache[key]


def power_chord(root, seconds, take, detune):
    return (gstring(root * detune, seconds, take) + 0.85 * gstring(root * 1.4983 * detune, seconds, take + 1)
            + 0.6 * gstring(root * 2.0 * detune, seconds, take + 2))


def high_gain_amp(x, drive):
    """Boost pedal, two clipping stages at 4x the sample rate, then a 4x12 cab."""
    x = mfilter(x, lo=95.0, order=4)
    x = meq(x, [(650.0, 1500.0, 7.0)])                     # the mid push of an overdrive pedal
    x = x / max(1e-9, np.max(np.abs(x)))
    up = oversample(x, 4)
    up = np.tanh(drive * up) + 0.12 * np.tanh(drive * 0.6 * up) ** 2   # slightly lopsided, like valves
    up = np.tanh(3.2 * up)
    up = mfilter(up, hi=7000.0, order=10, rate=MR * 4)
    y = downsample(up, 4)
    y = mfilter(y, lo=78.0, hi=5200.0, order=10)           # a guitar speaker passes little above 5 kHz
    return meq(y, [(95.0, 170.0, 5.5), (350.0, 620.0, -5.0), (2100.0, 3300.0, 6.0), (4200.0, 5200.0, -3.0)])


def room(x, wet, seconds=1.1, seed=3):
    """Reverb: convolve with a decaying burst of filtered noise, so nothing sounds bone dry."""
    n = int(MR * seconds)
    tail = np.random.default_rng(seed).normal(0.0, 1.0, n) * np.exp(-5.5 * np.arange(n) / MR / seconds * 1.6)
    tail = mfilter(tail, lo=220.0, hi=4800.0, order=4)
    size = len(x) + n
    echo = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(tail, size), size)[: len(x)]
    echo *= np.max(np.abs(x)) / max(1e-9, np.max(np.abs(echo)))
    return (1.0 - wet) * x + wet * echo


def mplace(dst, src, at_seconds, gain=1.0):
    start = int(at_seconds * MR)
    end = min(len(dst), start + len(src))
    if end > start:
        dst[start:end] += src[: end - start] * gain


# The riff. Each entry: (semitones above low B, length in sixteenths, palm-muted).
# Slow and sparse: long ringing chords, a pair of chugs, and the flat second
# and flat fifth that give doom its menace.
M, O = True, False
BAR_1 = [(0, 6, O), (0, 1, M), (0, 1, M), (3, 4, O), (0, 1, M), (0, 1, M), (1, 2, O)]
BAR_2 = [(0, 6, O), (0, 1, M), (0, 1, M), (6, 4, O), (5, 2, O), (3, 2, O)]
BAR_4 = [(0, 4, O), (0, 1, M), (0, 1, M), (8, 2, O), (7, 2, O), (6, 2, O), (3, 2, O), (1, 2, O)]
BAR_8 = [(0, 4, O), (1, 4, O), (0, 8, O)]
RIFF = [BAR_1, BAR_2, BAR_1, BAR_4, BAR_1, BAR_2, BAR_1, BAR_8]


def semitone(n):
    return LOW_B * 2.0 ** (n / 12.0)


def guitar_take(take, detune, octave=1.0):
    g = np.zeros(int(MR * BOSS_LEN))
    for bar, notes in enumerate(RIFF):
        step = 0
        for root, length, muted in notes:
            seconds = STEP * (0.9 if muted else length) + (0.0 if muted else 0.12)
            chord = power_chord(semitone(root) * octave, seconds, take, detune)
            fade = np.exp(-(22.0 if muted else 0.55) * mt(seconds)[: len(chord)])
            # A short fade-out so each chord is cut by the next, as a hand would mute it.
            tail = np.minimum(1.0, (len(chord) - np.arange(len(chord))) / (MR * 0.02))
            mplace(g, chord * fade * tail, bar * BAR + step * STEP, 0.85 if muted else 1.0)
            step += length
    return g


left = high_gain_amp(guitar_take(0, 1.0), 22.0)
right = high_gain_amp(guitar_take(10, 1.0038), 22.0)
low = high_gain_amp(guitar_take(20, 0.9965, 0.5), 14.0)    # a third guitar an octave down
guitars = left + right
guitars /= np.max(np.abs(guitars))
low /= np.max(np.abs(low))

# Bass: a distorted note under every chord, plus a clean sub.
bass = np.zeros(int(MR * BOSS_LEN))
for bar, notes in enumerate(RIFF):
    step = 0
    for root, length, muted in notes:
        seconds = STEP * (0.9 if muted else length)
        xx = mt(seconds)
        freq = semitone(root)
        tone = np.sin(2 * np.pi * freq * xx) + 0.5 * np.sin(2 * np.pi * freq * 0.5 * xx)
        mplace(bass, np.tanh(3.0 * tone) * np.exp(-(14.0 if muted else 0.8) * xx), bar * BAR + step * STEP)
        step += length
bass = mfilter(bass, hi=900.0, order=4)
bass /= np.max(np.abs(bass))


def boss_kick():
    xx = mt(0.32)
    freq = 42.0 + 120.0 * np.exp(-34.0 * xx)
    body = np.tanh(2.5 * np.sin(2 * np.pi * np.cumsum(freq) / MR)) * np.exp(-9.0 * xx)
    click = mfilter(np.random.default_rng(1).normal(0, 1, len(xx)), lo=2500.0, hi=7500.0, order=4) * np.exp(-150.0 * xx)
    return body + 0.5 * click


def boss_snare():
    xx = mt(0.42)
    crack = mfilter(np.random.default_rng(2).normal(0, 1, len(xx)), lo=600.0, hi=9000.0, order=4) * np.exp(-13.0 * xx)
    return np.tanh(1.8 * (crack + 0.8 * np.sin(2 * np.pi * 180.0 * xx) * np.exp(-20.0 * xx)))


def cymbal(seconds, decay, seed):
    xx = mt(seconds)
    return mfilter(np.random.default_rng(seed).normal(0, 1, len(xx)), lo=5500.0, order=4) * np.exp(-decay * xx)


KICK, SNARE, HAT, CRASH = boss_kick(), boss_snare(), cymbal(0.09, 55.0, 5), cymbal(2.4, 1.9, 6)


def drums(tier):
    d = np.zeros(int(MR * BOSS_LEN))
    for bar in range(BOSS_BARS):
        base = bar * BAR
        if bar % 4 == 0:
            mplace(d, CRASH, base, 0.5)
        # Half-time: a heavy kick on the one, the snare landing late on the three.
        kicks = [0, 6, 7] if tier == 1 else ([0, 3, 6, 7, 14] if tier == 2 else [0, 2, 3, 6, 7, 10, 11, 14, 15])
        for k in kicks:
            mplace(d, KICK, base + k * STEP, 1.0)
        mplace(d, SNARE, base + 8 * STEP, 1.0)
        for k in range(0, 16, 4 if tier == 1 else 2):
            mplace(d, HAT, base + k * STEP, 0.22)
        if bar == BOSS_BARS - 1:
            for k in (12, 13, 14, 15):
                mplace(d, SNARE, base + k * STEP, 0.55 + 0.1 * (k - 12))
    return d / np.max(np.abs(d))


def save_music(name, data, peak=0.82):
    data = np.asarray(data, dtype=np.float64)
    data = data / np.max(np.abs(data)) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(MR)
        f.writeframes((data * 32767.0).astype(np.int16).tobytes())


# Three tiers of the same riff, one per boss met in a run: guitars and a slow
# beat; then the octave-down guitar and a busier kick; then everything, louder.
for tier in (1, 2, 3):
    mix = 0.9 * guitars + 0.5 * bass + 1.0 * drums(tier)
    if tier >= 2:
        mix += 0.55 * low
    mix = room(mix, 0.16)
    mix = np.tanh((1.7 + 0.35 * tier) * mix / np.max(np.abs(mix)))   # a limiter, pushed harder each tier
    save_music("music_pressure%d" % tier, mix)
print("wrote", len(os.listdir(OUT)), "files to", os.path.normpath(OUT))
