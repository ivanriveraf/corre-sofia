/**
 * Las mediciones que necesita un juego de sprites nuevo.
 *
 * Cada funcion de aqui existe porque su ausencia produjo un fallo concreto que
 * costo encontrar. Estan sueltas para poder probarlas una por una; el que las
 * encadena es agregar_personaje.js.
 */
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// --- ffmpeg hace de codec: Node no decodifica PNG -------------------------
function buscarFfmpeg() {
  const base = path.join(process.env.LOCALAPPDATA || '', 'Microsoft/WinGet/Packages');
  try {
    for (const d of fs.readdirSync(base)) {
      if (!d.startsWith('Gyan.FFmpeg')) continue;
      for (const v of fs.readdirSync(path.join(base, d))) {
        const p = path.join(base, d, v, 'bin/ffmpeg.exe');
        if (fs.existsSync(p)) return p;
      }
    }
  } catch (e) { /* no esta instalado por winget */ }
  return 'ffmpeg';   // que lo resuelva el PATH
}
const FF = buscarFfmpeg();

function leerPng(archivo) {
  const b = fs.readFileSync(archivo);
  const w = b.readUInt32BE(16), h = b.readUInt32BE(20);   // cabecera IHDR
  const tmp = path.join(require('os').tmpdir(), `medir_${Date.now()}.raw`);
  execFileSync(FF, ['-y', '-loglevel', 'error', '-i', archivo,
    '-f', 'rawvideo', '-pix_fmt', 'rgba', tmp]);
  const buf = fs.readFileSync(tmp);
  fs.unlinkSync(tmp);
  return { buf, w, h };
}

function escribirPng(buf, w, h, destino) {
  const tmp = path.join(require('os').tmpdir(), `esc_${Date.now()}.raw`);
  fs.writeFileSync(tmp, buf);
  fs.mkdirSync(path.dirname(destino), { recursive: true });
  execFileSync(FF, ['-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgba',
    '-s', `${w}x${h}`, '-i', tmp, destino]);
  fs.unlinkSync(tmp);
}

const hex = (r, g, b) => [r, g, b].map((v) => v.toString(16).padStart(2, '0')).join('');
const deHex = (s) => [0, 2, 4].map((i) => parseInt(s.slice(i, i + 2), 16));
const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);

function hsv(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  let hu = 0;
  if (d > 0) {
    if (mx === r) hu = 60 * (((g - b) / d) % 6);
    else if (mx === g) hu = 60 * ((b - r) / d + 2);
    else hu = 60 * ((r - g) / d + 4);
  }
  return [(hu + 360) % 360, mx ? d / mx : 0, mx];
}


// --- 1. cortar la tira en cuadros -----------------------------------------

/**
 * Encuentra los cuadros por las columnas transparentes.
 *
 * Dos poses se pegan cuando un brazo o una pierna invade el cuadro vecino y no
 * queda ninguna columna vacia entre ellas. Se reconocen porque salen mucho mas
 * anchas que la mediana, y se parten en tantos trozos como quepan.
 */
function cortar(img) {
  const { buf, w, h } = img;
  const opaca = (x, y) => buf[(y * w + x) * 4 + 3] > 24;
  const llena = [];
  for (let x = 0; x < w; x++) {
    let hay = false;
    for (let y = 0; y < h && !hay; y++) if (opaca(x, y)) hay = true;
    llena.push(hay);
  }
  let cuadros = [], ini = -1;
  for (let x = 0; x <= w; x++) {
    if (x < w && llena[x] && ini < 0) ini = x;
    if ((x === w || !llena[x]) && ini >= 0) {
      if (x - 1 - ini > 20) cuadros.push({ x0: ini, x1: x - 1 });
      ini = -1;
    }
  }
  const anchos = cuadros.map((c) => c.x1 - c.x0 + 1).sort((a, b) => a - b);
  const mediana = anchos[Math.floor(anchos.length / 2)];
  for (let i = cuadros.length - 1; i >= 0; i--) {
    const ancho = cuadros[i].x1 - cuadros[i].x0 + 1;
    const partes = Math.round(ancho / mediana);
    if (partes < 2) continue;
    const paso = ancho / partes;
    const nuevos = [];
    for (let k = 0; k < partes; k++) {
      nuevos.push({
        x0: Math.round(cuadros[i].x0 + k * paso),
        x1: Math.round(cuadros[i].x0 + (k + 1) * paso) - 1,
      });
    }
    cuadros.splice(i, 1, ...nuevos);
  }
  return cuadros.map((c) => ({ ...c, ...encuadre(img, c) }));
}

