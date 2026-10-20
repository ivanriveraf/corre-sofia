/**
 * Mide una tira de sprites nueva y escupe todo lo que hay que pegar en el juego.
 *
 * PARA QUE SIRVE: cada tira generada sale distinta aunque sea el mismo dibujo —
 * otros colores, otro tamaño, otro anclaje — y hay que medirla entera antes de
 * que sirva. A mano son ocho mediciones con criterio; olvidar una da un fallo
 * concreto que ya conocemos:
 *
 *   paleta mal medida  -> la falda a medio pintar, mezclada, se ve violeta
 *   contorno no visto  -> el recoloreo se come la linea de toda la figura
 *   escala mal         -> el personaje cambia de tamaño al saltar
 *   anclaje mal        -> los pies flotan sobre el suelo o se hunden
 *   avance mal         -> las piernas se ven aceleradas, patinando
 *   nucleo mal         -> se pierde por rozar con la punta del zapato
 *
 * ESTO NO LO DECIDE TODO, y conviene saberlo. Deja tres imagenes en
 * herramientas/revision/ que hay que MIRAR: hubo criterio que ningun numero
 * resolvio — cual grupo de color es el pelo y cual el contorno, y si la escala
 * calza de verdad. La herramienta mide y propone; confirmar es tuyo.
 *
 *   node herramientas/agregar_personaje.js <tira.png> --set ninoCorto --anim run
 *        [--anclaje cabeza]      para saltos: alinea por arriba, no por los pies
 *        [--referencia arte/nina-suelto/run:6:0.611]   con quien calzar el tamaño
 *        [--escala 0.64]         para imponerla despues de mirar la comparacion
 *        [--tolerancia 19]       la del shader para este pack, en 0-255
 *        [--escribir]            sin esto solo mide, no toca ningun archivo
 */
const fs = require("fs");
const path = require("path");
const M = require("./medir.js");

const args = process.argv.slice(2);
const tira = args[0];
const opcion = (n, def) => {
  const i = args.indexOf("--" + n);
  return i >= 0 && args[i + 1] && !args[i + 1].startsWith("--") ? args[i + 1] : def;
};
const bandera = (n) => args.includes("--" + n);

if (!tira || bandera("ayuda")) {
  console.log(fs.readFileSync(__filename, "utf8").split("*/")[0]);
  process.exit(0);
}

const set = opcion("set", "nuevo");
const anim = opcion("anim", "run");
const pack = set + anim.charAt(0).toUpperCase() + anim.slice(1);
const porCabeza = opcion("anclaje", "pie") === "cabeza";
const tol = +opcion("tolerancia", 19);
const raiz = path.join(__dirname, "..");
const guion = (s) => s.replace(/([A-Z])/g, "-$1").toLowerCase();
const carpeta = opcion("carpeta", "arte/" + guion(set));

console.log("");
console.log("  tira: " + tira);
console.log("  set:  " + set + " / " + anim + "   anclaje por " + (porCabeza ? "CABEZA" : "PIES"));
console.log("");

// --- cortar ---------------------------------------------------------------
const img = M.leerPng(tira);
const cuadros = M.cortar(img);
console.log("  " + cuadros.length + " cuadros en una tira de " + img.w + "x" + img.h);
const pies = cuadros.map((c) => c.abajo);
console.log("  pies entre " + Math.min(...pies) + " y " + Math.max(...pies) +
  " (varian " + (Math.max(...pies) - Math.min(...pies)) +
  " px; si es mucho, cada cuadro se dibujo a otra altura)");
const marcos = M.recortar(img, cuadros, porCabeza);
const LW = marcos[0].w, LH = marcos[0].h;
console.log("  lienzo comun: " + LW + "x" + LH);

// medidas basicas del dibujo dentro del lienzo
const limites = marcos.map((im) => {
  let a = im.h, b = -1, i = im.w, d = -1;
  for (let y = 0; y < im.h; y++) {
    for (let x = 0; x < im.w; x++) {
      if (im.buf[(y * im.w + x) * 4 + 3] <= 24) continue;
      if (y < a) a = y;
      if (y > b) b = y;
      if (x < i) i = x;
      if (x > d) d = x;
    }
  }
  return { alto: b - a + 1, ancho: d - i + 1, arriba: a, abajo: b };
});
const altoMedio = limites.reduce((s, v) => s + v.alto, 0) / limites.length;

