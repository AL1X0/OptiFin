// Bande-son de la vidéo de présentation, entièrement synthétisée (aucun échantillon externe).
// Ambiance « keynote » : nappe chaude qui s'ouvre, piano électrique (FM), basse ronde, pulsation
// très discrète, impacts cinématiques sur le logo, souffles aux transitions, ticks de verre sous les taps.
//
//   node demo/music.mjs build/demo/timeline.json build/demo/music.wav
import fs from 'node:fs';

const [timelinePath, outPath] = process.argv.slice(2);
const tl = JSON.parse(fs.readFileSync(timelinePath, 'utf8'));
const SR = 48000;
const duration = tl.frames / tl.fps + 1.5; // traîne de réverbération après la dernière image
const N = Math.ceil(duration * SR);
const L = new Float32Array(N);
const R = new Float32Array(N);
const sendL = new Float32Array(N);
const sendR = new Float32Array(N);

const BPM = 84;
const beat = 60 / BPM;
const bar = beat * 4;
const midi = (n) => 440 * Math.pow(2, (n - 69) / 12);
const TAU = 2 * Math.PI;

// Ré majeur : Dmaj9, Bm11, Gmaj9, A6sus — lumineux, jamais tendu.
const chords = [
  { bass: 38, pad: [50, 54, 57, 61, 64] },
  { bass: 35, pad: [47, 50, 54, 57, 64] },
  { bass: 43, pad: [55, 59, 62, 66, 69] },
  { bass: 45, pad: [57, 59, 62, 64, 66] },
];
const chordAt = (t) => chords[Math.floor(Math.max(0, t) / bar) % chords.length];

let seed = 11;
const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647) * 2 - 1;

function add(t0, len, fn, { gain = 1, pan = 0, send = 0 } = {}) {
  const i0 = Math.max(0, Math.floor(t0 * SR));
  const i1 = Math.min(N, Math.floor((t0 + len) * SR));
  const gl = gain * Math.cos(((pan + 1) * Math.PI) / 4);
  const gr = gain * Math.sin(((pan + 1) * Math.PI) / 4);
  for (let i = i0; i < i1; i++) {
    const v = fn((i - i0) / SR, i / SR);
    L[i] += v * gl;
    R[i] += v * gr;
    if (send) {
      sendL[i] += v * gl * send;
      sendR[i] += v * gr * send;
    }
  }
}

const intro = tl.intro ?? 0.3;
const firstCut = tl.cuts[0];
const outro = tl.outro;
const end = tl.frames / tl.fps;

// ---------------------------------------------------------------- Nappe : partiels désaccordés, filtre qui s'ouvre
for (let b = 0; b * bar < end; b++) {
  const t0 = b * bar;
  const ch = chords[b % chords.length];
  const len = Math.min(bar + 1.6, end + 1.4 - t0);
  for (const [k, note] of ch.pad.entries()) {
    for (const detune of [-0.07, 0, 0.07]) {
      const f = midi(note) * Math.pow(2, detune / 12);
      const pan = detune * 9;
      let lp = 0;
      add(
        t0,
        len,
        (t, abs) => {
          const env = Math.min(1, t / 1.1) * Math.min(1, Math.max(0, (len - t) / 1.4));
          // Brillance : sombre au début, s'ouvre jusqu'au lecteur, se referme au logo final.
          const open = Math.min(1, abs / (tl.rotation || 16)) * (abs > outro ? Math.max(0.3, 1 - (abs - outro) / 3) : 1);
          let v = 0;
          for (let h = 1; h <= 8; h++) v += Math.sin(TAU * f * h * t + h * k * 0.7) / h;
          const cutoff = 0.02 + 0.07 * open;
          lp += cutoff * (v - lp);
          return lp * env * (0.88 + 0.12 * Math.sin(TAU * 0.2 * t + k));
        },
        { gain: detune === 0 ? 0.03 : 0.022, pan, send: 0.7 },
      );
    }
  }
}