/** Limites del dibujo dentro de un cuadro, y el centro de la CABEZA. */
function encuadre(img, c) {
  const { buf, w, h } = img;
  const opaca = (x, y) => buf[(y * w + x) * 4 + 3] > 24;
  let arriba = h, abajo = -1;
  for (let y = 0; y < h; y++)
    for (let x = c.x0; x <= c.x1; x++)
      if (opaca(x, y)) { if (y < arriba) arriba = y; if (y > abajo) abajo = y; break; }
  // Ancla horizontal: el centro de la CABEZA, no el de la caja. La caja se
  // ensancha y se angosta con los brazos y las piernas en cada cuadro; si se
  // alinea por ella, el cuerpo se bambolea de lado a lado.
  const corte = arriba + Math.round((abajo - arriba) * 0.30);
  let cx0 = c.x1, cx1 = c.x0;
  for (let y = arriba; y <= corte; y++)
    for (let x = c.x0; x <= c.x1; x++)
      if (opaca(x, y)) { if (x < cx0) cx0 = x; if (x > cx1) cx1 = x; }
  return { arriba, abajo, centro: (cx0 + cx1) / 2, alto: abajo - arriba + 1 };
}

/**
 * Recorta cada cuadro a un lienzo comun.
 *
 * Vertical: por los PIES en las animaciones de suelo. La primera version usaba
 * un desplazamiento comun para conservar el rebote del ciclo original y se veia
 * mal — en algunas poses los pies flotaban 20 px sobre el suelo y en otras lo
 * pisaban, y el conjunto se leia como si patinara.
 *
 * Con anclaje "cabeza" se alinea por arriba: es lo que corresponde en un salto,
 * donde los pies se recogen y alinear por ellos hunde el cuerpo en cada cuadro.
 */
function recortar(img, cuadros, porCabeza) {
  const { buf, w, h } = img;
  const anchoMax = Math.max(...cuadros.map((c) => c.x1 - c.x0 + 1));
  const altoMax = Math.max(...cuadros.map((c) => c.alto));
  const piesMax = Math.max(...cuadros.map((c) => c.abajo));
  const arribaMin = Math.min(...cuadros.map((c) => c.arriba));
  const lw = anchoMax + 40;
  const lh = (porCabeza ? altoMax : piesMax - arribaMin) + 40;

  return cuadros.map((c) => {
    const salida = Buffer.alloc(lw * lh * 4, 0);
    const dx = Math.round(lw / 2 - c.centro);
    const dy = porCabeza ? Math.round(20 - c.arriba) : Math.round(lh - 20 - c.abajo);
    for (let y = 0; y < h; y++) {
      for (let x = c.x0; x <= c.x1; x++) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= lw || ny >= lh) continue;
        const o = (y * w + x) * 4, d = (ny * lw + nx) * 4;
        salida[d] = buf[o]; salida[d + 1] = buf[o + 1];
        salida[d + 2] = buf[o + 2]; salida[d + 3] = buf[o + 3];
      }
    }
    return { buf: salida, w: lw, h: lh };
  });
}

module.exports = { FF, leerPng, escribirPng, hex, deHex, dist, hsv, cortar, encuadre, recortar };


// --- 2. la paleta ---------------------------------------------------------

/**
 * Agrupa los colores del sprite en zonas (piel, pelo, ropa) y da, para cada
 * una, el MINIMO de tonos que la cubre a la tolerancia real del shader.
 *
 * POR QUE ASI, y no a ojo: la falda tenia SEIS tonos y yo puse uno. Los tonos
 * de sombra de los pliegues estan a distancia 130 del tono base — ninguna
 * tolerancia razonable los alcanza — asi que se quedaron azules mientras el
 * resto se volvia rosado, y mezclados la falda se veia violeta.
 *
 * Y por que el minimo: las ranuras del shader son 24. Sobrar tonos en la piel
 * es quedarse corto en la falda.
 */
