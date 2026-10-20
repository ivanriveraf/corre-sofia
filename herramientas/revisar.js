/**
 * Las imagenes que hay que MIRAR antes de dar por bueno un set de sprites.
 *
 * Existen porque hubo decisiones que ningun numero resolvio, y equivocarse en
 * ellas produjo fallos que solo se vieron en pantalla:
 *
 *   zonas.png   - que grupo de color es el pelo y cual el contorno. Deducirlo
 *                 del color falla: en una tira el pelo hondo y la linea del
 *                 dibujo eran literalmente el mismo color.
 *   tamano.png  - si el personaje calza con el resto del catalogo. Las medidas
 *                 anatomicas se contradijeron entre si (ancho de cabeza, cara,
 *                 ojo, torso dieron cuatro escalas distintas); la que valio fue
 *                 verlo puesto al lado.
 *   caja.png    - donde queda la caja de colision respecto al dibujo.
 */
const path = require("path");
const M = require("./medir.js");

// Colores chillones para distinguir zonas de un vistazo.
const MARCAS = [[255, 0, 255], [0, 220, 0], [255, 40, 40], [0, 160, 255],
                [255, 210, 0], [255, 120, 0], [160, 0, 255]];

function lienzo(w, h, r, g, b) {
  const buf = Buffer.alloc(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    buf[i * 4] = r; buf[i * 4 + 1] = g; buf[i * 4 + 2] = b; buf[i * 4 + 3] = 255;
  }
  return buf;
}

/** Dibuja un cuadro con la MISMA cuenta que hace Godot con escala y origen. */
function poner(dest, dw, dh, im, escala, ox, oy, nodoX, nodoY, alfa) {
  for (let sy = 0; sy < im.h; sy++) {
    for (let sx = 0; sx < im.w; sx++) {
      const o = (sy * im.w + sx) * 4;
      if (im.buf[o + 3] < 25) continue;
      const dx = Math.round(nodoX + escala * (ox - im.w / 2 + sx));
      const dy = Math.round(nodoY + escala * (oy - im.h / 2 + sy));
      if (dx < 0 || dy < 0 || dx >= dw || dy >= dh) continue;
      const d = (dy * dw + dx) * 4;
      const a = alfa === undefined ? 1 : alfa;
      dest[d] = Math.round(dest[d] * (1 - a) + im.buf[o] * a);
      dest[d + 1] = Math.round(dest[d + 1] * (1 - a) + im.buf[o + 1] * a);
      dest[d + 2] = Math.round(dest[d + 2] * (1 - a) + im.buf[o + 2] * a);
    }
  }
}

function recuadro(dest, dw, dh, x0, y0, x1, y1, col) {
  const punto = (x, y) => {
    if (x < 0 || y < 0 || x >= dw || y >= dh) return;
    const d = (y * dw + x) * 4;
    dest[d] = col[0]; dest[d + 1] = col[1]; dest[d + 2] = col[2];
  };
  for (let g = 0; g < 3; g++) {
    for (let x = Math.round(x0); x <= Math.round(x1); x++) { punto(x, Math.round(y0) + g); punto(x, Math.round(y1) - g); }
    for (let y = Math.round(y0); y <= Math.round(y1); y++) { punto(Math.round(x0) + g, y); punto(Math.round(x1) - g, y); }
  }
}

module.exports = function revisar(o) {
  const { pack, marcos, zs, escala, ox, oy, nu, ref, tol, revision } = o;

  // --- 1. que zona es cada cosa ------------------------------------------
  {
    const im = marcos[Math.floor(marcos.length / 2)];
    const out = lienzo(im.w, im.h, 255, 255, 255);
    for (let i = 0; i < im.w * im.h; i++) {
      if (im.buf[i * 4 + 3] < 25) continue;
      const c = [im.buf[i * 4], im.buf[i * 4 + 1], im.buf[i * 4 + 2]];
      let marca = null;
      for (let k = 0; k < zs.length && !marca; k++) {
        for (const t of zs[k].tonos) {
          if (M.dist(c, M.deHex(t)) <= tol) { marca = MARCAS[k % MARCAS.length]; break; }
        }
      }
      // Lo que no cae en ninguna zona se deja gris: es lo que NO se recoloreara.
      const p = marca || [190, 190, 190];
      out[i * 4] = p[0]; out[i * 4 + 1] = p[1]; out[i * 4 + 2] = p[2];
    }
    M.escribirPng(out, im.w, im.h, path.join(revision, pack + "-zonas.png"));
    const nombres = ["magenta", "verde", "rojo", "celeste", "amarillo", "naranjo", "morado"];
    console.log("");
    console.log("  zonas.png:  " + zs.map((z, k) => nombres[k % 7] + "=" + z.nombre).join("  "));
    console.log("              (gris = no se recolorea)");
  }

  // --- 2. calza con el catalogo ------------------------------------------
  if (ref && ref.cuadros.length) {
    const W = 900, H = 620, SUELO = 540;
    const out = lienzo(W, H, 250, 250, 252);
    for (let x = 0; x < W; x++) {
      const d = (SUELO * W + x) * 4;
      out[d] = 220; out[d + 1] = 80; out[d + 2] = 80;
    }
    // La referencia se apoya en el suelo por sus propios pies.
    const r0 = ref.cuadros[0];
    let piesRef = 0;
    for (let y = 0; y < r0.h; y++) {
      for (let x = 0; x < r0.w; x++) if (r0.buf[(y * r0.w + x) * 4 + 3] > 24) { piesRef = y; break; }
    }
    for (let y = r0.h - 1; y >= 0; y--) {
      let hay = false;
      for (let x = 0; x < r0.w && !hay; x++) if (r0.buf[(y * r0.w + x) * 4 + 3] > 24) hay = true;
      if (hay) { piesRef = y; break; }
    }
    poner(out, W, H, r0, ref.escala, 0, r0.h / 2 - piesRef, 250, SUELO);
    // El nuevo va con SU escala y SU origen: si el anclaje esta bien, sus pies
    // caen solos donde deben.
    poner(out, W, H, marcos[0], escala, ox, oy, 620, SUELO);
    M.escribirPng(out, W, H, path.join(revision, pack + "-tamano.png"));
    console.log("  tamano.png: a la izquierda la referencia, a la derecha el nuevo.");
    console.log("              Tienen que verse del mismo tamaño y pisar la misma linea.");
  }

  // --- 3. donde queda la caja de colision ---------------------------------
  {
    const W = 520, H = 620, SUELO = 560;
    const out = lienzo(W, H, 250, 250, 252);
    for (let x = 0; x < W; x++) {
      const d = (SUELO * W + x) * 4;
      out[d] = 220; out[d + 1] = 80; out[d + 2] = 80;
    }
    const im = marcos[0];
    poner(out, W, H, im, escala, ox, oy, W / 2, SUELO);
    recuadro(out, W, H, W / 2 + nu.x, SUELO + nu.y,
      W / 2 + nu.x + nu.ancho, SUELO + nu.y + nu.alto, [0, 160, 255]);
    M.escribirPng(out, W, H, path.join(revision, pack + "-caja.png"));
    console.log("  caja.png:   la caja azul tiene que abrazar el TRONCO. Que el pelo, el");
    console.log("              puño y el pie estirados queden fuera es lo correcto.");
  }
};