// ---------------------------------------------------------------- Piano électrique (FM), motif aux débuts de plans
function epiano(t0, note, { gain = 0.07, pan = 0, len = 2.6 } = {}) {
  const f = midi(note);
  add(
    t0,
    len,
    (t) => {
      const index = 2.2 * Math.exp(-t * 3.5) + 0.25;
      const mod = Math.sin(TAU * f * t) * index;
      const tine = Math.sin(TAU * f * 14 * t) * Math.exp(-t * 30) * 0.08; // attaque « métallique »
      const env = Math.min(1, t / 0.004) * Math.exp(-t * 1.6);
      return (Math.sin(TAU * f * t + mod) + tine) * env;
    },
    { gain, pan, send: 0.55 },
  );
}
const motifs = [
  [74, 76, 78, 81],
  [74, 73, 71, 69],
  [78, 76, 74, 71],
  [81, 78, 76, 74],
  [76, 78, 81, 83],
  [74, 78, 81, 86],
];
tl.cuts.forEach((cut, i) => {
  const m = motifs[i % motifs.length];
  m.forEach((n, j) => epiano(cut + 0.15 + j * beat * 0.5, n, { pan: (j % 2 ? 0.25 : -0.25), gain: 0.06 - j * 0.006 }));
});

// ---------------------------------------------------------------- Basse ronde (à partir du 1er plan)
for (let b = Math.floor(firstCut / bar); b * bar < outro + bar; b++) {
  const t0 = Math.max(b * bar, firstCut);
  const len = Math.min(bar, outro + 2 - t0);
  if (len <= 0) break;
  const f = midi(chordAt(b * bar).bass);
  add(t0, len + 0.3, (t) => {
    const env = Math.min(1, t / 0.08) * Math.min(1, Math.max(0, (len + 0.3 - t) / 0.3));
    return (Math.sin(TAU * f * t) + 0.18 * Math.sin(TAU * 2 * f * t)) * env;
  }, { gain: 0.13 });
}

// ---------------------------------------------------------------- Pulsation feutrée (plans 2 → lecteur)
const pulseStart = tl.cuts[1] ?? firstCut + 4;
for (let t0 = Math.ceil(pulseStart / beat) * beat; t0 < outro - 0.2; t0 += beat * 2) {
  add(t0, 0.5, (t) => {
    const f = 42 + 60 * Math.exp(-t * 30);
    return Math.sin(TAU * f * t) * Math.exp(-t * 9) * Math.min(1, t / 0.006);
  }, { gain: 0.16 });
}
// Souffle rythmique très doux (« air »), contretemps.
const airStart = tl.cuts[2] ?? pulseStart + 4;
for (let t0 = Math.ceil(airStart / beat) * beat + beat / 2; t0 < outro - 0.2; t0 += beat) {
  let a = 0;
  let b2 = 0;
  add(t0, 0.18, (t) => {
    a += 0.06 * (rand() - a);
    b2 += 0.06 * (a - b2);
    return b2 * 3 * Math.exp(-t * 22) * Math.min(1, t / 0.015);
  }, { gain: 0.04, pan: 0.3, send: 0.3 });
}

// ---------------------------------------------------------------- Impacts cinématiques (logo)
function hit(t0, { gain = 0.5 } = {}) {
  add(t0, 3.5, (t) => {
    const f = 34 + 40 * Math.exp(-t * 6);
    return Math.sin(TAU * f * t) * Math.exp(-t * 1.3) * Math.min(1, t / 0.01);
  }, { gain, send: 0.25 });
  // Scintillement aigu qui s'éteint lentement.
  for (const [n, p] of [[86, -0.4], [90, 0.4], [93, 0]]) {
    add(t0, 4, (t) => Math.sin(TAU * midi(n) * t) * Math.exp(-t * 0.9) * Math.min(1, t / 0.02), {
      gain: 0.022,
      pan: p,
      send: 0.9,
    });
  }
}
function swell(center, len, gain) {
  let lp = 0;
  let lp2 = 0;
  add(center - len, len, (t) => {
    const x = t / len;
    const cutoff = 0.004 + 0.05 * x * x;
    lp += cutoff * (rand() - lp);
    lp2 += cutoff * (lp - lp2);
    return lp2 * x * x * 6;
  }, { gain, send: 0.6 });
}
swell(intro, 0.3, 0.08);
hit(intro, { gain: 0.45 });
swell(outro + 0.45, 1.4, 0.12);
hit(outro + 0.45, { gain: 0.55 });
// Accord final tenu, octave haute.
for (const [n, p] of [[74, -0.3], [78, 0.3], [81, 0], [86, 0]]) {
  add(outro + 0.45, end - outro + 1, (t) => {
    const env = Math.min(1, t / 0.8) * Math.min(1, Math.max(0, (end - outro + 0.5 - t) / 1.6));
    return Math.sin(TAU * midi(n) * t) * env;
  }, { gain: 0.02, pan: p, send: 0.9 });
}

