#!/usr/bin/env python3
"""Generates the original fallback score and sound effects for Business as Usual.

Everything here is synthesised from scratch (no samples), so the prototype ships
with audio even before the licensed reference tracks are dropped into
res://audio/music/. Run from the repo root:

    python3 tools/gen_audio.py

Requires numpy. Output: audio/generated/*.wav (22.05 kHz, 16-bit mono).
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "generated")
rng = np.random.default_rng(1979)

NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5,
              "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi(name):
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NOTE_INDEX[pitch]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


# ---------------------------------------------------------------- instruments
def pizz(f, dur=0.45, bright=1.0):
    t = t_axis(dur)
    sig = np.zeros_like(t)
    for k in range(1, 7):
        sig += (1.0 / k ** 1.25) * np.sin(2 * np.pi * f * k * t + k) * np.exp(-t * (7 + k * 3 / bright))
    attack = np.minimum(1.0, t / 0.004)
    thump = rng.normal(0, 1, len(t)) * np.exp(-t * 90) * 0.08
    return (sig * attack + thump) * 0.5


def clarinet(f, dur, vib=0.006):
    t = t_axis(dur)
    vibrato = 1 + vib * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1, t / 0.25)
    ph = 2 * np.pi * f * np.cumsum(vibrato) / SR
    sig = np.sin(ph) + 0.38 * np.sin(3 * ph) + 0.16 * np.sin(5 * ph) + 0.06 * np.sin(7 * ph)
    env = np.minimum(1, t / 0.025) * np.minimum(1, (dur - t) / 0.06)
    return sig * np.clip(env, 0, 1) * 0.28


def glock(f, dur=0.9):
    t = t_axis(dur)
    sig = np.sin(2 * np.pi * f * t) + 0.32 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 6) \
        + 0.12 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 12)
    return sig * np.exp(-t * 3.8) * np.minimum(1, t / 0.002) * 0.22


def woodblock(pitch=900, dur=0.09):
    t = t_axis(dur)
    return (np.sin(2 * np.pi * pitch * t) * np.exp(-t * 70) + rng.normal(0, 1, len(t)) * np.exp(-t * 300) * 0.3) * 0.35


def shaker(dur=0.07):
    t = t_axis(dur)
    n = rng.normal(0, 1, len(t))
    n = np.diff(n, prepend=0)
    return n * np.exp(-t * 60) * np.minimum(1, t / 0.008) * 0.05


def timpani(f=70, dur=0.9):
    t = t_axis(dur)
    fr = f * (1 + 0.25 * np.exp(-t * 25))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    return (np.sin(ph) * np.exp(-t * 4.5) + rng.normal(0, 1, len(t)) * np.exp(-t * 40) * 0.25) * 0.6


def strings_trem(f, dur, rate=13.0):
    t = t_axis(dur)
    sig = np.zeros_like(t)
    for k in range(1, 9):
        sig += np.sin(2 * np.pi * f * k * t * (1 + 0.0015 * k)) / k
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * rate * t)
    env = np.minimum(1, t / 0.03) * np.minimum(1, (dur - t) / 0.05)
    return sig * trem * np.clip(env, 0, 1) * 0.16


def brass(f, dur):
    t = t_axis(dur)
    sig = np.zeros_like(t)
    bright = np.minimum(1, t / 0.08)
    for k in range(1, 10):
        sig += np.sin(2 * np.pi * f * k * t) / k * (bright ** (k * 0.4))
    env = np.minimum(1, t / 0.03) * np.minimum(1, (dur - t) / 0.12)
    return sig * np.clip(env, 0, 1) * 0.18


def place(buf, sig, start):
    i = int(start * SR)
    if i >= len(buf):
        return
    n = min(len(sig), len(buf) - i)
    buf[i:i + n] += sig[:n]


def reverb(sig, length=0.9, mix=0.18):
    ir_t = t_axis(length)
    ir = rng.normal(0, 1, len(ir_t)) * np.exp(-ir_t * 6.0)
    ir[0] = 0
    n = len(sig) + len(ir)
    size = 1 << (n - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(sig, size) * np.fft.rfft(ir, size), size)[:len(sig)]
    wet /= (np.max(np.abs(wet)) + 1e-9)
    return sig * (1 - mix) + wet * mix * np.max(np.abs(sig))


def finish(sig, peak=0.89):
    sig = np.tanh(sig * 1.2)
    m = np.max(np.abs(sig)) + 1e-9
    return sig / m * peak


def write(name, sig):
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(sig, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}.wav  {len(sig) / SR:5.1f}s")


# ---------------------------------------------------------------- music
CHORDS = {
    "C": ["C3", "E3", "G3"], "A7": ["A2", "C#3", "G3"], "Dm": ["D3", "F3", "A3"], "G7": ["G2", "B2", "F3"],
    "E7": ["E3", "G#3", "D3"], "F": ["F3", "A3", "C4"], "Fm": ["F3", "Ab3", "C4"], "Am": ["A2", "C3", "E3"],
}


def office_theme():
    """'Tiptoe Through the Quarterly Review' — a sneaky pizzicato office waltz-that-isn't."""
    bpm = 112
    beat = 60.0 / bpm
    bars = ["C", "A7", "Dm", "G7", "C", "E7", "F|Fm", "G7"]
    melody = [
        ["G4", "-", "C5", "-", "E5", "-", "D#5", "E5"],
        ["C#5", "-", "E5", "-", "G5", "-", "F5", "E5"],
        ["D5", "-", "F5", "-", "A4", "-", "-", "-"],
        ["B4", "C5", "D5", "-", "F5", "-", "D5", "B4"],
        ["G4", "-", "C5", "-", "E5", "-", "G5", "-"],
        ["G#5", "-", "E5", "-", "D5", "-", "B4", "-"],
        ["A4", "C5", "F5", "-", "Ab4", "C5", "F5", "-"],
        ["G4", "-", "-", "B4", "D5", "-", "G4", "-"],
    ]
    total_bars = 16
    buf = np.zeros(int(total_bars * 4 * beat * SR) + SR)
    for bar in range(total_bars):
        b0 = bar * 4 * beat
        name = bars[bar % 8]
        halves = name.split("|")
        for beat_i in range(4):
            chord = CHORDS[halves[0] if (beat_i < 2 or len(halves) == 1) else halves[1]]
            t = b0 + beat_i * beat
            if beat_i in (0, 2):  # oom
                root = midi(chord[0]) - 12 + (7 if beat_i == 2 else 0)
                place(buf, pizz(hz(root), 0.6, 0.6) * 1.2, t)
            else:  # pah
                for n in chord:
                    place(buf, pizz(hz(midi(n) + 12), 0.3) * 0.45, t + rng.uniform(0, 0.008))
            place(buf, woodblock(1100 if beat_i % 2 else 800) * (0.5 if beat_i % 2 else 0.3), t)
            place(buf, shaker(), t + beat / 2)
        if bar % 8 == 7:  # chromatic walk-up into the next phrase
            for k, n in enumerate(["G2", "G#2", "A2", "B2"]):
                place(buf, pizz(hz(midi(n)), 0.25, 0.7), b0 + 2 * beat + k * beat / 2)
        line = melody[bar % 8]
        second_pass = bar >= 8
        for slot, note in enumerate(line):
            if note == "-":
                continue
            dur = beat / 2 * (0.55 if slot % 2 else 0.8)
            # hold notes followed by rests a little longer
            if slot + 1 < 8 and line[slot + 1] == "-":
                dur = beat * 0.75
            t = b0 + slot * beat / 2
            place(buf, clarinet(hz(midi(note)), dur), t)
            if second_pass:
                place(buf, glock(hz(midi(note) + 12)), t)
    buf = buf[:int(total_bars * 4 * beat * SR)]
    return finish(reverb(buf, 1.1, 0.16), 0.8)