function zonas(cuadros, tolerancia) {
  // Se cuentan los colores REDONDEADOS a una rejilla de 6. Un sprite trae
  // decenas de miles de colores distintos por el antialias, y la cobertura
  // avara es cuadratica: sin redondear, esto tarda minutos. Redondeando a 6 el
  // error maximo es de 3 por canal, muy por debajo de la tolerancia del shader.
  const REJILLA = 6;
  const cuenta = new Map();
  for (const im of cuadros) {
    for (let i = 0; i < im.w * im.h; i++) {
      if (im.buf[i * 4 + 3] < 200) continue;
      const k = hex(
        Math.round(im.buf[i * 4] / REJILLA) * REJILLA,
        Math.round(im.buf[i * 4 + 1] / REJILLA) * REJILLA,
        Math.round(im.buf[i * 4 + 2] / REJILLA) * REJILLA);
      cuenta.set(k, (cuenta.get(k) || 0) + 1);
    }
  }
  // Agrupacion gruesa por TONO. El brillo no sirve para separar zonas: la
  // sombra de una puede ser mas oscura que el color base de otra.
  const grupos = new Map();
  for (const [k, n] of cuenta) {
    const [r, g, b] = deHex(k);
    const [hu, s, v] = hsv(r, g, b);
    // Agrupacion GRUESA a proposito. Con cortes finos, la piel se parte en tres
    // zonas y la falda en dos, y entre todas piden mas tonos de los 24 que hay.
    // Es mejor pasarse de junto: separar dos zonas que salieron pegadas se hace
    // a mano mirando la imagen, unir cinco fragmentos no.
    let clave;
    if (v < 0.42) clave = 'oscuro';
    else if (s < 0.10) clave = 'claro';
    else clave = 'tono' + (Math.round(hu / 60) * 60) % 360;
    if (!grupos.has(clave)) grupos.set(clave, []);
    grupos.get(clave).push([k, n]);
  }

  const salida = [];
  for (const [clave, lista] of grupos) {
    const total = lista.reduce((s, e) => s + e[1], 0);
    if (total < 1200) continue;                      // ruido de antialias
    salida.push({ nombre: clave, total, tonos: cubrir(lista, tolerancia) });
  }
  return salida.sort((a, b) => b.total - a.total);
}

/**
 * Cobertura avara: elige el tono mas frecuente, tacha los pixeles que alcanza a
 * la tolerancia del shader, y repite hasta cubrir el 99%. Asi cada tono listado
 * se gana su ranura en vez de repetir a otro.
 */
function cubrir(lista, tolerancia) {
  const quedan = new Map(lista);
  const total = lista.reduce((s, e) => s + e[1], 0);
  const elegidos = [];
  let cubierto = 0;
  // 97% y no 100%: el ultimo 3% son pixeles sueltos del antialias, y cada tono
  // que se lleva ocupa una ranura de las 24 que tiene el shader.
  while (quedan.size && cubierto / total < 0.97 && elegidos.length < 8) {
    let mejor = null, mejorN = -1;
    for (const [k] of quedan) {
      let suma = 0;
      const c = deHex(k);
      for (const [k2, n2] of quedan) if (dist(c, deHex(k2)) <= tolerancia) suma += n2;
      if (suma > mejorN) { mejorN = suma; mejor = k; }
    }
    const c = deHex(mejor);
    for (const [k2, n2] of [...quedan])
      if (dist(c, deHex(k2)) <= tolerancia) { quedan.delete(k2); cubierto += n2; }
    elegidos.push(mejor);
  }
  return elegidos;
}

/**
 * Cuanto CONTORNO se llevaria puesto una lista de tonos.
 *
 * Es la prueba que evita el peor fallo del recoloreo. En la tira del salto, un
 * tono que parecia sombra del pelo recoloreaba el 47% del contorno: la figura
 * entera perdia su linea y dejaba de leerse como dibujo plano. Ni bajando la
 * tolerancia se separaban, porque en esa tira el pelo hondo y el contorno son
 * literalmente el mismo color.
 *
 * "Contorno" = pixel oscuro a <=2 px de uno transparente.
 */
function chocaContorno(cuadros, tonos, tolerancia) {
  let contorno = 0;
  const culpa = new Map();
  for (const im of cuadros) {
    const { buf, w, h } = im;
    const alfa = (x, y) => (x < 0 || y < 0 || x >= w || y >= h) ? 0 : buf[(y * w + x) * 4 + 3];
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        if (alfa(x, y) < 25) continue;
        const i = (y * w + x) * 4;
        const c = [buf[i], buf[i + 1], buf[i + 2]];
        if (Math.max(...c) > 60) continue;
        let borde = false;
        for (let dy = -2; dy <= 2 && !borde; dy++)
          for (let dx = -2; dx <= 2; dx++)
            if (alfa(x + dx, y + dy) < 25) { borde = true; break; }
        if (!borde) continue;
        contorno++;
        for (const t of tonos)
          if (dist(c, deHex(t)) <= tolerancia) { culpa.set(t, (culpa.get(t) || 0) + 1); break; }
      }
    }
  }
  const tocados = [...culpa.values()].reduce((a, b) => a + b, 0);
  return { contorno, tocados, culpa };
}


