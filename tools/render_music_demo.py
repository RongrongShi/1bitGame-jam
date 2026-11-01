"""Render an original soundtrack sketch using only the Python standard library."""
from array import array
from pathlib import Path
import math
import random
import struct
import sys
import wave

RATE = 32000
HEAVY = "--heavy" in sys.argv
BEAT = 60 / (68 if HEAVY else 76)
BAR = 4 * BEAT
BARS = 8 if HEAVY else 12
LENGTH = BARS * BAR + 1.4
mix = array("f", [0.0]) * int(LENGTH * RATE)
rng = random.Random(194411)


def frequency(note):
    return 440 * 2 ** ((note - 69) / 12)


def tone(start, note, duration, gain, instrument="brass"):
    start = int(start * RATE)
    count = int(duration * RATE)
    hz = frequency(note)
    harmonics = (1, .36, .15, .06) if instrument == "brass" else (1, .24, .32, .10, .07)
    attack = .045 if instrument == "brass" else .028
    if instrument == "low_strings":
        harmonics = (1, .56, .31, .22, .15, .10)
        attack = .018
    release = min(.11, duration * .35)
    for i in range(min(count, len(mix) - start)):
        t = i / RATE
        envelope = max(0, min(1, t / attack, (duration - t) / release))
        envelope *= .83 + .17 * math.exp(-t * 6)
        phase = 2 * math.pi * hz * t + .008 * math.sin(2 * math.pi * 4.1 * t)
        sound = sum(weight * math.sin(phase * (index + 1)) for index, weight in enumerate(harmonics))
        mix[start + i] += sound * envelope * gain


def drum(start, gain, snare=False):
    start = int(start * RATE)
    duration = .19 if snare else .27
    low = 0.0
    lower = 0.0
    for i in range(min(int(duration * RATE), len(mix) - start)):
        t = i / RATE
        if snare:
            noise = rng.uniform(-1, 1)
            low += .29 * (noise - low)
            lower += .025 * (noise - lower)
            sound = (low - lower) * math.exp(-t * 31)
            sound += .13 * math.sin(2 * math.pi * 178 * t) * math.exp(-t * 38)
        else:
            phase = 2 * math.pi * (53 * t + 1.0 * (1 - math.exp(-t * 35)))
            sound = math.sin(phase) * math.exp(-t * 22)
        mix[start + i] += sound * gain * min(1, t / .002)


# Original four-bar harmonic cycle; no borrowed melody or audio samples.
progression = [
    (38, [53, 57]),  # D minor
    (34, [50, 53]),  # B-flat
    (31, [46, 50]),  # G minor
    (33, [49, 52]),  # A major
]
phrases = [
    [(0, 50, .7), (1, 53, .45), (1.75, 52, .45), (2.5, 50, .85)],
    [(.25, 45, .65), (1.25, 48, .65), (2.5, 46, .8)],
    [(0, 43, .8), (1.25, 46, .5), (2, 45, .6), (3, 50, .6)],
    [(.25, 49, .6), (1.5, 45, .75), (3, 49, .5)],
]

