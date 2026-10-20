class_name Paleta
extends RefCounted

## Puente entre el `personaje` del config y el shader de recoloreo.
## Puerto de juegos-cumple/src/sprites.js.
##
## LAS PALETAS SON POR PACK, Y NO ES UN DETALLE: #ff6666 es el gorro en FlatBoy
## y el pelo en CuteGirl. Compartir una paleta le pinta el pelo del color del
## gorro a la niña.
##
## Si algun dia hay que cambiar de pack de sprites — por ejemplo si no llega el
## permiso de pzUH y se generan sprites propios — esto es lo unico que se toca,
## mas las rutas en arte.gd. El resto del juego no se entera.

const PALETAS := {
	"FlatBoy": {
		"piel": {"base": "fece90", "tonos": ["fece90", "feb660", "fec178"]},
		"pelo": {"base": "756861", "tonos": ["756861"]},
		"ropa": {"base": "69d2e7", "tonos": ["69d2e7", "33c2df"]},
		"gorro": {"base": "ff6666", "tonos": ["ff6666"]},
	},
	"CuteGirlFiles": {
		"piel": {"base": "fece90", "tonos": ["fece90", "feb660"]},
		"pelo": {"base": "ff6666", "tonos": ["ff6666", "ff4747"]},
		"ropa": {"base": "669999", "tonos": ["669999", "58847e"]},
	},
	"perro": {
		"pelaje": {"base": "eea03e", "tonos": ["eea03e", "eb8f1f", "ffb413"]},
	},

	# --- Arte propio (ChatGPT) --------------------------------------------
	# Extraidas con extraer_paleta.js sobre los PNG reales, no a ojo.
	#
	# DOS COSAS QUE COSTARON CARO:
	#
	# 1. Un solo tono por zona no alcanza. La falda tenia SEIS: los tonos de
	#    sombra de los pliegues estan a distancia 130 del tono base, o sea que
	#    ninguna tolerancia razonable los alcanza. Se quedaban azules mientras
	#    el resto se volvia rosado, y mezclados la falda se veia violeta.
	#
	# 2. Cada set de sprites necesita su PROPIA medicion, aunque sea el mismo
	#    personaje. Al regenerar la tira los colores se movieron dos veces:
	#    #7ba8d9 -> #6ca1d9 -> #5991cc. El ultimo salto fue de 28, fuera de
	#    tolerancia: media falda habria quedado sin recolorear.
	#
	# De los grupos automaticos hay que sacar a mano los negros del contorno.
	# El contorno NO se recolorea nunca, o el dibujo pierde su linea y deja de
	# leerse como dibujo plano.
	#
	# Por eso hay "ninaSueltoRun" y "ninaSueltoJump" y no un solo "ninaSuelto":
	# el pack es por ANIMACION, no por personaje. Ver el comentario largo sobre
	# ninaSueltoJump.
	#
	# El nombre lleva el del set del catalogo (ninaSuelto) porque cada set nuevo
	# trae sus propios packs: ninoCortoRun, ninaTrenzasRun, y asi.
	"ninaSueltoRun": {
		# Sin "3f211a": se veia como una sombra de piel muy oscura, pero pintando
		# donde caia (ubicar.js) resulto ser EL IRIS. En la lista, el color de
		# ojos del niño terminaba siguiendo a su color de piel, y ademas no
		# coincidia con el salto, cuya paleta no lo incluye. El ojo se deja como
		# esta dibujado.
		"piel": {
			"base": "ffbf95",
			"tonos": [
				"ffbf95", "ffc69e", "f3b998", "f2b48f", "fbad88", "f0bfa3",
				"f2a785", "e8ac8b", "e39979", "e1956e",
			],
		},
		"pelo": {
			# Sin "090707": esta a distancia 11 del contorno (#010000) y se lo
			# llevaria puesto, tiñendo la linea de TODA la figura. "110e0e" si
			# entra: esta a 25, con margen sobre la tolerancia de 19.
			"base": "171414",
			"tonos": ["171414", "1e1b1b", "110e0e"],
		},
		"ropa": {
			"base": "5991cc",
			"tonos": ["5991cc", "6395d0", "628dbf", "43668b", "51719a", "4a6b94"],
		},
	},

	# La MISMA niña saltando, y aun asi otra paleta: la tira del salto se genero
	# aparte y salio con otros colores. La falda paso de #5991cc a #87b4d5 —
	# distancia 61, tres veces la tolerancia. Con una sola paleta, la falda del
	# salto se quedaria sin recolorear entera.
	#
	# No es un defecto de esta tira en particular: cada generacion se corre. Ya
	# van tres (#7ba8d9 -> #6ca1d9 -> #5991cc -> #87b4d5). La regla es medir cada
	# tira nueva, nunca reusar la paleta de otra.
	#
	# El recoloreo ademas TAPA esa deriva: las dos apuntan al color del config,
	# asi que en pantalla la falda queda igual corriendo que saltando.
	#
	# Los tonos salen de cubrir.js: se elige el mas frecuente, se tachan los
	# pixeles que alcanza a la tolerancia real del shader, y se repite. Asi cada
	# tono listado gana su ranura en vez de repetir a otro (las 12 medidas de piel
	# se cubren con 6, y las ranuras son solo 24).
	"ninaSueltoJump": {
		"piel": {
			"base": "f6c8ae",
			"tonos": ["f6c8ae", "e5a58c", "eab39f", "f3d3c4", "d1a9a1", "d99c80"],
		},
		# Aca NO va "1b1927", aunque sea el 11% de los pixeles oscuros. En esta
		# tira la sombra honda del pelo y el contorno son el MISMO color: incluirlo
		# recoloreaba el 47% del contorno, y ni bajando la tolerancia a 8 se
		# separaban. Dejarlo fuera no cuesta nada — se comprobo pintando los
		# pixeles alcanzados: cubren todo el pelo, y lo que queda sin pintar es
		# justo la linea del dibujo, que es donde tiene que quedarse oscura.
		"pelo": {
			"base": "27272f",
			"tonos": ["27272f", "555861", "323844"],
		},
		"ropa": {
			"base": "87b4d5",
			"tonos": ["87b4d5", "6c9abb", "3a637f", "7fa8c8", "4d6a88", "99bbd6"],
		},
	},
	# Ciclo de galope de 6 cuadros. Solo se recolorea el pelaje marron: el crema
	# de la panza y las patas se deja, porque es lo que hace que se lea como
	# perro y no como mancha de un color.
	#
	# Se sacaron a mano los casi-negros del contorno (#291111, #321817, #250c05):
	# el extractor los mete entre los marrones porque el contorno tiene un tinte
	# calido y el tono de un color tan oscuro no es fiable.
	"perroRun": {
		"pelaje": {
			"base": "b9723e",
			"tonos": [
				"b9723e", "bf7945", "b37546", "b06e3c", "a8683a", "a86f44",
				"a06640", "985c38", "956041", "9b6549", "ad764f", "b57b55",
				"ad7c5c", "b8835b", "a57658", "a16e4f", "b88766", "986c53",
				"91644d", "855c4a", "412521",
			],
		},
	},
	"gato": {
		"pelaje": {"base": "838383", "tonos": ["838383", "666666", "999999", "333333", "cccccc"]},
	},
}