def brawl_theme():
    """'Meeting Has Escalated' — frantic tremolo strings and timpani, loopable."""
    bpm = 168
    beat = 60.0 / bpm
    bars = 8
    buf = np.zeros(int(bars * 4 * beat * SR) + SR)
    roots = ["D3", "D3", "Bb2", "A2", "D3", "F3", "E3", "A2"]
    riff = ["D5", "E5", "F5", "D5", "C#5", "D5", "A4", "-",
            "D5", "E5", "F5", "G5", "A5", "G5", "F5", "E5"]
    for bar in range(bars):
        b0 = bar * 4 * beat
        r = midi(roots[bar])
        for n in (r, r + 7, r + 12):
            place(buf, strings_trem(hz(n), 4 * beat), b0)
        place(buf, timpani(hz(r - 12)), b0)
        place(buf, timpani(hz(r - 12)) * 0.6, b0 + 2 * beat)
        if bar % 2 == 1:
            place(buf, timpani(hz(r - 5)) * 0.7, b0 + 3.5 * beat)
        for s in range(8):
            note = riff[(bar % 2) * 8 + s]
            if note != "-":
                place(buf, pizz(hz(midi(note)), 0.18, 1.5) * 0.9, b0 + s * beat / 2)
                place(buf, brass(hz(midi(note) - 12), beat / 2 * 0.8) * 0.5, b0 + s * beat / 2)
        for s in range(8):
            place(buf, shaker() * 2.0, b0 + s * beat / 2)
            place(buf, woodblock(1400) * (0.4 if s % 2 else 0.2), b0 + s * beat / 2)
    buf = buf[:int(bars * 4 * beat * SR)]
    return finish(reverb(buf, 0.7, 0.12), 0.8)