// --- 3. la geometria ------------------------------------------------------

/** Pixel que pertenece al cuerpo: opaco, no contorno y no pelo. */
function esCuerpo(im, x, y, pelo) {
  const k = (y * im.w + x) * 4;
  if (im.buf[k + 3] < 200) return false;
  const c = [im.buf[k], im.buf[k + 1], im.buf[k + 2]];
  if (Math.max(...c) < 90) return false;
  return !pelo.some((p) => dist(c, deHex(p)) <= 40);
}

/**
 * Caja del NUCLEO del cuerpo, relativa al nodo y en pixeles de pantalla.
 *
 * De aqui sale la colision. Nucleo = solo las columnas con cuerpo en al menos
 * el 30% del alto: un brazo o una pierna estirados ocupan pocas filas y quedan
 * fuera, el tronco queda dentro.
 *
 * POR QUE: con la caja sacada del dibujo entero, el pie delantero de la zancada
 * llegaba 50 px mas alla del cuerpo y se perdia la partida porque la punta del
 * zapato rozo el obstaculo. Un niño de 6 años lee eso como injusto.
 *
 * El ALTO en cambio va del cuerpo completo, no del nucleo: es el que decide si
 * pasa por encima del obstaculo, y ahi si cuentan los pies.
 */
function nucleo(cuadros, escala, ox, oy, pelo) {
  const L = [], R = [], T = [], B = [];
  for (const im of cuadros) {
    const { w, h } = im;
    let arr = h, ab = -1;
    const col = new Array(w).fill(0);
    for (let y = 0; y < h; y++)
      for (let x = 0; x < w; x++)
        if (esCuerpo(im, x, y, pelo)) {
          col[x]++;
          if (y < arr) arr = y;
          if (y > ab) ab = y;
        }
    const alto = ab - arr + 1;
    let izq = w, der = -1;
    for (let x = 0; x < w; x++)
      if (col[x] >= alto * 0.30) { if (x < izq) izq = x; if (x > der) der = x; }
    const px = (c) => (ox - w / 2 + c) * escala;
    const py = (r) => (oy - h / 2 + r) * escala;
    L.push(px(izq)); R.push(px(der)); T.push(py(arr)); B.push(py(ab));
  }
  const med = (a) => [...a].sort((x, y) => x - y)[Math.floor(a.length / 2)];
  const prom = (a) => a.reduce((s, v) => s + v, 0) / a.length;
  // El fondo va por PROMEDIO y no por el cuadro mas bajo: con las piernas
  // recogidas el cuerpo de verdad esta mas arriba, y quedarse con el cuadro
  // menos recogido es lo que hacia perder sin haber tocado nada.
  return {
    x: med(L), y: med(T),
    ancho: med(R) - med(L),
    alto: prom(B) - med(T),
    piesMin: Math.min(...B), piesMax: Math.max(...B),
  };
}

/** Caja del cuerpo entero (sin pelo), para comparar contra el nucleo. */
function cuerpoEntero(cuadros, escala, ox, pelo) {
  const L = [], R = [];
  for (const im of cuadros) {
    let izq = im.w, der = -1;
    for (let y = 0; y < im.h; y++)
      for (let x = 0; x < im.w; x++)
        if (esCuerpo(im, x, y, pelo)) { if (x < izq) izq = x; if (x > der) der = x; }
    L.push((ox - im.w / 2 + izq) * escala);
    R.push((ox - im.w / 2 + der) * escala);
  }
  return { izq: Math.min(...L), der: Math.max(...R) };
}