## Tolerancia del shader por pack, cuando la de fabrica (0.11) no sirve.
##
## Las dos tiras de la niña la bajan por la misma razon: el pelo negro y el
## contorno negro se parecen demasiado, y con la tolerancia normal (28) el
## recoloreo se come la linea de TODA la figura — no solo la del pelo — y el
## dibujo deja de leerse como dibujo plano.
##
##   carrera: pelo #110e0e a distancia 25 del contorno (#010000)
##   salto:   pelo #27272f a distancia 29 del contorno (#0d0c19)
##
## Con 0.075 (19) las dos quedan con margen. Se comprobo contando pixeles, no a
## ojo (colision_contorno.js): recolorean el 3% del contorno, y ese 3% son los
## pixeles de transicion entre el pelo y su propia linea.
const TOLERANCIAS := {
	"ninaSueltoRun": 0.075,
	"ninaSueltoJump": 0.075,
}
const TOLERANCIA_NORMAL := 0.11

## Que campo del config manda sobre que ranura.
const DESDE_CONFIG := {
	"piel": "piel",
	"pelo": "pelo",
	"ropa": "ropaColor",
	"gorro": "accesorioColor",
	"pelaje": "pelajeColor",
}

const PESO_LUZ := Vector3(0.299, 0.587, 0.114)
const MAX_RANURAS := 24


