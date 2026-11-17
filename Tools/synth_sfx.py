"""Sintesi procedurale degli effetti sonori di Pigeon Rush (WAV 44.1 kHz, 16 bit, mono)."""
import os
import sys
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else "sfx"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


# ------------------------------------------------------------------ utility
def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, release=0.05, sustain_level=1.0):
    e = np.full(n, sustain_level, dtype=float)
    a = max(1, int(attack * SR)); r = max(1, int(release * SR))
    e[:a] = np.linspace(0, sustain_level, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def exp_decay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def lowpass(x, fc, order=4):
    sos = signal.butter(order, fc, "low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, fc, order=2):
    sos = signal.butter(order, fc, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], "band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def sweep_bandpass(x, centers, q=2.0, block=256):
    """Passa-banda con frequenza centrale variabile (a blocchi)."""
    y = np.zeros_like(x)
    zi = None
    for i in range(0, len(x), block):
        fc = float(np.clip(centers[min(i, len(centers) - 1)], 80, SR / 2 - 2000))
        bw = fc / q
        sos = signal.butter(2, [max(30, fc - bw / 2), fc + bw / 2], "band", fs=SR, output="sos")
        if zi is None:
            zi = signal.sosfilt_zi(sos) * 0
        y[i:i + block], zi = signal.sosfilt(sos, x[i:i + block], zi=zi)
    return y


def osc(freq, dur=None, kind="saw", n_harm=40, phase_freq=None):
    """Oscillatore band-limited (additivo). freq può essere un array (glissando)."""
    if phase_freq is None:
        n = int(SR * dur)
        f = np.full(n, freq, dtype=float)
    else:
        f = phase_freq
    phase = 2 * np.pi * np.cumsum(f) / SR
    out = np.zeros_like(phase)
    for k in range(1, n_harm + 1):
        if kind == "square" and k % 2 == 0:
            continue
        amp = 1.0 / k
        # niente armoniche sopra Nyquist
        mask = (f * k) < SR / 2 - 500
        out += np.where(mask, amp * np.sin(k * phase), 0.0)
    return out


def pink_noise(n):
    white = rng.standard_normal(n)
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    return signal.lfilter(b, a, white)


def brown_noise(n):
    x = np.cumsum(rng.standard_normal(n))
    x = highpass(x, 20)
    return x / (np.max(np.abs(x)) + 1e-9)


def normalize(x, peak_db=-1.0):
    peak = np.max(np.abs(x)) + 1e-12
    return x / peak * (10 ** (peak_db / 20))


def soft_clip(x, drive=1.5):
    return np.tanh(x * drive) / np.tanh(drive)


def make_loop(x, fade=0.4):
    """Loop senza click: dissolvenza incrociata tra coda e testa."""
    f = int(fade * SR)
    head, body, tail = x[:f], x[f:-f], x[-f:]
    ramp = np.linspace(0, 1, f)
    mixed = tail * (1 - ramp) + head * ramp
    return np.concatenate([body, mixed])


def save(name, x, peak_db=-1.0):
    x = normalize(x, peak_db)
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))
    print(f"{name:22s} {len(x) / SR:5.2f} s")


# ------------------------------------------------------------------ clacson
def horn_tone(freqs, dur, attack=0.012, release=0.05):
    n = int(SR * dur)
    x = sum(osc(f, dur, "square", 30) for f in freqs)
    x = bandpass(x, 250, 3500)
    x += 0.3 * bandpass(x, 1400, 2100)       # risonanza della tromba (morbida, non squillante)
    x = soft_clip(x * 0.6, 2.2)
    return x * env(n, attack, release)


def horn_pattern(freqs, pattern):
    """pattern: lista di (durata_suono, pausa)."""
    parts = []
    for on, off in pattern:
        parts.append(horn_tone(freqs, on))
        parts.append(np.zeros(int(off * SR)))
    return np.concatenate(parts)


CAR_HORN = (360, 450)            # clacson bitonale europeo (terza maggiore), tono medio
save("horn_car", horn_pattern(CAR_HORN, [(0.45, 0.05)]))
save("horn_car_double", horn_pattern(CAR_HORN, [(0.16, 0.08), (0.22, 0.05)]))
save("horn_car_angry", horn_pattern(CAR_HORN, [(0.12, 0.06), (0.12, 0.06), (0.6, 0.05)]))


def air_horn(dur=0.95):
    n = int(SR * dur)
    t = t_axis(dur)
    bend = 1 - 0.035 * np.exp(-t / 0.06)      # attacco "che sale" tipico della tromba ad aria
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t)
    x = sum(osc(None, phase_freq=f * bend * vib, kind="saw", n_harm=60) for f in (185, 233, 277))
    x = lowpass(x, 2800)
    x += 0.15 * bandpass(rng.standard_normal(n), 800, 4000) * exp_decay(n, 0.08)  # soffio d'aria
    x = soft_clip(x * 0.5, 2.0)
    return x * env(n, 0.03, 0.12)