def happy_ending():
    """The sting when the cake arrives and everybody suddenly sits down nicely."""
    buf = np.zeros(int(4.0 * SR))
    seq = [("C5", 0.0), ("E5", 0.12), ("G5", 0.24), ("C6", 0.36)]
    for n, t in seq:
        place(buf, glock(hz(midi(n)), 1.5) * 1.3, t)
        place(buf, pizz(hz(midi(n) - 12), 0.4), t)
    for n in ("C4", "E4", "G4", "C5"):
        place(buf, brass(hz(midi(n)), 1.6) * 0.8, 0.55)
    place(buf, timpani(hz(midi("C2"))), 0.55)
    return finish(reverb(buf, 1.4, 0.25), 0.8)


# ---------------------------------------------------------------- sfx
def sfx_click():
    return finish(woodblock(1500, 0.05) * 1.0, 0.5)


def sfx_hover():
    return finish(woodblock(2200, 0.03), 0.18)


def sfx_blip():
    t = t_axis(0.05)
    return finish(np.sin(2 * np.pi * 620 * t) * np.exp(-t * 60) * np.minimum(1, t / 0.003), 0.35)


def sfx_notify():
    buf = np.zeros(int(0.7 * SR))
    place(buf, glock(hz(midi("E6")), 0.6), 0)
    place(buf, glock(hz(midi("B6")), 0.6), 0.11)
    return finish(buf, 0.6)


def sfx_buzz():
    t = t_axis(0.9)
    carrier = np.sign(np.sin(2 * np.pi * 155 * t)) * 0.5 + np.sin(2 * np.pi * 310 * t) * 0.3
    gate = ((t % 0.3) < 0.2).astype(float)
    return finish(carrier * gate * 0.5 * np.minimum(1, t / 0.01), 0.55)


def sfx_whoosh():
    t = t_axis(0.45)
    n = rng.normal(0, 1, len(t))
    out = np.zeros_like(n)
    a = 0.0
    cut = np.linspace(0.05, 0.5, len(t)) ** 1.5
    for i in range(len(n)):
        a += cut[i] * (n[i] - a)
        out[i] = a
    return finish(out * np.sin(np.pi * t / t[-1]) ** 2, 0.5)


def sfx_pop():
    t = t_axis(0.12)
    f = 300 + 900 * np.exp(-t * 40)
    return finish(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 30), 0.6)


def sfx_boing():
    t = t_axis(0.6)
    f = 180 * (1 + 0.5 * np.sin(2 * np.pi * 9 * t) * np.exp(-t * 4)) + 60 * t
    return finish(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4), 0.6)


def sfx_crickets():
    buf = np.zeros(int(2.4 * SR))
    for start in (0.1, 0.9, 1.7):
        for k in range(3):
            t = t_axis(0.05)
            chirp = np.sin(2 * np.pi * 4300 * t) * np.sin(np.pi * t / 0.05)
            place(buf, chirp * 0.6, start + k * 0.07)
    return finish(buf, 0.35)


def sfx_tada():
    buf = np.zeros(int(1.6 * SR))
    for i, n in enumerate(["C5", "E5", "G5"]):
        place(buf, brass(hz(midi(n)), 0.12), i * 0.09)
    for n in ("C5", "E5", "G5", "C6"):
        place(buf, brass(hz(midi(n)), 1.1) * 0.7, 0.3)
    place(buf, glock(hz(midi("C7")), 1.2), 0.3)
    return finish(reverb(buf, 0.8, 0.2), 0.7)


def sfx_sad_trombone():
    buf = np.zeros(int(2.6 * SR))
    notes = [("A3", 0.0, 0.35), ("G#3", 0.4, 0.35), ("G3", 0.8, 0.35), ("F#3", 1.2, 1.2)]
    for n, start, dur in notes:
        t = t_axis(dur)
        f = hz(midi(n)) * (1 + 0.012 * np.sin(2 * np.pi * 6 * t) * (t > 0.3))
        ph = 2 * np.pi * np.cumsum(f) / SR
        sig = sum(np.sin(k * ph) / k for k in range(1, 8))
        env = np.minimum(1, t / 0.04) * np.minimum(1, (dur - t) / 0.1)
        place(buf, sig * np.clip(env, 0, 1) * 0.3, start)
    return finish(buf, 0.6)


