#!/usr/bin/env python3
"""Castle Dominion audio generator.

Synthesizes ALL music and sound effects for the game from code (additive synthesis,
filtered noise, synthetic drums and convolution reverb), so every sound is original
and license-free. Writes OGG Vorbis files into assets/audio/{music,sfx}.

    python3 tools/synth_audio.py            # everything
    python3 tools/synth_audio.py sfx        # only sound effects
    python3 tools/synth_audio.py music      # only music

Requires numpy and ffmpeg (libvorbis).
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 32000
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
RNG = np.random.default_rng(1234)


# ----------------------------------------------------------------------------- helpers

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_adsr(n, a, d, s, r, sustain_len=None):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, n - a_n - d_n - r_n) if sustain_len is None else int(sustain_len * SR)
    e = np.concatenate([
        np.linspace(0, 1, max(a_n, 1), endpoint=False),
        np.linspace(1, s, max(d_n, 1), endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, max(r_n, 1)),
    ])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def exp_decay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def fft_filter(x, lo=None, hi=None, slope=4.0):
    """Zero-phase spectral band filter with soft (Butterworth-like) edges."""
    n = len(x)
    if n == 0:
        return x
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if hi is not None:
        g *= 1.0 / np.sqrt(1.0 + (f / hi) ** (2 * slope))
    if lo is not None:
        with np.errstate(divide="ignore"):
            g *= 1.0 / np.sqrt(1.0 + (lo / np.maximum(f, 1e-3)) ** (2 * slope))
    return np.fft.irfft(X * g, n)


def noise(n):
    return RNG.uniform(-1, 1, n)


def pitch_sweep_sine(f0, f1, dur, curve=3.0):
    n = int(dur * SR)
    k = np.linspace(0, 1, n)
    f = f1 + (f0 - f1) * np.exp(-k * curve)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def reverb(x, seconds=1.8, wet=0.3, damp=4000):
    n_ir = int(seconds * SR)
    ir = noise(n_ir) * exp_decay(n_ir, seconds / 6.0)
    ir = fft_filter(ir, lo=120, hi=damp)
    ir[: int(0.01 * SR)] *= np.linspace(0, 1, int(0.01 * SR))
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    m = len(x) + n_ir
    size = 1 << int(np.ceil(np.log2(m)))
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:m]
    out = np.concatenate([x, np.zeros(n_ir)]) * (1 - wet) + y * wet * 2.2
    return out


def normalize(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def soft_clip(x, drive=1.4):
    return np.tanh(x * drive) / np.tanh(drive)


def write_ogg(path, x, quality=4, stereo=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if stereo is None:
        data = np.clip(x, -1, 1)
        channels = 1
    else:
        data = np.clip(np.stack(stereo, axis=1), -1, 1).reshape(-1)
        channels = 2
    pcm = (data * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = tmp.name
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis",
                    "-q:a", str(quality), path], check=True)
    os.unlink(wav_path)


def mix(*layers):
    """Sum layers of different lengths (each optionally (array, offset_seconds))."""
    items = [(l, 0.0) if not isinstance(l, tuple) else l for l in layers]
    n = max(len(a) + int(o * SR) for a, o in items)
    out = np.zeros(n)
    for a, o in items:
        i = int(o * SR)
        out[i:i + len(a)] += a
    return out


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# ----------------------------------------------------------------------------- instruments

def additive(freq, dur, amps, vib_rate=5.0, vib_depth=0.0, detune_cents=0.0, phase_rand=True):
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + vib_depth * np.sin(2 * np.pi * vib_rate * t + RNG.uniform(0, 6.28)) * np.clip(t * 2, 0, 1)
    f = freq * 2 ** (detune_cents / 1200.0)
    phase = 2 * np.pi * np.cumsum(f * vib) / SR
    out = np.zeros(n)
    for k, a in enumerate(amps, start=1):
        if a <= 0 or k * f > SR / 2.2:
            continue
        out += a * np.sin(k * phase + (RNG.uniform(0, 6.28) if phase_rand else 0))
    return out


def strings(freq, dur, vol=0.2, attack=0.25):
    amps = [1.0 / k ** 1.15 for k in range(1, 18)]
    x = sum(additive(freq, dur, amps, 5.2, 0.006, d) for d in (-9, 0, 8))
    return x * env_adsr(len(x), attack, 0.2, 0.85, min(0.5, dur * 0.4)) * vol / 3


def staccato(freq, dur, vol=0.2):
    amps = [1.0 / k for k in range(1, 14)]
    x = additive(freq, dur, amps, 0, 0) + additive(freq, dur, amps, 0, 0, 7)
    return x * env_adsr(len(x), 0.005, 0.06, 0.25, 0.05) * vol / 2


def brass(freq, dur, vol=0.25, bright=1.0):
    n = int(dur * SR)
    env = env_adsr(n, 0.06, 0.15, 0.8, min(0.25, dur * 0.3))
    out = np.zeros(n)
    t = np.arange(n) / SR
    phase = 2 * np.pi * freq * t * (1 + 0.004 * np.sin(2 * np.pi * 5 * t))
    for k in range(1, 16):
        # brighter harmonics swell in with the envelope (classic brass behaviour)
        a = (1.0 / k) * np.clip(env * bright * 1.6 - (k - 1) * 0.09, 0, 1)
        out += a * np.sin(k * phase)
    return out * env * vol


def choir(freq, dur, vol=0.18, vowel="ah"):
    formants = {"ah": [(700, 1.0), (1220, 0.6), (2600, 0.25)], "oh": [(450, 1.0), (800, 0.7), (2830, 0.15)]}[vowel]
    amps = []
    for k in range(1, 30):
        fk = k * freq
        a = sum(g * np.exp(-((fk - fc) / 110.0) ** 2) for fc, g in formants) + 0.02 / k
        amps.append(a)
    x = sum(additive(freq, dur, amps, 4.8, 0.01, d) for d in (-12, 0, 11))
    return x * env_adsr(len(x), 0.35, 0.2, 0.9, min(0.6, dur * 0.4)) * vol / 3


def harp(freq, dur, vol=0.22):
    n = int(dur * SR)
    out = np.zeros(n)
    t = np.arange(n) / SR
    for k in range(1, 10):
        out += (1.0 / k ** 1.4) * np.sin(2 * np.pi * freq * k * t) * np.exp(-t * (1.8 + k * 0.9))
    out[: int(0.003 * SR)] *= np.linspace(0, 1, int(0.003 * SR))
    return out * vol


def taiko(dur=0.9, vol=0.9, pitch=70):
    n = int(dur * SR)
    body = pitch_sweep_sine(pitch * 1.8, pitch, dur, 18) * exp_decay(n, 0.22)
    slap = fft_filter(noise(n), lo=80, hi=1200) * exp_decay(n, 0.03)
    return (body * 0.9 + slap * 0.5) * vol


def timpani(freq, dur=1.4, vol=0.6):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = (np.sin(2 * np.pi * freq * t) + 0.5 * np.sin(2 * np.pi * freq * 1.5 * t) + 0.3 * np.sin(2 * np.pi * freq * 1.98 * t))
    x *= exp_decay(n, 0.45)
    x += fft_filter(noise(n), lo=60, hi=900) * exp_decay(n, 0.04) * 0.6
    return x * vol


def snare(dur=0.25, vol=0.4):
    vol *= 0.55
    n = int(dur * SR)
    tone = pitch_sweep_sine(330, 180, dur, 20) * exp_decay(n, 0.05)
    nz = fft_filter(noise(n), lo=1200, hi=5500) * exp_decay(n, 0.06)
    return (tone * 0.4 + nz) * vol


def cymbal(dur=2.0, vol=0.25):
    n = int(dur * SR)
    return fft_filter(noise(n), lo=4500, hi=11000) * exp_decay(n, 0.45) * vol * 0.6


def place(buf, x, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i]


# ----------------------------------------------------------------------------- music

def chord_notes(root, kind):
    iv = {"m": [0, 3, 7], "M": [0, 4, 7], "sus": [0, 5, 7], "dim": [0, 3, 6]}[kind]
    return [root + i for i in iv]


def finish_loop(mix, loop_len, tail_wet=0.32, seconds=2.2):
    """Adds reverb and folds the tail into the start so the loop is seamless."""
    n = int(loop_len * SR)
    left = reverb(mix, seconds, tail_wet)
    out = left[:n].copy()
    tail = left[n:]
    out[: len(tail)] += tail[: n]
    return out


def stereo_widen(x, amount=0.012):
    d = int(amount * SR)
    l = x
    r = np.concatenate([np.zeros(d), x[:-d]]) if d > 0 else x
    return 0.9 * l + 0.1 * r, 0.9 * r + 0.1 * l


def music_menu():
    bpm = 76
    beat = 60 / bpm
    prog = [(50, "m"), (46, "M"), (53, "M"), (48, "M"), (50, "m"), (43, "m"), (45, "M"), (45, "M")]
    bars = len(prog) * 2
    loop = bars * 4 * beat
    mix = np.zeros(int((loop + 4) * SR))
    melody = [74, 72, 69, 70, 69, 65, 67, 69, 74, 77, 76, 74, 72, 70, 69, 69]
    for b in range(bars):
        root, kind = prog[(b // 2) % len(prog)]
        t0 = b * 4 * beat
        notes = chord_notes(root, kind)
        if b % 2 == 0:
            for m in notes:
                place(mix, strings(midi_hz(m), 8 * beat, 0.12, 0.6), t0)
            place(mix, strings(midi_hz(root - 12), 8 * beat, 0.14, 0.6), t0)
            if b >= 4:
                place(mix, choir(midi_hz(notes[0] + 12), 8 * beat, 0.07, "oh"), t0)
        arp = notes + [notes[0] + 12, notes[1] + 12, notes[2], notes[1]]
        for i, m in enumerate(arp):
            place(mix, harp(midi_hz(m + 12), 1.6, 0.11), t0 + i * beat * 0.5)
        if b >= 8:
            m = melody[b - 8 if b - 8 < len(melody) else 0]
            place(mix, brass(midi_hz(m), 3.6 * beat, 0.09, 0.6), t0 + 0.02)
        if b % 4 == 0:
            place(mix, timpani(midi_hz(root - 24), 2.0, 0.35), t0)
    out = finish_loop(mix, loop, 0.38, 2.8)
    return normalize(soft_clip(out, 1.1), 0.82)


def music_battle():
    bpm = 132
    beat = 60 / bpm
    prog = [(52, "m"), (48, "M"), (50, "M"), (47, "m")]
    bars = 16
    loop = bars * 4 * beat
    mix = np.zeros(int((loop + 4) * SR))
    lead = [76, 79, 81, 79, 76, 74, 76, 71, 72, 74, 76, 79, 81, 83, 81, 79]
    for b in range(bars):
        root, kind = prog[b % len(prog)]
        notes = chord_notes(root, kind)
        t0 = b * 4 * beat
        # string ostinato (16ths)
        pattern = [0, 0, 2, 0, 1, 0, 2, 1, 0, 0, 2, 0, 1, 2, 1, 0]
        for i, p in enumerate(pattern):
            place(mix, staccato(midi_hz(notes[p] - 12 + (12 if i % 8 == 6 else 0)), beat * 0.24, 0.07), t0 + i * beat / 4)
        place(mix, strings(midi_hz(root - 24), 4 * beat, 0.12, 0.05), t0)
        for m in notes:
            place(mix, strings(midi_hz(m), 4 * beat, 0.05, 0.15), t0)
        # drums: taiko on 1 and 3, syncopated low hits, snare on 2/4
        for hit in [0, 1.5, 2, 3.5]:
            place(mix, taiko(0.8, 0.55, 62), t0 + hit * beat)
        for hit in [1, 3]:
            place(mix, snare(0.25, 0.22), t0 + hit * beat)
        if b % 4 == 3:
            for k in range(8):
                place(mix, snare(0.2, 0.12 + k * 0.02), t0 + 2 * beat + k * beat / 4)
        if b % 4 == 0:
            place(mix, cymbal(2.4, 0.16), t0)
            place(mix, brass(midi_hz(notes[0]), beat * 1.5, 0.1, 1.0), t0)
            place(mix, brass(midi_hz(notes[2]), beat * 1.5, 0.08, 1.0), t0)
        if b >= 8:
            place(mix, brass(midi_hz(lead[b - 8]), 3.8 * beat, 0.1, 1.1), t0)
            place(mix, brass(midi_hz(lead[(b - 8 + 8) % 16] - 12), 3.8 * beat, 0.06, 0.8), t0)
    out = finish_loop(mix, loop, 0.22, 1.6)
    return normalize(soft_clip(out, 1.5), 0.86)


def music_boss():
    bpm = 144
    beat = 60 / bpm
    prog = [(48, "m"), (49, "M"), (48, "m"), (46, "m"), (48, "m"), (49, "M"), (44, "M"), (43, "M")]
    bars = 16
    loop = bars * 4 * beat
    mix = np.zeros(int((loop + 4) * SR))
    for b in range(bars):
        root, kind = prog[b % len(prog)]
        notes = chord_notes(root, kind)
        t0 = b * 4 * beat
        for i in range(16):
            m = notes[0] - 12 if i % 4 != 3 else notes[1] - 12
            place(mix, staccato(midi_hz(m), beat * 0.22, 0.09), t0 + i * beat / 4)
        place(mix, choir(midi_hz(notes[0] + 12), 4 * beat, 0.09, "ah"), t0)
        place(mix, choir(midi_hz(notes[2]), 4 * beat, 0.07, "ah"), t0)
        place(mix, brass(midi_hz(root - 12), 4 * beat, 0.12, 0.7), t0)
        for hit in [0, 0.75, 1.5, 2, 2.75, 3.5]:
            place(mix, taiko(0.9, 0.7, 52), t0 + hit * beat)
        for hit in [1, 3]:
            place(mix, snare(0.3, 0.28), t0 + hit * beat)
        if b % 2 == 0:
            place(mix, timpani(midi_hz(root - 24), 1.5, 0.45), t0)
            place(mix, cymbal(1.8, 0.15), t0)
        if b % 4 == 2:
            for k, m in enumerate([notes[0] + 12, notes[1] + 12, notes[2] + 12, notes[0] + 24]):
                place(mix, brass(midi_hz(m), beat * 0.45, 0.1, 1.3), t0 + k * beat * 0.5)
    out = finish_loop(mix, loop, 0.25, 2.0)
    return normalize(soft_clip(out, 1.7), 0.88)


def music_victory():
    beat = 60 / 112
    mix = np.zeros(int(8 * SR))
    fan = [(67, 0, 0.5), (67, 0.5, 0.25), (67, 0.75, 0.25), (72, 1.0, 1.0), (71, 2.0, 0.5), (72, 2.5, 0.5), (76, 3.0, 2.5)]
    for m, at, d in fan:
        place(mix, brass(midi_hz(m), d * beat + 0.2, 0.18, 1.2), at * beat)
        place(mix, brass(midi_hz(m - 12), d * beat + 0.2, 0.1, 0.9), at * beat)
    for m in chord_notes(60, "M"):
        place(mix, strings(midi_hz(m), 3.5 * beat, 0.12, 0.1), 3 * beat)
        place(mix, choir(midi_hz(m + 12), 3.5 * beat, 0.07), 3 * beat)
    place(mix, timpani(midi_hz(36), 1.5, 0.5), 3 * beat)
    place(mix, cymbal(3.0, 0.22), 3 * beat)
    for k in range(6):
        place(mix, harp(midi_hz(72 + [0, 4, 7, 12, 16, 19][k]), 1.5, 0.1), 3 * beat + k * 0.09)
    out = reverb(mix, 2.4, 0.35)
    return normalize(soft_clip(out, 1.2), 0.85)


def music_defeat():
    beat = 60 / 64
    mix = np.zeros(int(9 * SR))
    for i, (m, k) in enumerate([(57, "m"), (53, "M"), (52, "m"), (50, "m")]):
        for n in chord_notes(m, k):
            place(mix, strings(midi_hz(n - 12), 2.2 * beat, 0.14, 0.4), i * 1.5 * beat)
    for i, m in enumerate([69, 67, 65, 64, 62]):
        place(mix, brass(midi_hz(m), 1.4 * beat, 0.09, 0.5), i * 1.2 * beat)
    place(mix, timpani(midi_hz(38), 3.0, 0.5), 0)
    place(mix, timpani(midi_hz(38), 3.0, 0.4), 4.5 * beat)
    out = reverb(mix, 3.0, 0.42)
    return normalize(out, 0.8)


# ----------------------------------------------------------------------------- sfx

def sfx_set():
    s = {}
    n = lambda d: int(d * SR)

    # UI
    t = t_axis(0.09)
    s["ui_click"] = (np.sin(2 * np.pi * 1400 * t) * 0.6 + np.sin(2 * np.pi * 2100 * t) * 0.3) * exp_decay(len(t), 0.018)
    t = t_axis(0.25)
    s["ui_open"] = mix(pitch_sweep_sine(500, 1200, 0.25, -2) * 0.5, harp(1046, 0.25, 0.5))[: len(t)] * env_adsr(len(t), 0.005, 0.1, 0.4, 0.12)
    s["ui_back"] = pitch_sweep_sine(900, 450, 0.18, 4) * exp_decay(n(0.18), 0.06) * 0.6
    up = np.zeros(n(0.7))
    for i, m in enumerate([72, 76, 79, 84]):
        place(up, harp(midi_hz(m), 0.6, 0.6), i * 0.07)
    s["upgrade"] = reverb(up, 0.8, 0.25)
    s["level_up"] = reverb(mix(up, (brass(midi_hz(84), 0.6, 0.3), 0.25)), 1.0, 0.3)
    b = mix(fft_filter(noise(n(0.5)), lo=100, hi=2500) * exp_decay(n(0.5), 0.08), taiko(0.5, 0.5, 90))
    s["build"] = mix(b, (harp(midi_hz(79), 0.3, 0.4), 0.12))
    s["sell"] = pitch_sweep_sine(1600, 900, 0.3, 3) * exp_decay(n(0.3), 0.08) * 0.5
    c = np.zeros(n(0.35))
    for i, f in enumerate([2637, 3520]):
        place(c, (np.sin(2 * np.pi * f * t_axis(0.25)) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t_axis(0.25))) * exp_decay(n(0.25), 0.06) * 0.5, i * 0.06)
    s["coin"] = c
    ch = fft_filter(noise(n(0.25)), lo=200, hi=3000) * exp_decay(n(0.25), 0.05) * 0.6
    sp = np.zeros(n(1.4))
    place(sp, ch, 0)
    for i, m in enumerate([76, 79, 83, 88, 91]):
        place(sp, harp(midi_hz(m), 0.9, 0.35), 0.15 + i * 0.06)
    s["chest_open"] = reverb(sp, 1.2, 0.3)
    leg = np.zeros(n(2.0))
    for m in [72, 76, 79, 84]:
        place(leg, choir(midi_hz(m), 1.6, 0.25), 0)
    for i, m in enumerate([84, 88, 91, 96, 100]):
        place(leg, harp(midi_hz(m), 1.0, 0.3), 0.1 + i * 0.07)
    s["loot_legendary"] = reverb(leg, 1.8, 0.35)
    bl = np.zeros(n(1.2))
    for m in [69, 73, 76, 81]:
        place(bl, choir(midi_hz(m), 1.0, 0.25, "oh"), 0)
    s["blessing"] = reverb(bl, 1.5, 0.35)
    s["combo"] = reverb(mix(bl, (brass(midi_hz(81), 0.7, 0.35, 1.3), 0.4)), 1.5, 0.3)

    # combat: physical
    a = fft_filter(noise(n(0.22)), lo=1800, hi=7000) * env_adsr(n(0.22), 0.002, 0.03, 0.3, 0.15)
    s["arrow_shoot"] = mix(a * 0.7, pitch_sweep_sine(900, 300, 0.22, 5) * exp_decay(n(0.22), 0.03) * 0.25)
    s["arrow_hit"] = mix(fft_filter(noise(n(0.12)), lo=300, hi=3000) * exp_decay(n(0.12), 0.02), pitch_sweep_sine(260, 120, 0.12, 8) * exp_decay(n(0.12), 0.03) * 0.6)
    sl = fft_filter(noise(n(0.3)), lo=2500, hi=9000)
    sl *= np.sin(np.linspace(0, np.pi, len(sl))) ** 2
    s["sword_slash"] = sl * 0.8
    ring = sum((1.0 / k) * np.sin(2 * np.pi * 1800 * k * 1.01 * t_axis(0.5)) for k in range(1, 5)) * exp_decay(n(0.5), 0.09)
    s["sword_hit"] = mix(ring * 0.35, fft_filter(noise(n(0.5)), lo=500, hi=5000) * exp_decay(n(0.5), 0.02) * 0.6)
    boom = mix(taiko(0.9, 1.0, 55), fft_filter(noise(n(0.9)), lo=40, hi=700) * exp_decay(n(0.9), 0.2) * 0.8)
    s["cannon_fire"] = soft_clip(boom, 2.0)
    ex = mix(fft_filter(noise(n(1.2)), lo=30, hi=900) * exp_decay(n(1.2), 0.25), pitch_sweep_sine(120, 40, 1.2, 4) * exp_decay(n(1.2), 0.3) * 0.8)
    crackle = fft_filter(noise(n(1.2)), lo=1500, hi=6000) * exp_decay(n(1.2), 0.12) * (RNG.uniform(0, 1, n(1.2)) > 0.93) * 2
    s["explosion"] = soft_clip(mix(ex, crackle * 0.4), 1.8)
    big = mix(fft_filter(noise(n(2.4)), lo=20, hi=600) * exp_decay(n(2.4), 0.55), pitch_sweep_sine(80, 28, 2.4, 3) * exp_decay(n(2.4), 0.6))
    s["explosion_big"] = reverb(soft_clip(mix(big * 1.2, crackle * 0.5), 2.2), 1.6, 0.25)
    s["castle_hit"] = mix(fft_filter(noise(n(0.5)), lo=60, hi=1500) * exp_decay(n(0.5), 0.08), taiko(0.5, 0.4, 80))

    # magic
    zap = fft_filter(noise(n(0.6)), lo=900, hi=12000) * exp_decay(n(0.6), 0.12)
    zap *= (1 + np.sign(np.sin(2 * np.pi * 60 * t_axis(0.6))) * 0.5)
    thunder = fft_filter(noise(n(1.6)), lo=25, hi=400) * exp_decay(n(1.6), 0.45) * env_adsr(n(1.6), 0.08, 0.2, 0.7, 1.0)
    s["lightning"] = reverb(soft_clip(mix(zap * 0.8, thunder * 1.1), 1.6), 1.6, 0.25)
    s["chain_zap"] = zap[: n(0.35)] * 0.8
    ic = np.zeros(n(0.9))
    for i in range(14):
        f = RNG.uniform(2500, 6000)
        place(ic, np.sin(2 * np.pi * f * t_axis(0.3)) * exp_decay(n(0.3), 0.05) * 0.25, RNG.uniform(0, 0.5))
    s["ice_cast"] = reverb(mix(ic, fft_filter(noise(n(0.9)), lo=3000, hi=9000) * env_adsr(n(0.9), 0.1, 0.3, 0.3, 0.4) * 0.3), 1.2, 0.3)
    sh = np.zeros(n(0.8))
    for i in range(22):
        f = RNG.uniform(1800, 7000)
        place(sh, np.sin(2 * np.pi * f * t_axis(0.25)) * exp_decay(n(0.25), 0.03) * 0.3, RNG.uniform(0, 0.25))
    s["ice_shatter"] = mix(sh, fft_filter(noise(n(0.8)), lo=2000, hi=8000) * exp_decay(n(0.8), 0.06) * 0.5)
    fw = fft_filter(noise(n(0.8)), lo=150, hi=2500) * env_adsr(n(0.8), 0.15, 0.2, 0.6, 0.4)
    s["fire_whoosh"] = fw
    roar_t = t_axis(1.2)
    s["fire_cast"] = mix(fw * 0.7, fft_filter(noise(n(0.4)), lo=60, hi=500) * exp_decay(n(0.4), 0.1))
    s["fire_roar"] = fft_filter(noise(n(2.0)), lo=80, hi=1800) * env_adsr(n(2.0), 0.3, 0.3, 0.8, 1.0)
    mf = fft_filter(noise(n(1.0)), lo=200, hi=4000) * np.linspace(0.1, 1, n(1.0)) ** 2
    s["meteor_fall"] = mix(mf * 0.7, pitch_sweep_sine(1200, 300, 1.0, -1.5) * np.linspace(0.05, 0.4, n(1.0)))
    s["meteor_impact"] = s["explosion_big"]
    mag = sum(np.sin(2 * np.pi * f * roar_t[: n(0.7)]) for f in [523, 659, 784, 1046]) * env_adsr(n(0.7), 0.05, 0.2, 0.5, 0.4) * 0.15
    s["magic_cast"] = reverb(mix(mag, fft_filter(noise(n(0.7)), lo=2000, hi=8000) * env_adsr(n(0.7), 0.2, 0.2, 0.3, 0.3) * 0.2), 1.2, 0.3)
    holy = np.zeros(n(2.0))
    for m in [72, 76, 79, 84, 88]:
        place(holy, choir(midi_hz(m), 1.8, 0.22), 0)
    s["holy_cast"] = reverb(mix(holy, cymbal(1.5, 0.3)), 2.0, 0.4)
    nat = fft_filter(noise(n(1.2)), lo=80, hi=900) * env_adsr(n(1.2), 0.05, 0.4, 0.4, 0.6)
    creak = np.sin(2 * np.pi * (120 + 40 * np.sin(2 * np.pi * 7 * t_axis(1.2))) * t_axis(1.2)) * env_adsr(n(1.2), 0.1, 0.3, 0.3, 0.5) * 0.4
    s["nature_cast"] = mix(nat, creak)
    shadow = np.zeros(n(2.0))
    for m in [45, 48, 51, 54]:
        place(shadow, choir(midi_hz(m), 1.8, 0.25, "oh"), 0)
    s["shadow_cast"] = reverb(mix(shadow, fft_filter(noise(n(2.0)), lo=60, hi=500) * env_adsr(n(2.0), 0.4, 0.4, 0.5, 0.8) * 0.4), 2.0, 0.4)
    s["summon"] = s["shadow_cast"]
    sh_up = sum(np.sin(2 * np.pi * f * t_axis(1.0)) for f in [440, 554, 659]) * env_adsr(n(1.0), 0.3, 0.2, 0.6, 0.4) * 0.2
    s["shield_up"] = reverb(sh_up * (1 + 0.3 * np.sin(2 * np.pi * 8 * t_axis(1.0)))[: len(sh_up)], 1.2, 0.3)

    # creatures
    def growl(dur, f0, rough=0.5):
        tt = t_axis(dur)
        f = f0 * (1 + 0.2 * np.sin(2 * np.pi * 3 * tt)) * np.linspace(1.1, 0.8, len(tt))
        ph = 2 * np.pi * np.cumsum(f) / SR
        x = sum((1 / k) * np.sin(k * ph) for k in range(1, 12))
        x *= 1 + rough * fft_filter(noise(len(tt)), hi=60) * 6
        x = fft_filter(x, lo=80, hi=2200)
        return x * env_adsr(len(tt), 0.04, 0.1, 0.8, dur * 0.4)
    s["enemy_hit"] = fft_filter(noise(n(0.15)), lo=150, hi=2000) * exp_decay(n(0.15), 0.025) * 0.8
    s["enemy_death"] = growl(0.45, 160, 0.6) * 0.5
    bones = np.zeros(n(0.7))
    for i in range(10):
        f = RNG.uniform(700, 1800)
        place(bones, mix(np.sin(2 * np.pi * f * t_axis(0.08)), fft_filter(noise(n(0.08)), lo=500, hi=4000))[: n(0.08)] * exp_decay(n(0.08), 0.015) * 0.4, RNG.uniform(0, 0.5))
    s["skeleton_death"] = bones
    s["boss_roar"] = reverb(soft_clip(mix(growl(2.2, 70, 1.0) * 1.3, growl(2.2, 105, 0.8) * 0.6), 1.6), 1.8, 0.3)
    s["boss_slam"] = reverb(soft_clip(mix(taiko(1.5, 1.2, 40), fft_filter(noise(n(1.5)), lo=30, hi=500) * exp_decay(n(1.5), 0.3)), 2.0), 1.4, 0.25)
    s["dragon_roar"] = reverb(soft_clip(mix(growl(2.4, 95, 0.9), growl(2.4, 140, 0.6) * 0.5, fft_filter(noise(n(2.4)), lo=300, hi=3000) * env_adsr(n(2.4), 0.2, 0.3, 0.5, 1.0) * 0.4), 1.5), 2.0, 0.3)

    # horn + stingers
    horn = np.zeros(n(2.2))
    place(horn, brass(midi_hz(50), 1.0, 0.4, 0.9), 0)
    place(horn, brass(midi_hz(57), 1.2, 0.4, 1.0), 0.8)
    place(horn, brass(midi_hz(45), 2.0, 0.25, 0.7), 0)
    s["wave_start"] = reverb(horn, 2.0, 0.35)
    wc = np.zeros(n(1.6))
    for i, m in enumerate([67, 72, 76]):
        place(wc, brass(midi_hz(m), 0.5 if i < 2 else 1.0, 0.25, 1.1), i * 0.18)
    s["wave_clear"] = reverb(wc, 1.5, 0.3)
    return s


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "sfx"):
        for name, x in sfx_set().items():
            write_ogg(os.path.join(ROOT, "sfx", name + ".ogg"), normalize(x, 0.92), 5)
            print("sfx", name, round(len(x) / SR, 2), "s")
    if what in ("all", "music"):
        for name, fn in [("menu", music_menu), ("battle", music_battle), ("boss", music_boss), ("victory", music_victory), ("defeat", music_defeat)]:
            x = fn()
            write_ogg(os.path.join(ROOT, "music", name + ".ogg"), x, 4, stereo_widen(x))
            print("music", name, round(len(x) / SR, 1), "s")


if __name__ == "__main__":
    main()