static func _color(hex: String) -> Color:
	return Color(hex if hex.begins_with("#") else "#" + hex)


## Devuelve un ShaderMaterial listo, o null si este pedido no pide ningun
## cambio de color para ese pack (entonces el sprite va tal cual).
static func material(pack: String, personaje: Dictionary) -> ShaderMaterial:
	if not PALETAS.has(pack):
		push_warning("Paleta: no hay definicion para el pack '%s'" % pack)
		return null

	var origenes: Array[Color] = []
	var destinos: Array[Color] = []
	var bases: Array[Color] = []

	for ranura: String in PALETAS[pack]:
		var campo: String = DESDE_CONFIG.get(ranura, "")
		var destino: String = str(personaje.get(campo, ""))
		if destino.is_empty():
			continue  # ranura sin color en el config: se deja el original

		var def: Dictionary = PALETAS[pack][ranura]
		var c_base := _color(def["base"])
		var c_destino := _color(destino)

		for tono: String in def["tonos"]:
			if origenes.size() >= MAX_RANURAS:
				push_warning("Paleta: '%s' tiene mas de %d tonos, se recortan" % [pack, MAX_RANURAS])
				break
			origenes.append(_color(tono))
			destinos.append(c_destino)
			bases.append(c_base)

	if origenes.is_empty():
		return null

	var mat := ShaderMaterial.new()
	mat.shader = load("res://arte/paleta.gdshader")
	mat.set_shader_parameter("paleta", _textura(origenes, destinos, bases))
	mat.set_shader_parameter("cantidad", origenes.size())
	mat.set_shader_parameter("tolerancia", TOLERANCIAS.get(pack, TOLERANCIA_NORMAL))
	return mat


## Empaqueta la paleta en una textura de 3 filas: origen, destino y color base.
##
## Va como textura y no como `uniform vec3[]` porque los arreglos de uniforms
## llegan CORRUPTOS al renderizador GL Compatibility de Godot 4.6 — ver el
## comentario largo en paleta.gdshader. Una textura chica viaja bien siempre.
static func _textura(origenes: Array[Color], destinos: Array[Color],
		bases: Array[Color]) -> ImageTexture:
	# Tamaño POTENCIA DE DOS a proposito. Una textura de 11x3 la redimensiona el
	# renderizador GL Compatibility e interpola los texeles, y entonces el shader
	# lee colores mezclados en vez de los exactos. Con un ancho potencia de dos y
	# filtro nearest, lo que se escribe es lo que se lee.
	var img := Image.create(MAX_RANURAS, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	for i in origenes.size():
		img.set_pixel(i, 0, origenes[i])
		img.set_pixel(i, 1, destinos[i])
		img.set_pixel(i, 2, bases[i])
	return ImageTexture.create_from_image(img)


## Cuantos tonos se recolorean con este pedido. Solo lo usa test.gd.
static func _cuantas(pack: String, personaje: Dictionary) -> int:
	var n := 0
	for ranura: String in PALETAS[pack]:
		var campo: String = DESDE_CONFIG.get(ranura, "")
		if str(personaje.get(campo, "")).is_empty():
			continue
		n += PALETAS[pack][ranura]["tonos"].size()
	return mini(n, MAX_RANURAS)