save("horn_truck", np.concatenate([air_horn(0.95), np.zeros(int(0.05 * SR))]))


# ------------------------------------------------------------------ passaggi con effetto Doppler
def pass_by(dur, center, base_f, rel_speed, lateral, harm, noise_band, noise_gain, rumble=0.0):
    t = t_axis(dur) - center
    c = 343.0
    # componente radiale della velocità: avvicinamento (+) -> allontanamento (-)
    x_pos = rel_speed * t
    radial = rel_speed * (-x_pos) / np.sqrt(x_pos ** 2 + lateral ** 2)
    doppler = c / (c - radial)
    dist = np.sqrt(x_pos ** 2 + lateral ** 2)
    amp = 1 / (1 + (dist / (lateral * 1.5)) ** 2)

    engine = osc(None, phase_freq=base_f * doppler, kind="saw", n_harm=harm)
    engine = lowpass(engine, 1800)
    tires = bandpass(pink_noise(len(t)), *noise_band) * noise_gain
    wind = sweep_bandpass(rng.standard_normal(len(t)), 900 * doppler, q=1.2) * 0.6
    x = (engine * 0.5 + tires + wind) * amp
    if rumble:
        x += lowpass(brown_noise(len(t)), 120) * amp * rumble
    fade = env(len(t), 0.05, 0.15)
    return x * fade


save("passby_car", pass_by(1.4, 0.6, 105, 40, 2.5, 25, (300, 3200), 0.9))
save("passby_truck", pass_by(2.0, 0.85, 55, 36, 3.0, 40, (150, 1800), 1.2, rumble=1.5))


# ------------------------------------------------------------------ ambienti in loop
def road_loop(dur=6.0):
    n = int(SR * dur)
    t = t_axis(dur)
    rumble = highpass(lowpass(brown_noise(n), 350), 50, 4)  # niente sub-bassi: il telefono non li riproduce
    hiss = bandpass(pink_noise(n), 500, 2200) * 0.25
    swell = 1 + 0.25 * np.sin(2 * np.pi * t / dur * 2) + 0.1 * np.sin(2 * np.pi * t / dur * 5)
    return make_loop((rumble + hiss) * swell)


def wind_loop(dur=6.0):
    n = int(SR * dur)
    t = t_axis(dur)
    noise = rng.standard_normal(n)
    center = 900 + 400 * np.sin(2 * np.pi * t / dur * 3) + 250 * np.sin(2 * np.pi * t / dur * 7)
    x = sweep_bandpass(noise, center, q=1.5)
    gust = 1 + 0.35 * np.sin(2 * np.pi * t / dur * 2 + 1) + 0.15 * np.sin(2 * np.pi * t / dur * 9)
    return make_loop(x * gust)


def tunnel_loop(dur=6.0):
    n = int(SR * dur)
    t = t_axis(dur)
    drone = 0.6 * np.sin(2 * np.pi * 50 * t) + 0.3 * np.sin(2 * np.pi * 100 * t) + 0.15 * np.sin(2 * np.pi * 150 * t)
    fans = bandpass(pink_noise(n), 180, 700) * 0.6
    beat = 1 + 0.2 * np.sin(2 * np.pi * t / dur * 4)
    return make_loop((drone * 0.5 + fans) * beat)


save("road_loop", road_loop(), -6)
save("wind_loop", wind_loop(), -6)
save("tunnel_loop", tunnel_loop(), -6)


# ------------------------------------------------------------------ piccione
def flap():
    dur = 0.26
    n = int(SR * dur)
    x = np.zeros(n)
    for start, gain in ((0.0, 1.0), (0.09, 0.6)):
        s = int(start * SR)
        m = int(0.12 * SR)
        burst = lowpass(rng.standard_normal(m), 900) * exp_decay(m, 0.025)
        burst[: int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
        x[s:s + m] += burst * gain
    return x


save("flap", flap())


def poop_drop():
    dur = 0.16
    n = int(SR * dur)
    t = t_axis(dur)
    f = 180 + 620 * np.exp(-t / 0.03)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * exp_decay(n, 0.04)
    click = highpass(rng.standard_normal(n), 3000) * exp_decay(n, 0.003) * 0.3
    return (x + click) * env(n, 0.002, 0.02)


save("poop_drop", poop_drop())


def splat():
    dur = 0.45
    n = int(SR * dur)
    t = t_axis(dur)
    noise = rng.standard_normal(n)
    wet = sweep_bandpass(noise, 2800 * np.exp(-t / 0.08) + 350, q=1.0) * exp_decay(n, 0.09)
    thump = np.sin(2 * np.pi * np.cumsum(90 * np.exp(-t / 0.08) + 40) / SR) * exp_decay(n, 0.05)
    drops = np.zeros(n)
    for _ in range(6):  # goccioline
        s = int(rng.uniform(0.04, 0.3) * SR)
        m = int(0.03 * SR)
        f0 = rng.uniform(900, 1800)
        tt = np.arange(m) / SR
        drop = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 2 * tt / 0.03)) / SR) * exp_decay(m, 0.008)
        drops[s:s + m] += drop[: max(0, min(m, n - s))] * 0.25
    return (wet * 1.2 + thump * 0.8 + drops) * env(n, 0.002, 0.05)


