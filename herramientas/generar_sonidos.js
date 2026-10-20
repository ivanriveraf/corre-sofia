/**
 * Sintetiza los efectos de sonido del juego como WAV.
 *
 * POR QUE GENERARLOS Y NO BAJARLOS: este proyecto ya perdio tiempo con packs de
 * sprites de licencia dudosa que acabaron sin poder usarse. Un sonido hecho aqui
 * no tiene ese problema: es nuestro, se puede publicar, y si hace falta cambiarlo
 * se cambia un numero y se vuelve a generar.
 *
 * El publico son niños de 4 a 9 años, asi que nada de ruido aspero ni golpes
 * secos: ondas triangulares suaves, notas afinadas y colas cortas.
 *
 *   node herramientas/generar_sonidos.js
 */
const fs = require("fs");
const path = require("path");

const HZ = 22050;          // de sobra para efectos; pesa la mitad que 44100
const destino = path.join(__dirname, "..", "audio");

// --- sintesis -------------------------------------------------------------

/** Triangular: tiene armonicos como la cuadrada pero sin su aspereza. */
const triangulo = (f, t) => {
  const x = (t * f) % 1;
  return 4 * Math.abs(x - 0.5) - 1;
};
const seno = (f, t) => Math.sin(2 * Math.PI * f * t);

/**
 * Envolvente ataque/caida. El ataque corto evita el "click" de empezar una onda
 * de golpe, que en auriculares se oye como un chasquido.
 */
function envolvente(t, dur, ataque) {
  const a = ataque === undefined ? 0.005 : ataque;
  if (t < a) return t / a;
  return Math.max(0, 1 - (t - a) / (dur - a));
}

/** Suma de notas: cada una con su frecuencia (o barrido), inicio y duracion. */
function mezclar(duracionTotal, notas) {
  const n = Math.floor(HZ * duracionTotal);
  const muestras = new Float64Array(n);
  for (const nota of notas) {
    const ini = Math.floor(nota.desde * HZ);
    const largo = Math.floor(nota.dur * HZ);
    for (let i = 0; i < largo && ini + i < n; i++) {
      const t = i / HZ;
      const prog = i / largo;
      // Si trae "hasta", la frecuencia barre de "hz" a "hasta".
      const f = nota.hasta === undefined ? nota.hz : nota.hz + (nota.hasta - nota.hz) * prog;
      const onda = nota.onda === "seno" ? seno : triangulo;
      const env = envolvente(t, nota.dur, nota.ataque);
      muestras[ini + i] += onda(f, t) * env * (nota.vol === undefined ? 1 : nota.vol);
    }
  }
  return muestras;
}

/** Ruido con filtro paso-bajo, para el golpe. Sin filtro suena a estatica. */
function ruido(dur, vol, suavidad) {
  const n = Math.floor(HZ * dur);
  const m = new Float64Array(n);
  let previo = 0;
  for (let i = 0; i < n; i++) {
    const crudo = Math.random() * 2 - 1;
    previo = previo * suavidad + crudo * (1 - suavidad);
    m[i] = previo * envolvente(i / HZ, dur) * vol;
  }
  return m;
}

function sumar(a, b) {
  const n = Math.max(a.length, b.length);
  const r = new Float64Array(n);
  for (let i = 0; i < n; i++) r[i] = (a[i] || 0) + (b[i] || 0);
  return r;
}