/**
 * Cuanto suelo pasa por cada cuadro de la animacion.
 *
 * Es la condicion exacta de "no patinar": el personaje esta clavado en x, asi
 * que el pie apoyado tiene que retroceder EN LA ANIMACION lo mismo que avanza
 * el suelo. Si retrocede mas, las piernas se ven aceleradas — que es como se
 * reporto el fallo: "corren muy rapido".
 *
 * Se sigue el bloque de pie que llega mas abajo y se mide cuanto se corrio su
 * centro. Los saltos hacia adelante son el pie despegando y no cuentan.
 *
 * OJO: en un galope de cuatro patas cada una apoya uno o dos cuadros de seis,
 * muy poco para seguir una sola, y esto devuelve valores incoherentes. La
 * funcion lo dice en `fiable`; cuando es false hay que sacar el numero de la
 * zancada y comprobarlo mirando.
 */
function avance(cuadros, escala) {
  const pies = cuadros.map((im) => {
    const { w, h } = im;
    const opaca = (x, y) => im.buf[(y * w + x) * 4 + 3] > 24;
    let arr = h, ab = -1;
    for (let y = 0; y < h; y++)
      for (let x = 0; x < w; x++)
        if (opaca(x, y)) { if (y < arr) arr = y; if (y > ab) ab = y; break; }
    const y0 = ab - Math.round((ab - arr) * 0.10);
    const col = new Array(w).fill(-1);
    for (let x = 0; x < w; x++)
      for (let y = y0; y <= ab; y++) if (opaca(x, y)) col[x] = y;
    const bloques = [];
    let ini = -1;
    for (let x = 0; x <= w; x++) {
      if (x < w && col[x] >= 0 && ini < 0) ini = x;
      if ((x === w || col[x] < 0) && ini >= 0) {
        if (x - ini > 8) {
          let bajo = -1;
          for (let k = ini; k < x; k++) if (col[k] > bajo) bajo = col[k];
          bloques.push({ centro: (ini + x - 1) / 2, bajo });
        }
        ini = -1;
      }
    }
    bloques.sort((a, b) => b.bajo - a.bajo);
    return bloques[0] ? bloques[0].centro : 0;
  });

  const retros = [];
  for (let i = 0; i < pies.length; i++) {
    const d = pies[i] - pies[(i + 1) % pies.length];
    if (d > 0) retros.push(d * escala);
  }
  if (!retros.length) return { valor: 0, fiable: false, muestras: [] };
  const orden = [...retros].sort((a, b) => a - b);
  const mediana = orden[Math.floor(orden.length / 2)];
  // Si las muestras no se parecen entre si, no estamos siguiendo el mismo pie.
  const disperso = orden[orden.length - 1] > orden[0] * 2.2;
  return { valor: mediana, fiable: retros.length >= 3 && !disperso, muestras: retros };
}

module.exports.zonas = zonas;
module.exports.cubrir = cubrir;
module.exports.chocaContorno = chocaContorno;
module.exports.nucleo = nucleo;
module.exports.cuerpoEntero = cuerpoEntero;
module.exports.avance = avance;
module.exports.esCuerpo = esCuerpo;


/**
 * Altura del centro del cuerpo respecto al nodo, en pixeles de pantalla.
 *
 * Sirve para anclar una animacion en el aire. Los pies no valen (en un salto se
 * recogen) y la cabeza tampoco: fijandola, los pies pegaban un salto de 79 px
 * al despegar. El centro del cuerpo si: no lo mueve ni recoger las piernas ni
 * levantar los brazos.
 */
function centroCuerpo(cuadros, escala, oy, pelo) {
  const alturas = [];
  for (const im of cuadros) {
    // Solo las columnas del TRONCO. Con el cuerpo entero, recoger las piernas
    // sube el centro 30 px y el personaje queda colgado mas abajo de lo que
    // toca; el tronco en cambio se queda donde esta haga lo que haga con los
    // brazos y las piernas.
    let arr = im.h, ab = -1;
    const col = new Array(im.w).fill(0);
    for (let y = 0; y < im.h; y++)
      for (let x = 0; x < im.w; x++)
        if (esCuerpo(im, x, y, pelo)) {
          col[x]++;
          if (y < arr) arr = y;
          if (y > ab) ab = y;
        }
    const alto = ab - arr + 1;
    let suma = 0, n = 0;
    for (let y = 0; y < im.h; y++)
      for (let x = 0; x < im.w; x++)
        if (col[x] >= alto * 0.30 && esCuerpo(im, x, y, pelo)) { suma += y; n++; }
    if (n) alturas.push(escala * (oy - im.h / 2 + suma / n));
  }
  return alturas.reduce((s, v) => s + v, 0) / alturas.length;
}

module.exports.centroCuerpo = centroCuerpo;
