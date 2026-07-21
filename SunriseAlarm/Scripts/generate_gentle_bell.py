#!/usr/bin/env python3
"""Generates Resources/GentleBell.wav: a soft two-note bell chime used as the
alarm sound. Pure stdlib (wave + math), no external dependencies.

Re-run after editing to regenerate the asset:
    python3 SunriseAlarm/Scripts/generate_gentle_bell.py
"""
import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
OUT_PATH = Path(__file__).resolve().parent.parent / "Resources" / "GentleBell.wav"


def bell_note(freq: float, start: float, duration: float, amplitude: float, samples: list):
    """Additively synthesizes one soft bell strike (fundamental + a few
    inharmonic overtones, like a real bell) with an exponential decay
    envelope, and mixes it into `samples` starting at `start` seconds."""
    start_i = int(start * SAMPLE_RATE)
    n = int(duration * SAMPLE_RATE)
    # Bell-like inharmonic partials (ratio, relative amplitude, decay rate)
    partials = [
        (1.0, 1.00, 2.2),
        (2.0, 0.55, 3.0),
        (2.76, 0.35, 3.6),
        (3.5, 0.18, 4.4),
        (4.2, 0.10, 5.2),
    ]
    attack = int(0.008 * SAMPLE_RATE)
    for i in range(n):
        idx = start_i + i
        if idx >= len(samples):
            break
        t = i / SAMPLE_RATE
        env = (i / attack) if i < attack else math.exp(-2.5 * t)
        val = 0.0
        for ratio, amp, decay in partials:
            val += amp * math.exp(-decay * t) * math.sin(2 * math.pi * freq * ratio * t)
        samples[idx] += amplitude * env * val


def main():
    total_seconds = 3.6
    n_samples = int(total_seconds * SAMPLE_RATE)
    samples = [0.0] * n_samples

    # A soft, gentle two-note chime (major third), like a small wind chime.
    bell_note(523.25, 0.00, 3.0, 0.55, samples)  # C5
    bell_note(659.25, 0.35, 3.0, 0.40, samples)  # E5

    # Normalize and apply a gentle overall fade-out at the tail so it loops
    # smoothly when the app repeats it during the wake-up ramp.
    peak = max(abs(s) for s in samples) or 1.0
    fade_samples = int(0.25 * SAMPLE_RATE)
    for i in range(n_samples):
        s = samples[i] / peak * 0.85
        if i > n_samples - fade_samples:
            s *= (n_samples - i) / fade_samples
        samples[i] = s

    with wave.open(str(OUT_PATH), "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(v * 32767))
        wav.writeframes(bytes(frames))

    print(f"Wrote {OUT_PATH} ({n_samples / SAMPLE_RATE:.2f}s, {OUT_PATH.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