// --- paleta ---------------------------------------------------------------
console.log("");
console.log("  ZONAS DE COLOR   (cual es cual se ve en revision/" + pack + "-zonas.png)");
const zs = M.zonas(marcos, tol);
for (const z of zs) {
  const ch = M.chocaContorno(marcos, z.tonos, tol);
  const pct = ch.contorno ? (100 * ch.tocados / ch.contorno) : 0;
  let aviso = "";
  if (pct > 8) {
    // Un solo tono puede arruinar el dibujo entero: en la tira del salto habia
    // uno que se comia el 47% del contorno. Se saca el culpable, no la zona.
    const peor = [...ch.culpa.entries()].sort((a, b) => b[1] - a[1])[0];
    if (peor) {
      z.tonos = z.tonos.filter((t) => t !== peor[0]);
      aviso = "   [SACADO \"" + peor[0] + "\": se comia el " + pct.toFixed(0) + "% del contorno]";
    }
  }
  console.log("   " + z.nombre.padEnd(10) + String(z.total).padStart(8) + " px   " +
    z.tonos.length + " tonos" + aviso);
}
const ranuras = zs.reduce((s, z) => s + z.tonos.length, 0);
console.log("   " + ranuras + " tonos en total. El shader tiene 24 RANURAS, pero solo");
console.log("   gastan ranura las zonas que pongas en paleta.gd: elige 2 o 3 (piel, pelo,");
console.log("   ropa) y deja el resto sin recolorear.");

// El pelo se supone que es la zona oscura. Es una SUPOSICION: confirmala en la
// imagen de zonas. Se usa para descontarlo del cuerpo, porque el pelo al vuelo
// no choca con nada y si entra manda en el ancho.
const zonaPelo = zs.find((z) => z.nombre === "oscuro");
const pelo = zonaPelo ? zonaPelo.tonos : [];

// --- escala ---------------------------------------------------------------
console.log("");
let escala = +opcion("escala", 0);
let ref = null;
const refTxt = opcion("referencia", "");
if (refTxt) {
  const partes = refTxt.split(":");
  ref = { cuadros: [], escala: +partes[2], prefijo: partes[0] };
  for (let i = 1; i <= +partes[1]; i++) {
    const f = path.join(raiz, partes[0] + "_" + String(i).padStart(2, "0") + ".png");
    if (fs.existsSync(f)) ref.cuadros.push(M.leerPng(f));
  }
  const refAltos = ref.cuadros.map((im) => {
    let a = im.h, b = -1;
    for (let y = 0; y < im.h; y++) {
      for (let x = 0; x < im.w; x++) {
        if (im.buf[(y * im.w + x) * 4 + 3] > 24) { if (y < a) a = y; if (y > b) b = y; break; }
      }
    }
    return b - a + 1;
  });
  ref.altoMedio = refAltos.reduce((s, v) => s + v, 0) / refAltos.length;
  if (!escala) escala = ref.escala * ref.altoMedio / altoMedio;
  console.log("  ESCALA " + escala.toFixed(3) + ": el dibujo mide " + altoMedio.toFixed(0) +
    " px de alto contra " + ref.altoMedio.toFixed(0) + " de la referencia.");
  console.log("   Esto vale cuando las dos animaciones tienen POSES PARECIDAS (una carrera");
  console.log("   contra otra carrera). Entre una carrera y un salto NO vale: ahi el alto");
  console.log("   cambia por la pose y no por el tamaño, y hay que mirar la comparacion.");
} else {
  if (!escala) escala = 0.6;
  console.log("  ESCALA " + escala.toFixed(3) + " (sin referencia: pasa --escala o --referencia)");
}

// --- anclaje --------------------------------------------------------------
// El recorte ya dejo la cabeza centrada en el lienzo y los pies (o la cabeza) a
// 20 px del borde, asi que el origen sale de ahi. En pantalla, el pixel (px,py)
// de la textura cae en   posicion + escala * (origen - tamaño/2 + (px,py)).
const ox = 0;
let oy = LH / 2 - (LH - 20);        // pies al ras del suelo
if (porCabeza) {
  // En el aire los pies no valen de ancla: se recogen. La cabeza tampoco —
  // fijandola, los pies pegaban un salto de 79 px al despegar. Lo que no mueve
  // ni recoger las piernas ni levantar los brazos es el CENTRO del cuerpo, asi
  // que se cuelga de ahi, a la altura que tiene en la animacion de referencia.
  //
  // El origen de la referencia se deduce de como se corto: esta herramienta deja
  // los pies a 20 px del borde de abajo, o sea origen.y = 20 - alto/2.
  if (!ref || !ref.cuadros.length) {
    console.log("  ORIGEN: sin --referencia no se puede anclar una animacion en el aire.");
    console.log("   Pasa la animacion de suelo del mismo personaje como referencia.");
  } else {
    const oyRef = 20 - ref.cuadros[0].h / 2;
    // Los dos centros se miden IGUAL (sin descontar pelo con listas distintas),
    // o la comparacion no seria entre lo mismo.
    const centroRef = M.centroCuerpo(ref.cuadros, ref.escala, oyRef, []);
    const centroCrudo = M.centroCuerpo(marcos, escala, 0, []);
    oy = (centroRef - centroCrudo) / escala;
    console.log("  el centro del cuerpo de la referencia esta a " + centroRef.toFixed(0) +
      " px del suelo; se cuelga el nuevo a la misma altura");
  }
}
console.log("  ORIGEN (" + ox.toFixed(1) + ", " + oy.toFixed(1) + ")" +
  (porCabeza ? "" : "   [los pies quedan al ras del suelo]"));

