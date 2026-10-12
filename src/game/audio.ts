// All sound is synthesized at runtime with the Web Audio API (no audio files, nothing copyrighted).
import type { SfxName } from './battle';

type Ctx = AudioContext;

export class SoundEngine {
  private ctx: Ctx | null = null;
  private master: GainNode | null = null;
  private sfxGain: GainNode | null = null;
  private musicGain: GainNode | null = null;
  private noise: AudioBuffer | null = null;
  private lastPlayed = new Map<SfxName, number>();
  private musicTimer: number | null = null;
  private musicStep = 0;
  private nextNoteTime = 0;
  private track: 'menu' | 'battle' | null = null;
  sfxOn = true;
  musicOn = true;

  /** Must be called from a user gesture (iOS requirement). */
  unlock() {
    if (!this.ctx) {
      const AC = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (!AC) return;
      this.ctx = new AC();
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.8;
      this.master.connect(this.ctx.destination);
      this.sfxGain = this.ctx.createGain();
      this.sfxGain.gain.value = this.sfxOn ? 0.9 : 0;
      this.sfxGain.connect(this.master);
      this.musicGain = this.ctx.createGain();
      this.musicGain.gain.value = this.musicOn ? 0.22 : 0;
      this.musicGain.connect(this.master);
      const len = this.ctx.sampleRate;
      this.noise = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
      const d = this.noise.getChannelData(0);
      for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
      // Play a silent buffer to fully unlock on iOS.
      const s = this.ctx.createBufferSource();
      s.buffer = this.ctx.createBuffer(1, 1, 22050);
      s.connect(this.ctx.destination);
      s.start(0);
      if (this.track) this.startMusicLoop();
    }
    if (this.ctx.state === 'suspended') void this.ctx.resume();
  }

  suspend() {
    if (this.ctx && this.ctx.state === 'running') void this.ctx.suspend();
  }

  resume() {
    if (this.ctx && this.ctx.state === 'suspended') void this.ctx.resume();
  }

  setSfx(on: boolean) {
    this.sfxOn = on;
    if (this.sfxGain) this.sfxGain.gain.value = on ? 0.9 : 0;
  }

  setMusic(on: boolean) {
    this.musicOn = on;
    if (this.musicGain) this.musicGain.gain.value = on ? 0.22 : 0;
  }

  // ---------- primitives ----------