for bar in range(BARS):
    if HEAVY:
        root, chord = [
            (38, [50, 53, 57]), (38, [50, 53, 57]),
            (39, [51, 55, 58]), (38, [50, 53, 57]),
            (34, [50, 53, 58]), (31, [46, 50, 55]),
            (33, [49, 52, 57]), (38, [50, 53, 57]),
        ][bar]
        start = bar * BAR
        for beat in range(4):
            note = root + (12 if beat == 3 and bar in [1, 5] else 0)
            accent = 1.0 if beat in [0, 2] else .82
            tone(start + beat * BEAT, note, .58 * BEAT, .16 * accent, "low_strings")
            tone(start + beat * BEAT + .009, note - 12, .62 * BEAT, .055 * accent)
            if beat in [0, 2]:
                drum(start + beat * BEAT, .055)
        for beat in [.5, 2.5]:
            for note in chord:
                tone(start + beat * BEAT, note, .43 * BEAT, .045, "low_strings")
                tone(start + beat * BEAT + .012, note, .46 * BEAT, .018)
        # A sparse original upper voice appears only in the second half.
        if bar >= 4:
            for beat, note in [(1.25, [62, 63, 61, 62][bar - 4]), (3, [58, 60, 57, 62][bar - 4])]:
                tone(start + beat * BEAT, note, .66 * BEAT, .037, "reed")
        continue
    root, chord = progression[bar % 4]
    start = bar * BAR
    quiet = bar >= 8
    level = .56 if quiet else (.78 if bar < 4 else 1.0)
    for beat in [0, 2]:
        bass = root if beat == 0 else root + 7
        tone(start + beat * BEAT, bass, BEAT * .72, .135 * level)
        drum(start + beat * BEAT, .045 * level)
    for beat in [1, 3]:
        for note in chord:
            tone(start + beat * BEAT + .012, note, BEAT * .29, .025 * level)
        if not quiet or beat == 3:
            drum(start + beat * BEAT, .064 * level, snare=True)
    if not quiet and bar != 0:
        for beat, note, length in phrases[bar % 4]:
            # A slight phrase variation in the second statement.
            if bar == 6 and beat == 3:
                note = 53
            tone(start + beat * BEAT, note, length * BEAT, .067 * level, "reed")
    if quiet:
        tone(start + .08, root + 12, BAR * .90, .014, "reed")

# Quiet closing tonic and a short, dark room response.
tone(BARS * BAR, 38, .95, .10 if HEAVY else .060)
tone(BARS * BAR, 50, .85, .035 if HEAVY else .018, "reed")
dry = array("f", mix)
for delay, gain in [(.057, .10), (.131, .065), (.239, .035)]:
    offset = int(delay * RATE)
    for i in range(offset, len(mix)):
        mix[i] += dry[i - offset] * gain

# A restrained mono mix, with a little low-pass softening and clean fades.
state = 0.0
alpha = 1 - math.exp(-2 * math.pi * 3200 / RATE)
for i, sample in enumerate(mix):
    state += alpha * (sample - state)
    t = i / RATE
    envelope = min(1, t / .15, (LENGTH - t) / .8)
    mix[i] = state * max(0, envelope)
peak = max(abs(sample) for sample in mix)
gain = .78 / peak
samples = [sample * gain for sample in mix]
assert all(math.isfinite(sample) and abs(sample) < 1 for sample in samples)

output = Path(__file__).resolve().parents[1] / "assets/audio/music_drafts"
output.mkdir(parents=True, exist_ok=True)
name = "iron_ostinato_preview" if HEAVY else "weary_march_preview"
with wave.open(str(output / (name + ".wav")), "wb") as stream:
    stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
    stream.writeframes(b"".join(struct.pack("<h", round(sample * 32767)) for sample in samples))
(output / ("iron_ostinato_README.md" if HEAVY else "README.md")).write_text(
    "# Iron Ostinato: original procedural music study\n\n"
    "68 BPM, approximately 30 seconds. Repeated low strings-like notes, octave bass, "
    "heavy offbeat chords, restrained percussion and a sparse second-half upper voice.\n"
    "Original composition and synthesis; no borrowed melody, audio samples or generative audio model.\n"
    "This is a timbre/composition sketch, not a realistic orchestra or a seamless loop. "
    "Not connected to gameplay.\n" if HEAVY else
    "# Weary March: original procedural music study\n\n"
    "76 BPM, D minor, approximately 39 seconds. 32 kHz / 16-bit mono PCM WAV.\n"
    "0-12.6 s: restrained introduction; 12.6-25.3 s: fuller theme; "
    "25.3-37.9 s: quieter work arrangement, followed by a closing tonic.\n\n"
    "All melodies, synthesis and percussion were created for this project. "
    "No third-party recordings or game melodies were used. "
    "Brass/reed timbres are approximate procedural sketches, not sampled instruments.\n"
    "This is an audition track, not a seamless loop, and is not connected to gameplay.\n",
    encoding="utf-8",
)
print(f"Created {output / (name + '.wav')}")
print(f"PASS: {len(samples) / RATE:.2f} seconds; peak {max(abs(s) for s in samples):.3f}; no clipping")
