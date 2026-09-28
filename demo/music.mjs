// Bande-son de la vidéo de démo, entièrement synthétisée (aucun échantillon externe).
// Nappe en la mineur, basse, pulsation légère, arpège, clics sous les taps, souffles aux transitions.
//
//   node demo/music.mjs build/demo/timeline.json build/demo/music.wav
import fs from 'node:fs';

const [timelinePath, outPath] = process.argv.slice(2);
const tl = JSON.parse(fs.readFileSync(timelinePath, 'utf8'));
const SR = 48000;
const duration = tl.frames / tl.fps;
const N = Math.ceil(duration * SR);
const L = new Float32Array(N);
const R = new Float32Array(N);
const sendL = new Float32Array(N); // départ réverbération
const sendR = new Float32Array(N);

const BPM = 96;
const beat = 60 / BPM;
const bar = beat * 4;
const midi = (n) => 440 * Math.pow(2, (n - 69) / 12);

// Accords (MIDI) : Am9, Fmaj7, Cadd9, G6.
const chords = [
  { bass: 45, pad: [57, 60, 64, 67, 71] },
  { bass: 41, pad: [53, 57, 60, 64, 69] },
  { bass: 48, pad: [60, 64, 67, 71, 74] },
  { bass: 43, pad: [55, 59, 62, 64, 71] },
];
const chordAt = (t) => chords[Math.floor(t / bar) % chords.length];

let seed = 7;
const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647) * 2 - 1;

function add(t0, len, fn, { gain = 1, pan = 0, send = 0 } = {}) {
  const i0 = Math.max(0, Math.floor(t0 * SR));
  const i1 = Math.min(N, Math.floor((t0 + len) * SR));
  const gl = gain * Math.cos(((pan + 1) * Math.PI) / 4);
  const gr = gain * Math.sin(((pan + 1) * Math.PI) / 4);
  for (let i = i0; i < i1; i++) {
    const v = fn((i - i0) / SR);
    L[i] += v * gl;
    R[i] += v * gr;
    if (send) {
      sendL[i] += v * gl * send;
      sendR[i] += v * gr * send;
    }
  }
}

// ---------------------------------------------------------------- Nappe (additive, douce)
const outro = tl.outro;
const end = duration;
for (let b = 0; b * bar < end; b++) {
  const t0 = b * bar;
  const ch = chords[b % chords.length];
  const last = t0 + bar >= outro;
  const len = last ? end - t0 : bar + 1.2;
  for (const [k, note] of ch.pad.entries()) {
    for (const detune of [-0.08, 0.08]) {
      const f = midi(note) * Math.pow(2, detune / 12);
      const pan = detune < 0 ? -0.45 : 0.45;
      add(
        t0,
        len,
        (t) => {
          const env = Math.min(1, t / 0.9) * Math.min(1, Math.max(0, (len - t) / 1.2));
          let v = 0;
          for (let h = 1; h <= 6; h++) v += Math.sin(2 * Math.PI * f * h * t + h * k) / Math.pow(h, 1.8);
          // Légère respiration du volume.
          return v * env * (0.85 + 0.15 * Math.sin(2 * Math.PI * 0.25 * t + k));
        },
        { gain: 0.028, pan, send: 0.6 },
      );
    }
  }
}

// Brillance du final : octave haute.
for (const note of [81, 84, 88]) {
  add(outro, end - outro, (t) => {
    const env = Math.min(1, t / 1.2) * Math.min(1, (end - outro - t) / 1.5);
    return Math.sin(2 * Math.PI * midi(note) * t) * env;
  }, { gain: 0.018, send: 0.9, pan: note === 84 ? 0 : note === 81 ? -0.3 : 0.3 });
}

// ---------------------------------------------------------------- Basse (à partir de la scène 2)
const bassStart = tl.cuts[1] ?? 4;
for (let b = Math.floor(bassStart / bar); b * bar < outro; b++) {
  const t0 = Math.max(b * bar, bassStart);
  const f = midi(chordAt(b * bar).bass);
  add(t0, bar, (t) => {
    const env = Math.min(1, t / 0.03) * Math.exp(-t * 0.9);
    return (Math.sin(2 * Math.PI * f * t) + 0.25 * Math.sin(4 * Math.PI * f * t)) * env;
  }, { gain: 0.16 });
}

// ---------------------------------------------------------------- Pulsation
const kickStart = tl.cuts[1] ?? 4;
for (let t0 = Math.ceil(kickStart / beat) * beat; t0 < outro - 0.1; t0 += beat * 2) {
  add(t0, 0.35, (t) => {
    const f = 45 + 80 * Math.exp(-t * 28);
    // Attaque de 4 ms : pas de clic à l'impact.
    return Math.sin(2 * Math.PI * f * t) * Math.exp(-t * 11) * Math.min(1, t / 0.004);
  }, { gain: 0.22 });
}
const hatStart = tl.cuts[2] ?? 8;
let prev = 0;
for (let t0 = Math.ceil(hatStart / beat) * beat + beat / 2; t0 < outro - 0.1; t0 += beat) {
  add(t0, 0.06, (t) => {
    const n = rand();
    // Bruit adouci (moyenne de deux échantillons) : un « tss » feutré plutôt qu'un claquement.
    const soft = (n + prev) / 2;
    prev = n;
    return soft * Math.exp(-t * 90) * Math.min(1, t / 0.002);
  }, { gain: 0.018, pan: 0.2 });
}