// --- avance ---------------------------------------------------------------
const av = M.avance(marcos, escala);
console.log("");
if (porCabeza) {
  console.log("  AVANCE 0: una animacion en el aire no la mueve el suelo. El cuadro lo");
  console.log("    elige la fisica del salto, no la animacion (ver _animar_salto en main.gd).");
  av.valor = 0;
} else if (av.fiable) {
  console.log("  AVANCE " + av.valor.toFixed(1) + " px de suelo por cuadro (pie apoyado seguido en " +
    av.muestras.length + " pares)");
} else {
  console.log("  AVANCE " + av.valor.toFixed(1) + " px por cuadro   [POCO FIABLE]");
  console.log("    muestras: " + av.muestras.map((v) => v.toFixed(0)).join(", ") +
    " - no se esta siguiendo el mismo pie.");
  console.log("    Pasa en cuadrupedos: en un galope cada pata apoya uno o dos cuadros de");
  console.log("    seis. Sacalo de la zancada (avance * cuadros = 2 a 3 veces la altura de");
  console.log("    lomo) y compruebalo mirando que las patas no patinen.");
}

// --- nucleo ---------------------------------------------------------------
const nu = M.nucleo(marcos, escala, ox, oy, pelo);
const ent = M.cuerpoEntero(marcos, escala, ox, pelo);
console.log("");
console.log("  NUCLEO " + nu.ancho.toFixed(0) + " px de ancho, contra " +
  (ent.der - ent.izq).toFixed(0) + " del cuerpo entero.");
console.log("    La diferencia son los brazos y las piernas estirados, y queda fuera a");
console.log("    proposito: perder porque la punta del zapato rozo el obstaculo se siente");
console.log("    injusto, y para un niño de 6 años eso arruina el regalo.");
console.log("  pies del cuerpo entre " + nu.piesMin.toFixed(0) + " y " + nu.piesMax.toFixed(0) +
  " px del nodo" + (nu.piesMax < -20 ? "   (recogidos: es un salto)" : ""));

// --- lo que hay que pegar -------------------------------------------------
const T = "\t";
console.log("");
console.log("  === pega esto en FUENTES, en src/arte.gd ===");
console.log(T + T + T + "\"" + anim + "\": {");
console.log(T + T + T + T + "\"pack\": \"" + pack + "\",");
console.log(T + T + T + T + "\"cuadros\": " + marcos.length + ",");
console.log(T + T + T + T + "\"avance\": " + av.valor.toFixed(1) + ",");
console.log(T + T + T + T + "\"escala\": " + escala.toFixed(3) + ",");
console.log(T + T + T + T + "\"origen\": Vector2(" + ox.toFixed(1) + ", " + oy.toFixed(1) + "),");
console.log(T + T + T + T + "\"dibujo\": Vector2(" +
  Math.max(...limites.map((l) => l.ancho)).toFixed(1) + ", " +
  Math.max(...limites.map((l) => l.alto)).toFixed(1) + "),");
console.log(T + T + T + T + "\"cuerpo\": Rect2(" + nu.x.toFixed(1) + ", " + nu.y.toFixed(1) +
  ", " + nu.ancho.toFixed(1) + ", " + nu.alto.toFixed(1) + "),");
console.log(T + T + T + "},");
console.log("");
console.log("  === pega esto en PALETAS, en src/paleta.gd (ponle nombre a cada zona) ===");
console.log(T + "\"" + pack + "\": {");
for (const z of zs) {
  const nombre = z.nombre === "oscuro" ? "pelo" : (z.nombre === "claro" ? "SIN_RECOLOREAR" : "???");
  console.log(T + T + "\"" + nombre + "\": {");
  console.log(T + T + T + "\"base\": \"" + z.tonos[0] + "\",");
  console.log(T + T + T + "\"tonos\": [" + z.tonos.map((t) => "\"" + t + "\"").join(", ") + "],");
  console.log(T + T + "},");
}
console.log(T + "},");
console.log("");
console.log("  Los nombres de zona los pones tu: piel, pelo, ropa, pelaje. Los que digan");
console.log("  \"???\" hay que mirarlos en la imagen de zonas. Las zonas que NO quieras");
console.log("  recolorear (el blanco de una blusa, el crema de la panza de un perro)");
console.log("  simplemente no las pongas: lo que no esta en la paleta se deja tal cual.");

// --- escribir -------------------------------------------------------------
if (bandera("escribir")) {
  const destino = path.join(raiz, carpeta);
  marcos.forEach((im, i) => {
    M.escribirPng(im.buf, im.w, im.h,
      path.join(destino, anim + "_" + String(i + 1).padStart(2, "0") + ".png"));
  });
  console.log("");
  console.log("  escritos " + marcos.length + " cuadros en " + carpeta);
} else {
  console.log("");
  console.log("  (solo medicion; agrega --escribir para guardar los cuadros)");
}

// --- imagenes de revision -------------------------------------------------
require("./revisar.js")({ pack, marcos, zs, escala, ox, oy, nu, ref, tol,
  revision: path.join(__dirname, "revision") });
console.log("  imagenes de revision en herramientas/revision/ — MIRALAS antes de dar");
console.log("  el set por bueno.");
console.log("");