// ---------------------------------------------------------------- Transitions et interface
function swoosh(center, len, gain) {
  let lp = 0;
  let lp2 = 0;
  add(center - len * 0.6, len, (t) => {
    const x = t / len;
    const env = Math.sin(Math.PI * Math.min(1, x)) ** 2;
    const cutoff = 0.006 + 0.045 * Math.sin(Math.PI * x);
    lp += cutoff * (rand() - lp);
    lp2 += cutoff * (lp - lp2);
    return lp2 * env * 5;
  }, { gain, send: 0.5, pan: 0 });
}
tl.cuts.slice(1).forEach((c) => swoosh(c, 0.6, 0.05));
if (tl.rotation > 0) swoosh(tl.rotation + 0.4, 0.9, 0.09);

for (const t0 of tl.taps) {
  // Tick de verre : deux partiels inharmoniques très courts.
  add(t0, 0.12, (t) => {
    const env = Math.exp(-t * 60) * Math.min(1, t / 0.0015);
    return (Math.sin(TAU * 2350 * t) + 0.5 * Math.sin(TAU * 3710 * t)) * env;
  }, { gain: 0.03, send: 0.35 });
}

// ---------------------------------------------------------------- Réverbération (FDN 8 lignes, amortie)
function reverb(inL, inR) {
  const delays = [1433, 1601, 1867, 2053, 2251, 2399, 2617, 2797];
  const lines = delays.map((d) => ({ buf: new Float32Array(d), i: 0, lp: 0 }));
  const outL = new Float32Array(N);
  const outR = new Float32Array(N);
  const g = 0.86; // durée de la queue (~2,5 s)
  const damp = 0.35; // aigus absorbés à chaque passage
  const pre = Math.floor(0.025 * SR);
  for (let n = 0; n < N; n++) {
    const xl = n >= pre ? inL[n - pre] : 0;
    const xr = n >= pre ? inR[n - pre] : 0;
    const y = lines.map((l) => l.buf[l.i]);
    // Matrice de Hadamard normalisée (mélange sans perte).
    const h = new Array(8);
    for (let a = 0; a < 8; a++) {
      let s = 0;
      for (let b = 0; b < 8; b++) s += y[b] * (popcount(a & b) % 2 ? -1 : 1);
      h[a] = s / Math.sqrt(8);
    }
    for (const [k, l] of lines.entries()) {
      l.lp += (1 - damp) * (h[k] - l.lp);
      l.buf[l.i] = (k % 2 ? xr : xl) + l.lp * g;
      l.i = (l.i + 1) % l.buf.length;
    }
    outL[n] = (y[0] + y[2] + y[4] + y[6]) * 0.5;
    outR[n] = (y[1] + y[3] + y[5] + y[7]) * 0.5;
  }
  return [outL, outR];
}
function popcount(x) {
  let c = 0;
  for (; x; x &= x - 1) c++;
  return c;
}
const [rl, rr] = reverb(sendL, sendR);

// ---------------------------------------------------------------- Mixage, compression douce, export
let peak = 0;
for (let i = 0; i < N; i++) {
  L[i] = Math.tanh((L[i] + rl[i] * 0.4) * 1.3);
  R[i] = Math.tanh((R[i] + rr[i] * 0.4) * 1.3);
  peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
}
const norm = 0.89 / peak;
const fadeOut = 1.4 * SR;
const pcm = Buffer.alloc(N * 4);
for (let i = 0; i < N; i++) {
  const g = norm * Math.min(1, i / (0.05 * SR)) * Math.min(1, (N - i) / fadeOut);
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
console.log(`musique : ${duration.toFixed(2)} s, ${tl.taps.length} ticks, ${tl.cuts.length} plans`);