save("splat", splat())


def crash():
    dur = 1.1
    n = int(SR * dur)
    t = t_axis(dur)
    thump = np.sin(2 * np.pi * np.cumsum(40 + 60 * np.exp(-t / 0.08)) / SR) * exp_decay(n, 0.18)
    impact = lowpass(rng.standard_normal(n), 1600) * exp_decay(n, 0.07)
    clang = sum(np.sin(2 * np.pi * f * t) * exp_decay(n, d) * a
                for f, d, a in ((523, 0.35, 0.25), (1270, 0.22, 0.18), (2210, 0.15, 0.12), (3390, 0.1, 0.08)))
    puff = bandpass(rng.standard_normal(n), 400, 2500) * np.exp(-((t - 0.25) / 0.12) ** 2) * 0.35  # piume
    return soft_clip(thump * 1.2 + impact + clang + puff, 1.4) * env(n, 0.001, 0.2)


save("crash", crash())


# ------------------------------------------------------------------ gameplay
def chime(notes, spacing, decay, partials=((1, 1.0), (2, 0.3), (3, 0.1))):
    dur = spacing * (len(notes) - 1) + decay * 4
    n = int(SR * dur)
    t = t_axis(dur)
    x = np.zeros(n)
    for i, f in enumerate(notes):
        s = int(i * spacing * SR)
        tt = t[: n - s]
        tone = sum(a * np.sin(2 * np.pi * f * k * tt) for k, a in partials)
        x[s:] += tone * exp_decay(n - s, decay)
    return x * env(n, 0.002, 0.05)


save("pickup", chime([1318.5, 1661.2, 1975.5], 0.065, 0.12))
save("combo", chime([1046.5], 0, 0.25, ((1, 1.0), (2.76, 0.35), (5.4, 0.12))))
save("lock_on", chime([1800, 2400], 0.05, 0.03))


def whoosh():
    dur = 0.5
    n = int(SR * dur)
    t = t_axis(dur)
    center = 500 + 2200 * np.exp(-((t - 0.2) / 0.1) ** 2)
    x = sweep_bandpass(rng.standard_normal(n), center, q=1.3)
    return x * np.exp(-((t - 0.2) / 0.12) ** 2)


save("near_miss", whoosh())


def relay_click(f_body):
    dur = 0.05
    n = int(SR * dur)
    t = t_axis(dur)
    click = highpass(rng.standard_normal(n), 2500) * exp_decay(n, 0.0015)
    body = np.sin(2 * np.pi * f_body * t) * exp_decay(n, 0.006) * 0.6
    return (click + body) * env(n, 0.0005, 0.01)  # chiusura morbida: niente clic finale


save("indicator_tick", relay_click(900))
save("indicator_tock", relay_click(650))


def beep(freq, dur, square=0.2):
    n = int(SR * dur)
    t = t_axis(dur)
    x = np.sin(2 * np.pi * freq * t) + square * np.sign(np.sin(2 * np.pi * freq * t))
    return lowpass(x, 5000) * env(n, 0.004, 0.02)


save("works_beep", np.concatenate([beep(1050, 0.22, 0.4), np.zeros(int(0.22 * SR))]))
save("countdown_beep", beep(660, 0.16))
save("countdown_go", beep(1320, 0.4))
save("ui_click", beep(1500, 0.035, 0.0) * exp_decay(int(0.035 * SR), 0.01))


def game_over_sting():
    parts = []
    for f, d in ((392, 0.22), (330, 0.22), (262, 0.6)):
        t = t_axis(d)
        vib = 1 + (0.012 * np.sin(2 * np.pi * 6 * t) if d > 0.5 else 0)
        x = osc(None, phase_freq=f * vib * np.ones_like(t), kind="square", n_harm=15)
        x = lowpass(x, 1800) * env(len(t), 0.01, 0.08)
        parts.append(x)
    return np.concatenate(parts)


save("game_over", game_over_sting())
