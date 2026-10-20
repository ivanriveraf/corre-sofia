class_name Arte
extends RefCounted

## Unico lugar del juego que sabe de donde salen los sprites.
##
## Para agregar o cambiar una animacion:
##   1. Deja los cuadros en arte/<carpeta>/<animacion>_NN.png (NN desde 01)
##   2. MIDELOS (ver abajo) y agrega su entrada en FUENTES — incluido "avance",
##      que es cuanto suelo pasa por cada cuadro; NO son cuadros por segundo
##   3. Agrega su paleta en paleta.gd
##   4. Corre test.gd
##
## ------------------------------------------------------------------------
## CADA ANIMACION LLEVA LO SUYO, Y NO ES CAPRICHO
##
## Escala, anclaje y PALETA van por animacion, no por personaje. Las tiras se
## generan una por una y cada una sale distinta, aunque sea el mismo dibujo:
##
##   - Escala: el salto vino dibujado mas chico. Cuanto, costo medirlo, porque
##     casi ningun rasgo sobrevive al cambio de pose: el ancho de la cabeza
##     depende de cuanto pelo vuele, la cara la tapa el pelo, la blusa la tapan
##     los brazos, los pies se recogen. Cada medida dio un numero distinto
##     (0.587, 0.605, 0.693, 0.747).
##     La que sirvio fue el TORSO — del alto del pelo a la cintura — medido
##     sobre el video ya renderizado (torso_video.js): 95.3 px corriendo contra
##     90.0 saltando, o sea la carrera es 5.9% mas grande, y 0.611/1.059 =
##     0.641. Medir sobre el render y no sobre el PNG es lo que lo destrabo:
##     es lo que el jugador ve, y se puede volver a medir despues de cambiarlo.
##
##   - Anclaje: por la CADERA — el borde de arriba de la falda. Los pies no
##     sirven, porque en el salto se recogen. La cabeza tampoco: fijandola, los
##     pies pegaban un salto de 79 px en el despegue. Con la cadera alineada la
##     cabeza baja 17 px y los pies suben 62, que es justo lo que hace alguien
##     al saltar.
##
##   - Paleta: la falda salio #5991cc corriendo y #87b4d5 saltando — 61 de
##     distancia, tres veces la tolerancia. Con una paleta unica, la falda del
##     salto se quedaria sin recolorear entera.
##     (Como las dos apuntan al color del config, el recoloreo ademas corrige
##     esa deriva: al final las dos quedan del mismo color.)
##
## Los numeros salen de medir el alfa de los PNG, no de mirarlos:
##   node cortar_tira.js <raw> <ancho> <alto> [--anclaje-arriba] --escribir <dir> <pre>
##   node anclar.js / calzar_cara.js / medir_cadera.js / extraer_paleta.js
## ------------------------------------------------------------------------

const FUENTES := {
	"ninaSuelto": {
		"carpeta": "res://arte/nina-suelto",
		"animaciones": {
			"run": {
				"pack": "ninaSueltoRun",
				"cuadros": 6,
				# Suelo que pasa por cada cuadro. MEDIDO siguiendo el pie
				# apoyado (pie_apoyado.js): retrocede 35, 52, 43 y 46 px entre
				# cuadros, promedio 44.
				"avance": 44.0,
				"escala": 0.611,            # 547 px de dibujo -> 334 px en pantalla
				"origen": Vector2(4.5, -273.0),
				"dibujo": Vector2(402.0, 547.0),
				# Ancho = NUCLEO (tronco y cara), no el cuerpo entero: el pie
				# delantero de la zancada llega a +119 y perder porque la punta
				# del zapato rozo el obstaculo se siente injusto. Ver cuerpo().
				"cuerpo": Rect2(-5.0, -270.0, 80.0, 267.0),
			},
			"jump": {
				"pack": "ninaSueltoJump",
				"cuadros": 4,
				# avance 0: el cuadro NO lo elige la animacion sino la velocidad
				# vertical del salto. Ver _animar_salto en main.gd.
				"avance": 0.0,
				"escala": 0.641,            # torso medido contra la carrera
				"origen": Vector2(8.7, -259.0),
				"dibujo": Vector2(308.0, 428.0),
				# El fondo (-52) es el PROMEDIO de los pies de los cuatro cuadros
				# (-59, -82, -36, -31), no el mas bajo: con las piernas recogidas
				# el cuerpo de verdad esta mas arriba, y quedarse con el cuadro
				# menos recogido es lo que hacia perder sin tocar nada.
				"cuerpo": Rect2(-21.0, -258.0, 80.0, 206.0),
			},
		},
	},
	"perro": {
		"carpeta": "res://arte/perro",
		"animaciones": {
			"run": {
				"pack": "perroRun",
				"cuadros": 6,
				# Este no salio de seguir la pata, como el de la niña: en un galope
				# cada pata apoya uno o dos cuadros de seis, muy poco para seguir
				# una sola, y el rastreo salta entre delanteras y traseras dando
				# valores que no se sostienen (28, 88, 97 px).
				# Sale de la zancada: 42 * 6 cuadros = 252 px por ciclo, que es
				# 2.4 veces su altura de lomo (106 px). Un perro chico galopando
				# hace entre 2 y 3 veces, asi que cae donde debe. Y el minimo esta
				# comprobado: la separacion maxima entre patas es 153 px, y la
				# zancada tiene que ser mayor porque incluye el vuelo.
				"avance": 42.0,
				"escala": 0.520,            # 271 px de dibujo -> 141 px en pantalla
				"origen": Vector2(-11.5, -135.0),
				"dibujo": Vector2(398.0, 271.0),
				# La mascota no choca con nada, pero se declara igual: si algun
				# dia lo hace, el numero ya esta medido y no se inventa.
				"cuerpo": Rect2(-82.0, -108.0, 154.0, 105.0),
			},
		},
	},
}


