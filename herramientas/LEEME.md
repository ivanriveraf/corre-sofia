# Agregar un personaje al catálogo

El catálogo se construye **una vez**, no por pedido. La razón está en
`src/arte.gd`, pero en corto: cada tira generada sale con otros colores, otro
tamaño y otro anclaje, y hay que medirla entera antes de que sirva. Por pedido
no sale la cuenta, y saltárselo manda al cumpleaños de un niño real la falda a
medio pintar o una partida perdida sin haber tocado nada.

Lo que **sí** es gratis por pedido son los colores: piel, pelo y ropa los pone
el shader a partir de `config.json`, sin arte nuevo.

## El flujo

### 1. Generar la tira

Un PNG **con transparencia** (no JPG), con los cuadros en fila y hueco entre
ellos. Para la carrera, 6 cuadros; para el salto, 4.

Lo que importa del prompt: fondo transparente, misma cámara y mismo tamaño en
todos los cuadros, y **las piernas alternando de verdad** — si el generador
devuelve seis veces la misma pose con variaciones, se ve como si saltara en el
sitio, no como si corriera.

### 2. Medir

```bash
node herramientas/agregar_personaje.js tira.png --set ninoCorto --anim run \
     --referencia arte/nina-suelto/run:6:0.611
```

La referencia es con quién calzar el tamaño: pasa siempre la carrera de un
personaje que ya esté en el catálogo, para que todos midan lo mismo en pantalla.

Para un salto, añade `--anclaje cabeza` y pasa como referencia **la carrera del
mismo personaje**: en el aire los pies no sirven de ancla porque se recogen.

Sin `--escribir` solo mide y no toca nada. Corre primero sin él.

### 3. Mirar las tres imágenes

Están en `herramientas/revision/`. Esto **no es opcional**: hubo decisiones que
ningún número resolvió, y equivocarse en ellas solo se ve en pantalla.

| imagen | qué comprobar |
|---|---|
| `-zonas.png` | Que cada color chillón sea la zona que crees. En una tira, el pelo hondo y la línea del dibujo eran literalmente el mismo color; recolorear esa zona le borra el contorno a toda la figura. Lo gris no se recolorea. |
| `-tamano.png` | Que los dos se vean del mismo tamaño. Las medidas anatómicas se contradicen entre sí (ancho de cabeza, cara, ojo y torso dieron cuatro escalas distintas); la que vale es verlo puesto al lado. Si no calza, repite con `--escala`. |
| `-caja.png` | Que la caja azul abrace el **tronco**. Que el pelo, el puño y el pie estirados queden fuera es lo correcto: perder porque la punta del zapato rozó el obstáculo se siente injusto. |

La herramienta acierta el anclaje con unos 15 px de margen. Eso es poco, pero se
nota al despegar, así que la imagen de tamaño es la que cierra el ajuste.

### 4. Escribir y pegar

```bash
node herramientas/agregar_personaje.js tira.png --set ninoCorto --anim run \
     --referencia arte/nina-suelto/run:6:0.611 --escribir
```

Escribe los cuadros en `arte/nino-corto/` e imprime dos bloques listos:

- uno para `FUENTES` en `src/arte.gd`
- otro para `PALETAS` en `src/paleta.gd` — **ponle nombre a cada zona**
  (`piel`, `pelo`, `ropa`). Las zonas que no quieras recolorear simplemente no
  las pongas: lo que no está en la paleta se deja tal cual.

### 5. Darlo de alta en el catálogo

En `Arte.CATALOGO`, dentro de `src/arte.gd`:

```gdscript
const CATALOGO := {
	"f": {"suelto": "ninaSuelto"},
	"m": {"corto": "ninoCorto"},     <- la fila nueva
}
```

### 6. Correr las pruebas

```bash
godot --headless --path . --script test.gd
```

Comprueban que estén todos los cuadros, que cada animación traiga su propia
paleta, que la caja de colisión salga del tronco y no del lienzo, que no cuelgue
bajo el suelo, y que el pedido de `config.json` se pueda cumplir con el catálogo.

Y luego míralo corriendo, que es la prueba que de verdad manda:

```bash
godot --path . -- --demo --cajas
```

## Regla de negocio

**El formulario del cliente solo debe ofrecer lo que esté en `CATALOGO`.** Si
ofrece "trenzas" y no hay set de trenzas, prometiste algo que no puedes
entregar. La prueba `[11]` falla cuando un pedido pide algo que no existe — para
que el problema salga en el taller y no en la fiesta.

## Nota sobre licencias

`arte/nino/` y `arte/mascota/` son los packs de pzUH y FlatBoy, con licencia sin
confirmar. **No están en el catálogo y no deben usarse** hasta que llegue el
permiso. Ver `LICENCIAS.md` en el proyecto de juegos-cumple.