/** WAV mono de 16 bits. La cabecera son 44 bytes y luego las muestras. */
function escribirWav(muestras, archivo) {
  // Normaliza al 85%: deja aire para que al sonar dos efectos juntos no sature.
  let pico = 0;
  for (const v of muestras) pico = Math.max(pico, Math.abs(v));
  const g = pico > 0 ? 0.85 / pico : 1;

  const n = muestras.length;
  const buf = Buffer.alloc(44 + n * 2);
  buf.write("RIFF", 0);
  buf.writeUInt32LE(36 + n * 2, 4);
  buf.write("WAVE", 8);
  buf.write("fmt ", 12);
  buf.writeUInt32LE(16, 16);          // tamaño del bloque fmt
  buf.writeUInt16LE(1, 20);           // PCM sin comprimir
  buf.writeUInt16LE(1, 22);           // mono
  buf.writeUInt32LE(HZ, 24);
  buf.writeUInt32LE(HZ * 2, 28);      // bytes por segundo
  buf.writeUInt16LE(2, 32);           // bytes por muestra
  buf.writeUInt16LE(16, 34);          // bits por muestra
  buf.write("data", 36);
  buf.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) {
    buf.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(muestras[i] * g * 32767))), 44 + i * 2);
  }
  fs.mkdirSync(path.dirname(archivo), { recursive: true });
  fs.writeFileSync(archivo, buf);
  console.log("   " + path.basename(archivo).padEnd(16) +
    (n / HZ).toFixed(2) + " s   " + (buf.length / 1024).toFixed(0) + " KB");
}

// --- los efectos ----------------------------------------------------------
// Las notas estan afinadas entre si (do mayor) para que, cuando se encadenan
// varias al juntar coleccionables seguidos, suene a musica y no a pitidos.
const DO = 523.25, MI = 659.25, SOL = 783.99, DO_ALTO = 1046.5, LA = 880;

console.log("");
console.log("  generando efectos en audio/");

// Salto: barrido hacia arriba, corto. Hacia arriba porque sube el personaje.
escribirWav(mezclar(0.16, [
  { hz: 380, hasta: 760, desde: 0, dur: 0.13, vol: 0.8 },
]), path.join(destino, "salto.wav"));

// Recoger: dos notas que suben. Es el sonido que mas se oye en la partida —
// 25 veces por juego — asi que va corto y suave, o cansa.
escribirWav(mezclar(0.20, [
  { hz: SOL, desde: 0.00, dur: 0.07, onda: "seno", vol: 0.7 },
  { hz: DO_ALTO, desde: 0.05, dur: 0.12, onda: "seno", vol: 0.7 },
]), path.join(destino, "recoger.wav"));

// Choque: nota grave que cae, con algo de ruido para darle cuerpo. Suave a
// proposito: el niño ya perdio, no hace falta asustarlo.
escribirWav(sumar(
  mezclar(0.35, [{ hz: 300, hasta: 110, desde: 0, dur: 0.30, vol: 0.9 }]),
  ruido(0.16, 0.25, 0.75)
), path.join(destino, "choque.wav"));

// Ganar: arpegio de do mayor subiendo, y la ultima nota mas larga.
escribirWav(mezclar(0.70, [
  { hz: DO, desde: 0.00, dur: 0.12, onda: "seno" },
  { hz: MI, desde: 0.10, dur: 0.12, onda: "seno" },
  { hz: SOL, desde: 0.20, dur: 0.12, onda: "seno" },
  { hz: DO_ALTO, desde: 0.30, dur: 0.38, onda: "seno" },
  { hz: MI * 2, desde: 0.30, dur: 0.38, onda: "seno", vol: 0.4 },
]), path.join(destino, "ganar.wav"));

// Perder: el mismo arpegio al reves. No es un "error": baja y se queda en una
// nota tranquila, para que invite a intentarlo otra vez.
escribirWav(mezclar(0.55, [
  { hz: SOL, desde: 0.00, dur: 0.13, onda: "seno" },
  { hz: MI, desde: 0.11, dur: 0.13, onda: "seno" },
  { hz: DO, desde: 0.22, dur: 0.30, onda: "seno" },
]), path.join(destino, "perder.wav"));

// Empezar: dos notas que invitan, para el boton de JUGAR.
escribirWav(mezclar(0.30, [
  { hz: MI, desde: 0.00, dur: 0.10, onda: "seno" },
  { hz: LA, desde: 0.08, dur: 0.20, onda: "seno" },
]), path.join(destino, "empezar.wav"));

console.log("");
console.log("  listos. Son nuestros: se pueden publicar sin pedirle permiso a nadie.");
console.log("");
