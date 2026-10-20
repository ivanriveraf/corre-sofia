class_name Sonido
extends Node

## Los efectos del juego.
##
## Los WAV no se bajaron de ningun sitio: los sintetiza
## herramientas/generar_sonidos.js. En este proyecto ya se perdio tiempo con
## packs de arte de licencia dudosa que acabaron sin poder usarse, y un efecto
## hecho en casa no tiene ese problema — es nuestro y se puede publicar.
##
## Reproduce con VARIAS VOCES y no con un reproductor unico: juntar un
## coleccionable mientras suena el salto es lo normal, y con una sola voz el
## segundo sonido corta al primero de golpe, que se oye como un fallo.

const EFECTOS := {
	"salto": "res://audio/salto.wav",
	"recoger": "res://audio/recoger.wav",
	"choque": "res://audio/choque.wav",
	"ganar": "res://audio/ganar.wav",
	"perder": "res://audio/perder.wav",
	"empezar": "res://audio/empezar.wav",
}

const VOCES := 6

var _streams := {}
var _voces: Array[AudioStreamPlayer] = []
var _siguiente := 0


func _ready() -> void:
	for clave: String in EFECTOS:
		var ruta: String = EFECTOS[clave]
		if not ResourceLoader.exists(ruta):
			# Sin reventar: un pedido con un archivo de audio faltante tiene que
			# abrirse igual. Mejor un juego mudo que una pantalla negra.
			push_warning("Sonido: falta %s" % ruta)
			continue
		_streams[clave] = load(ruta)

	for i in VOCES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voces.append(p)


## Toca un efecto. `tono` multiplica la frecuencia: 1.0 es el original.
func tocar(nombre: String, tono := 1.0, volumen_db := 0.0) -> void:
	if not _streams.has(nombre) or _voces.is_empty():
		return
	# Voces por turno circular. Si todas estan ocupadas se pisa la mas antigua,
	# que es justo la que menos se echa de menos.
	var p := _voces[_siguiente]
	_siguiente = (_siguiente + 1) % _voces.size()
	p.stream = _streams[nombre]
	p.pitch_scale = clampf(tono, 0.5, 2.0)
	p.volume_db = volumen_db
	p.play()