  private tone(freq: number, dur: number, type: OscillatorType, vol: number, slideTo?: number, delay = 0, dest?: AudioNode) {
    const ctx = this.ctx!;
    const t = ctx.currentTime + delay;
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.type = type;
    o.frequency.setValueAtTime(freq, t);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(Math.max(20, slideTo), t + dur);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + 0.008);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g).connect(dest ?? this.sfxGain!);
    o.start(t);
    o.stop(t + dur + 0.02);
  }

  private noiseBurst(dur: number, vol: number, filter: BiquadFilterType, freq: number, delay = 0, q = 1, freqTo?: number) {
    const ctx = this.ctx!;
    const t = ctx.currentTime + delay;
    const src = ctx.createBufferSource();
    src.buffer = this.noise;
    const f = ctx.createBiquadFilter();
    f.type = filter;
    f.frequency.setValueAtTime(freq, t);
    if (freqTo) f.frequency.exponentialRampToValueAtTime(freqTo, t + dur);
    f.Q.value = q;
    const g = ctx.createGain();
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f).connect(g).connect(this.sfxGain!);
    src.start(t, Math.random() * 0.5);
    src.stop(t + dur + 0.02);
  }

  play(name: SfxName | 'click' | 'select') {
    if (!this.ctx || !this.sfxOn || this.ctx.state !== 'running') return;
    // Throttle rapid repeats (e.g. plant-food pea storms).
    const now = this.ctx.currentTime;
    const minGap = name === 'shoot' || name === 'hit' ? 0.045 : name === 'chomp' ? 0.12 : 0.02;
    const key = name as SfxName;
    if (now - (this.lastPlayed.get(key) ?? -1) < minGap) return;
    this.lastPlayed.set(key, now);
    const r = 1 + (Math.random() - 0.5) * 0.12;
    switch (name) {
      case 'click':
        this.tone(660, 0.06, 'triangle', 0.25, 880);
        break;
      case 'select':
        this.tone(520 * r, 0.08, 'triangle', 0.3, 780);
        break;
      case 'shoot':
        this.tone(420 * r, 0.09, 'sine', 0.25, 160);
        this.noiseBurst(0.04, 0.12, 'bandpass', 1800);
        break;
      case 'hit':
        this.noiseBurst(0.08, 0.3, 'lowpass', 900 * r);
        this.tone(180 * r, 0.06, 'sine', 0.2, 90);
        break;
      case 'cone':
        this.tone(240 * r, 0.08, 'square', 0.12, 180);
        this.noiseBurst(0.06, 0.2, 'lowpass', 1200);
        break;
      case 'bucket':
        this.tone(1320 * r, 0.18, 'square', 0.07, 1250);
        this.tone(1760 * r, 0.14, 'triangle', 0.08, 1700);
        this.noiseBurst(0.05, 0.15, 'highpass', 3000);
        break;
      case 'place':
        this.noiseBurst(0.12, 0.35, 'lowpass', 500);
        this.tone(330, 0.1, 'triangle', 0.25, 660, 0.04);
        break;
      case 'sun':
        [880, 1175, 1568].forEach((f, i) => this.tone(f, 0.18, 'sine', 0.2, undefined, i * 0.05));
        break;
      case 'coin':
        this.tone(1320, 0.08, 'square', 0.08);
        this.tone(1980, 0.25, 'square', 0.08, undefined, 0.07);
        break;
      case 'plantfood':
        [523, 659, 784, 1047].forEach((f, i) => this.tone(f, 0.15, 'triangle', 0.22, undefined, i * 0.06));
        break;
      case 'pfuse':
        this.tone(200, 0.5, 'sawtooth', 0.12, 1200);
        this.tone(400, 0.5, 'triangle', 0.18, 1600, 0.05);
        break;
      case 'groan':
        this.groan();
        break;
      case 'chomp':
        this.noiseBurst(0.07, 0.25, 'bandpass', 700 * r, 0, 3);
        this.noiseBurst(0.06, 0.2, 'bandpass', 500 * r, 0.09, 3);
        break;
      case 'explode':
        this.noiseBurst(0.9, 0.9, 'lowpass', 1600, 0, 1, 80);
        this.tone(110, 0.6, 'sine', 0.6, 30);
        break;
      case 'smash':
        this.noiseBurst(0.4, 0.8, 'lowpass', 600, 0, 1, 60);
        this.tone(80, 0.35, 'sine', 0.6, 30);
        break;
      case 'mower':
        this.tone(90, 1.2, 'sawtooth', 0.15, 140);
        this.noiseBurst(1.2, 0.2, 'bandpass', 400, 0, 2);
        break;
      case 'siren':
        for (let i = 0; i < 3; i++) {
          this.tone(440, 0.4, 'sawtooth', 0.12, 880, i * 0.45);
        }
        break;
      case 'win':
        [523, 659, 784, 1047, 784, 1047].forEach((f, i) => this.tone(f, 0.25, 'triangle', 0.25, undefined, i * 0.12));
        break;
      case 'lose':
        [392, 370, 349, 262].forEach((f, i) => this.tone(f, 0.45, 'sawtooth', 0.12, undefined, i * 0.3));
        break;
      case 'shovel':
        this.noiseBurst(0.18, 0.4, 'bandpass', 1500, 0, 2, 400);
        break;
      case 'error':
        this.tone(160, 0.15, 'square', 0.12, 120);
        break;
      case 'freeze':
        this.noiseBurst(0.5, 0.3, 'highpass', 4000, 0, 1, 8000);
        this.tone(1600, 0.4, 'sine', 0.1, 2400);
        break;
      case 'arm':
        this.tone(300, 0.12, 'square', 0.1, 600);
        this.tone(600, 0.12, 'square', 0.1, 900, 0.12);
        break;
      case 'gulp':
        this.tone(300, 0.2, 'sine', 0.3, 80);
        break;
    }
  }

  private groan() {
    const ctx = this.ctx!;
    const t = ctx.currentTime;
    const o = ctx.createOscillator();
    const lfo = ctx.createOscillator();
    const lfoGain = ctx.createGain();
    const f = ctx.createBiquadFilter();
    const g = ctx.createGain();
    o.type = 'sawtooth';
    const base = 85 + Math.random() * 40;
    o.frequency.setValueAtTime(base, t);
    o.frequency.linearRampToValueAtTime(base * 0.8, t + 1.1);
    lfo.frequency.value = 6;
    lfoGain.gain.value = 8;
    lfo.connect(lfoGain).connect(o.frequency);
    f.type = 'bandpass';
    f.frequency.setValueAtTime(500, t);
    f.frequency.linearRampToValueAtTime(800, t + 0.5);
    f.frequency.linearRampToValueAtTime(400, t + 1.1);
    f.Q.value = 4;
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.25, t + 0.15);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 1.2);
    o.connect(f).connect(g).connect(this.sfxGain!);
    o.start(t);
    lfo.start(t);
    o.stop(t + 1.25);
    lfo.stop(t + 1.25);
  }

  // ---------- procedural music ----------

  playMusic(track: 'menu' | 'battle' | null) {
    if (this.track === track) return;
    this.track = track;
    this.musicStep = 0;
    if (this.musicTimer !== null) {
      clearInterval(this.musicTimer);
      this.musicTimer = null;
    }
    if (track && this.ctx) this.startMusicLoop();
  }

  private startMusicLoop() {
    if (this.musicTimer !== null || !this.ctx) return;
    this.nextNoteTime = this.ctx.currentTime + 0.1;
    this.musicTimer = window.setInterval(() => this.scheduleMusic(), 50);
  }

  private scheduleMusic() {
    const ctx = this.ctx;
    if (!ctx || !this.track || ctx.state !== 'running') return;
    const battle = this.track === 'battle';
    const bpm = battle ? 112 : 92;
    const step = 60 / bpm / 2; // eighth notes
    // Original, playful minor-ish ditty (A minor pentatonic with a swing bass).
    const melodyBattle = [69, -1, 72, 74, 76, -1, 74, 72, 69, -1, 67, 69, 72, -1, -1, -1, 69, -1, 72, 74, 76, 79, 76, 74, 72, -1, 74, 72, 69, -1, -1, -1];
    const melodyMenu = [76, -1, 79, -1, 81, 79, 76, -1, 74, -1, 76, 74, 72, -1, -1, -1, 72, -1, 74, -1, 76, 79, 81, -1, 79, -1, 76, 74, 76, -1, -1, -1];
    const bassBattle = [45, 52, 45, 52, 43, 50, 43, 50, 41, 48, 41, 48, 40, 47, 40, 47];
    const bassMenu = [48, 55, 52, 55, 45, 52, 48, 52, 41, 48, 45, 48, 43, 50, 47, 50];
    const mel = battle ? melodyBattle : melodyMenu;
    const bass = battle ? bassBattle : bassMenu;
    const midi = (n: number) => 440 * Math.pow(2, (n - 69) / 12);
    while (this.nextNoteTime < ctx.currentTime + 0.25) {
      const i = this.musicStep;
      const delay = this.nextNoteTime - ctx.currentTime;
      const note = mel[i % mel.length];
      if (note > 0) this.tone(midi(note), step * 1.6, 'triangle', 0.35, undefined, delay, this.musicGain!);
      if (i % 2 === 0) this.tone(midi(bass[(i / 2) % bass.length]), step * 1.8, 'sine', 0.5, undefined, delay, this.musicGain!);
      if (battle && i % 4 === 2) {
        const t = ctx.currentTime + delay;
        const src = ctx.createBufferSource();
        src.buffer = this.noise;
        const f = ctx.createBiquadFilter();
        f.type = 'highpass';
        f.frequency.value = 6000;
        const g = ctx.createGain();
        g.gain.setValueAtTime(0.12, t);
        g.gain.exponentialRampToValueAtTime(0.0001, t + 0.05);
        src.connect(f).connect(g).connect(this.musicGain!);
        src.start(t);
        src.stop(t + 0.06);
      }
      this.musicStep++;
      this.nextNoteTime += step;
    }
  }
}

export const audio = new SoundEngine();