## ---------------------------------------------------------------------------
## EL CATALOGO: que juego de sprites le toca a cada pedido
##
## Se elige por el genero del niño y su peinado, y la mascota por su tipo. NADA
## de esto se genera al momento del pedido, y es a proposito: cada tira nueva
## sale con otros colores, otro tamaño y otro anclaje, y hay que MEDIRLA entera
## antes de que sirva (ver los comentarios de escala y paleta mas arriba). Eso
## es media hora larga de trabajo con criterio; por pedido no sale la cuenta, y
## saltarselo manda al cumpleaños de un niño los fallos que ya conocemos: la
## falda a medio pintar, el personaje cambiando de tamaño al saltar, perder sin
## tocar el obstaculo.
##
## Asi que el catalogo se construye UNA VEZ, medido y verificado, y el pedido
## solo elige de aqui. Lo unico que cambia por cliente son los colores, que si
## son gratis (los pone el shader).
##
## Para agregar un set:
##   node herramientas/agregar_personaje.js <tira.png> ... (mide y escribe todo)
##   luego su entrada en FUENTES, su paleta en paleta.gd, y su fila aqui.
##
## REGLA DE NEGOCIO: el formulario del cliente solo debe ofrecer lo que este
## aqui. Si ofrece "trenzas" y no hay set de trenzas, prometiste algo que no
## puedes entregar.
##
## (arte/nino y arte/mascota son los packs de pzUH y FlatBoy, con licencia aun
## sin confirmar. No estan en el catalogo y no deben usarse hasta que llegue el
## permiso.)
const CATALOGO := {
	"f": {"suelto": "ninaSuelto"},
}

const MASCOTAS := {
	"perro": "perro",
	"perra": "perro",
}


## El set del niño para este pedido.
##
## Si la combinacion no esta, NO revienta: devuelve lo que haya y avisa. Un
## pedido pagado tiene que abrirse igual — mejor un peinado que no es que una
## pantalla negra el dia del cumpleaños. Pero `faltantes()` lo denuncia y
## test.gd falla, asi el problema sale en el taller y no en la fiesta.
static func set_jugador(cfg: Dictionary) -> String:
	var genero := str(cfg.get("genero", ""))
	var peinado := str((cfg.get("personaje", {}) as Dictionary).get("peinado", ""))
	if CATALOGO.has(genero) and (CATALOGO[genero] as Dictionary).has(peinado):
		return CATALOGO[genero][peinado]
	var respaldo := _cualquier_set()
	push_warning("Catalogo: no hay sprites para genero '%s' con peinado '%s'. Se usa '%s'."
		% [genero, peinado, respaldo])
	return respaldo


static func set_mascota(cfg: Dictionary) -> String:
	var tipo := str((cfg.get("mascota", {}) as Dictionary).get("tipo", ""))
	if MASCOTAS.has(tipo):
		return MASCOTAS[tipo]
	push_warning("Catalogo: no hay sprites de mascota '%s'. Se usa 'perro'." % tipo)
	return "perro"


static func _cualquier_set() -> String:
	for g: String in CATALOGO:
		for pe: String in CATALOGO[g]:
			return CATALOGO[g][pe]
	return FUENTES.keys()[0]


## Lo que le falta al catalogo para cumplir este pedido. Vacio = se puede.
## Lo usa test.gd para que un pedido imposible no llegue a entregarse.
static func faltantes(cfg: Dictionary) -> Array[String]:
	var falta: Array[String] = []
	var genero := str(cfg.get("genero", ""))
	var peinado := str((cfg.get("personaje", {}) as Dictionary).get("peinado", ""))
	if not (CATALOGO.has(genero) and (CATALOGO[genero] as Dictionary).has(peinado)):
		falta.append("personaje de genero '%s' con peinado '%s'" % [genero, peinado])
	var tipo := str((cfg.get("mascota", {}) as Dictionary).get("tipo", ""))
	if not MASCOTAS.has(tipo):
		falta.append("mascota '%s'" % tipo)
	return falta


## Carga los cuadros de una animacion. Devuelve [] si falta algo, sin reventar:
## un pedido con un sprite faltante tiene que abrirse igual.
static func cuadros(carpeta: String, animacion: String, n: int) -> Array[Texture2D]:
	var salida: Array[Texture2D] = []
	for i in range(1, n + 1):
		var ruta := "%s/%s_%02d.png" % [carpeta, animacion, i]
		if not ResourceLoader.exists(ruta):
			push_warning("Arte: falta %s" % ruta)
			continue
		salida.append(load(ruta))
	return salida