def sfx_crash():
    t = t_axis(1.0)
    n = rng.normal(0, 1, len(t)) * np.exp(-t * 5)
    thumps = np.zeros_like(t)
    for start in (0.0, 0.08, 0.21, 0.33):
        place(thumps, timpani(90, 0.5), start)
    return finish(n * 0.5 + thumps, 0.7)


def sfx_bonk():
    t = t_axis(0.18)
    f = 220 * np.exp(-t * 6)
    return finish(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 25) + rng.normal(0, 1, len(t)) * np.exp(-t * 80) * 0.4, 0.6)


def sfx_slide_whistle():
    t = t_axis(0.8)
    f = 500 + 1200 * (t / t[-1]) ** 1.3
    return finish(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / t[-1]) * 0.6, 0.45)


def sfx_kaching():
    buf = np.zeros(int(1.2 * SR))
    place(buf, woodblock(500, 0.1), 0)
    place(buf, glock(hz(midi("E7")), 0.9) * 1.4, 0.08)
    place(buf, glock(hz(midi("G#7")), 0.9) * 1.2, 0.1)
    return finish(buf, 0.6)


def sfx_bell():
    return finish(glock(hz(midi("A6")), 1.4) * 2 + glock(hz(midi("A6")) * 1.003, 1.4), 0.5)


def sfx_typing():
    buf = np.zeros(int(1.2 * SR))
    tt = 0.0
    while tt < 1.1:
        place(buf, woodblock(rng.uniform(1800, 2600), 0.025), tt)
        tt += rng.uniform(0.05, 0.13)
    return finish(buf, 0.3)


def sfx_deploy():
    buf = np.zeros(int(1.5 * SR))
    for i, n in enumerate(["C5", "D5", "E5", "G5", "A5", "C6"]):
        place(buf, pizz(hz(midi(n)), 0.4) + glock(hz(midi(n)), 0.4) * 0.5, i * 0.07)
    return finish(buf, 0.6)


def sfx_alarm():
    t = t_axis(1.6)
    f = 700 + 300 * np.sign(np.sin(2 * np.pi * 2.5 * t))
    return finish(np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.3 * np.minimum(1, t / 0.02), 0.4)


def sfx_page():
    t = t_axis(0.25)
    n = np.diff(rng.normal(0, 1, len(t)), prepend=0)
    return finish(n * np.sin(np.pi * t / t[-1]) ** 3, 0.3)


def sfx_gulp():
    t = t_axis(0.25)
    f = 140 + 160 * np.sin(np.pi * t / t[-1])
    return finish(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / t[-1]), 0.5)


def sfx_rumble():
    t = t_axis(3.0)
    n = rng.normal(0, 1, len(t))
    out = np.zeros_like(n)
    a = 0.0
    for i in range(len(n)):
        a += 0.02 * (n[i] - a)
        out[i] = a
    clatter = np.zeros_like(t)
    for k in range(60):
        place(clatter, woodblock(rng.uniform(600, 1600), 0.05) * rng.uniform(0.2, 0.7), rng.uniform(0.2, 2.9))
    env = np.minimum(1, t / 0.6)
    return finish(out * 8 * env + clatter, 0.7)


def main():
    write("music_office_theme", office_theme())
    write("music_brawl", brawl_theme())
    write("sting_happy_ending", happy_ending())
    for name, fn in [("click", sfx_click), ("hover", sfx_hover), ("blip", sfx_blip), ("notify", sfx_notify),
                     ("buzz", sfx_buzz), ("whoosh", sfx_whoosh), ("pop", sfx_pop), ("boing", sfx_boing),
                     ("crickets", sfx_crickets), ("tada", sfx_tada), ("sad_trombone", sfx_sad_trombone),
                     ("crash", sfx_crash), ("bonk", sfx_bonk), ("slide_whistle", sfx_slide_whistle),
                     ("kaching", sfx_kaching), ("bell", sfx_bell), ("typing", sfx_typing),
                     ("deploy", sfx_deploy), ("alarm", sfx_alarm), ("page", sfx_page), ("gulp", sfx_gulp),
                     ("rumble", sfx_rumble)]:
        write("sfx_" + name, fn())


if __name__ == "__main__":
    main()