// ---------------------------------------------------------------- Arpège (bibliothèque → lecteur)
const arpStart = tl.cuts[3] ?? 12;
let step = 0;
for (let t0 = Math.ceil(arpStart / (beat / 2)) * (beat / 2); t0 < outro - 0.2; t0 += beat / 2, step++) {
  const ch = chordAt(t0);
  const note = ch.pad[[0, 2, 4, 3][step % 4]] + 12;
  const f = midi(note);
  add(t0, 0.9, (t) => (Math.sin(2 * Math.PI * f * t) + 0.3 * Math.sin(4 * Math.PI * f * t)) * Math.exp(-t * 5), {
    gain: 0.03,
    pan: step % 2 ? 0.35 : -0.35,
    send: 0.5,
  });
}

// ---------------------------------------------------------------- Bruitages
for (const t0 of tl.taps) {
  add(t0, 0.08, (t) => Math.sin(2 * Math.PI * 1320 * t) * Math.exp(-t * 55) * Math.min(1, t / 0.002), {
    gain: 0.045,
    send: 0.2,
  });
}
function whoosh(center, len, gain) {
  let lp = 0;
  let lp2 = 0;
  add(center - len * 0.7, len, (t) => {
    const x = t / len;
    const env = Math.sin(Math.PI * Math.min(1, x)) ** 2;
    const cutoff = 0.008 + 0.06 * x; // filtre qui s'ouvre, sans aigus agressifs
    lp += cutoff * (rand() - lp);
    lp2 += cutoff * (lp - lp2);
    return lp2 * env * 4;
  }, { gain, send: 0.5 });
}
tl.cuts.slice(1).forEach((c) => whoosh(c, 0.45, 0.05));
if (tl.rotation > 0) whoosh(tl.rotation + 0.35, 0.8, 0.12);
whoosh(outro + 0.2, 1.0, 0.1);

// ---------------------------------------------------------------- Réverbération (Schroeder)
function reverb(input) {
  const out = new Float32Array(N);
  const combs = [1557, 1617, 1491, 1422].map((d) => ({ buf: new Float32Array(d), i: 0, fb: 0.84 }));
  const aps = [225, 556].map((d) => ({ buf: new Float32Array(d), i: 0 }));
  for (let n = 0; n < N; n++) {
    let s = 0;
    for (const c of combs) {
      const y = c.buf[c.i];
      c.buf[c.i] = input[n] + y * c.fb;
      c.i = (c.i + 1) % c.buf.length;
      s += y;
    }
    s *= 0.25;
    for (const a of aps) {
      const y = a.buf[a.i];
      a.buf[a.i] = s + y * 0.5;
      a.i = (a.i + 1) % a.buf.length;
      s = y - s * 0.5;
    }
    out[n] = s;
  }
  return out;
}
const rl = reverb(sendL);
const rr = reverb(sendR);

// ---------------------------------------------------------------- Mixage et export
let peak = 0;
for (let i = 0; i < N; i++) {
  L[i] = Math.tanh((L[i] + rl[i] * 0.35) * 1.2);
  R[i] = Math.tanh((R[i] + rr[i] * 0.35) * 1.2);
  peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
}
const norm = 0.89 / peak;
const fadeIn = 0.25 * SR;
const fadeOut = 1.2 * SR;
const pcm = Buffer.alloc(N * 4);
for (let i = 0; i < N; i++) {
  const g = norm * Math.min(1, i / fadeIn) * Math.min(1, (N - i) / fadeOut);
  pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, L[i] * g)) * 32767), i * 4);
  pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, R[i] * g)) * 32767), i * 4 + 2);
}
const header = Buffer.alloc(44);
header.write('RIFF', 0);
header.writeUInt32LE(36 + pcm.length, 4);
header.write('WAVEfmt ', 8);
header.writeUInt32LE(16, 16);
header.writeUInt16LE(1, 20);
header.writeUInt16LE(2, 22);
header.writeUInt32LE(SR, 24);
header.writeUInt32LE(SR * 4, 28);
header.writeUInt16LE(4, 32);
header.writeUInt16LE(16, 34);
header.write('data', 36);
header.writeUInt32LE(pcm.length, 40);
fs.writeFileSync(outPath, Buffer.concat([header, pcm]));
console.log(`musique : ${duration.toFixed(2)} s, ${tl.taps.length} clics, ${tl.cuts.length} plans`);