## Arma un sprite con TODAS las animaciones declaradas para ese personaje, cada
## una con su escala, su anclaje y su recoloreo. Arranca en la primera.
static func crear(quien: String, personaje: Dictionary) -> SpriteAnimado:
	var s := SpriteAnimado.new()
	if not FUENTES.has(quien):
		push_error("Arte: no existe '%s'" % quien)
		return s

	var f: Dictionary = FUENTES[quien]
	for nombre: String in f["animaciones"]:
		var a: Dictionary = f["animaciones"][nombre]
		s.animaciones[nombre] = {
			"texturas": cuadros(f["carpeta"], nombre, int(a["cuadros"])),
			"avance": float(a["avance"]),
			"escala": float(a["escala"]),
			"origen": a["origen"],
			"dibujo": a["dibujo"],
			"cuerpo": a["cuerpo"],
			"material": Paleta.material(a["pack"], personaje),
		}
	s.usar(f["animaciones"].keys()[0])
	return s


## Sprite2D que sabe cambiar de animacion sin que el personaje salte ni cambie
## de tamaño, porque cada animacion trae su propia escala y anclaje.
class SpriteAnimado extends Sprite2D:
	var animaciones := {}
	## Suelo recorrido, en pixeles de pantalla. La animacion avanza con ESTO y
	## no con el reloj.
	##
	## Es la diferencia entre que se vea bien y que se vea acelerada: el pie
	## apoyado tiene que quedarse pegado al suelo, y el suelo se mueve a la
	## velocidad del juego, que cambia todo el rato. Con cuadros por segundo
	## fijos hay que ir corrigiendolos a mano cada vez que cambia la velocidad —
	## antes habia un multiplicador para eso — y con la distancia no hay nada que
	## corregir: a cualquier velocidad, el pie no patina.
	var _recorrido := 0.0
	## Cuadro forzado. Con -1 la animacion corre sola por reloj; con un indice
	## se queda en ese cuadro. Lo usa el salto, que se sincroniza con la fisica
	## y no con un temporizador.
	var cuadro_fijo := -1

	var _actual := ""

	func usar(nombre: String) -> void:
		if _actual == nombre or not animaciones.has(nombre):
			return
		_actual = nombre
		_recorrido = 0.0
		var a: Dictionary = animaciones[nombre]
		scale = Vector2.ONE * float(a["escala"])
		offset = a["origen"]
		material = a["material"]
		_pintar()

	## El juego le pasa cuanto suelo paso en este fotograma.
	func avanzar(distancia: float) -> void:
		_recorrido += distancia
		_pintar()

	func _pintar() -> void:
		if not animaciones.has(_actual):
			return
		var a: Dictionary = animaciones[_actual]
		var texturas: Array = a["texturas"]
		if texturas.is_empty():
			return
		var avance: float = a["avance"]
		if cuadro_fijo >= 0 or avance <= 0.0:
			texture = texturas[clampi(maxi(cuadro_fijo, 0), 0, texturas.size() - 1)]
		else:
			texture = texturas[int(_recorrido / avance) % texturas.size()]

	## Caja del CUERPO de la animacion en curso, relativa a la posicion del nodo
	## y en pixeles de pantalla. De aqui sale la colision.
	##
	## Antes salia del tamaño del dibujo, y estaba mal por dos motivos: el ancho
	## lo mandaba el PELO al vuelo (402 px de dibujo contra 172 de cuerpo), y el
	## fondo se pegaba al nodo. Eso ultimo era el error grave: en el salto la niña
	## recoge las piernas y sus pies quedan hasta 82 px MAS ARRIBA del nodo, o sea
	## que la caja le colgaba por debajo de los pies y enganchaba el obstaculo que
	## en pantalla ya habia librado.
	##
	## Y el ancho no es el del cuerpo entero sino el del NUCLEO: solo las columnas
	## que tienen cuerpo en al menos el 30% del alto. Un brazo o una pierna
	## estirados ocupan pocas filas y quedan fuera; el tronco queda dentro. Son 80
	## px en vez de 172, y es la diferencia entre morir porque te alcanzo el
	## obstaculo y morir porque tu zapato lo rozo de pasada — que es lo que un
	## niño de 6 años lee como injusto.
	##
	## Va por animacion, medida cuadro a cuadro sobre el alfa (nucleo.js /
	## cuerpo_caja.js), descontando el pelo.
	func cuerpo() -> Rect2:
		if not animaciones.has(_actual):
			return Rect2()
		return animaciones[_actual]["cuerpo"]

	## Cuantos cuadros tiene una animacion. Lo pregunta main.gd para repartir el
	## salto entre ellos sin tener el numero escrito en dos lugares.
	func n_cuadros(animacion: String) -> int:
		if not animaciones.has(animacion):
			return 0
		return (animaciones[animacion]["texturas"] as Array).size()
