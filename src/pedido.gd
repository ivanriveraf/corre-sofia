extends Node

## Autoload. Carga el pedido del cliente y lo deja disponible para todo el juego.
##
## Lo unico que cambia entre un cliente y otro es config.json. Ni una linea de
## codigo. Si para personalizar un pedido tienes que tocar un .gd, algo se
## diseño mal.

const RUTA := "res://config.json"

## Campos sin los cuales el pedido sale raro. No aborta: solo avisa.
const REQUERIDOS: Array[String] = [
	"nombre", "genero", "edad", "lugar", "coleccionable", "personaje"
]

var cfg: Dictionary = {}
var cargado := false


func _ready() -> void:
	cargar()


func cargar() -> void:
	if not FileAccess.file_exists(RUTA):
		push_error("No existe %s — cada pedido necesita el suyo." % RUTA)
		cfg = _por_defecto()
		return

	var texto := FileAccess.get_file_as_string(RUTA)
	var leido: Variant = JSON.parse_string(texto)
	if typeof(leido) != TYPE_DICTIONARY:
		push_error("%s no es un JSON valido." % RUTA)
		cfg = _por_defecto()
		return

	cfg = leido
	cargado = true
	_avisar_faltantes()


## No aborta el juego: avisa por consola y sigue. Un pedido con un campo vacio
## tiene que poder abrirse igual — mejor un texto raro que una pantalla negra
## el dia del cumpleanos.
func _avisar_faltantes() -> void:
	for clave: String in REQUERIDOS:
		if not cfg.has(clave) or str(cfg[clave]).is_empty():
			push_warning("config.json: falta '%s'" % clave)
	if not ["m", "f", "n"].has(cfg.get("genero", "")):
		push_warning("config.json: 'genero' debe ser m, f o n — se usara neutro")


func _por_defecto() -> Dictionary:
	return {
		"nombre": "Amig[o|a|e]", "genero": "n", "edad": 6,
		"lugar": "la plaza",
		"mascota": {"nombre": "Kiwi", "tipo": "perro", "genero": "n"},
		"coleccionable": {"singular": "estrella", "plural": "estrellas"},
		"colores": {"primario": "#4A90D9", "secundario": "#FFD166", "fondo": "#1B2A3A"},
		"personaje": {},
		"mensajeFinal": {"texto": "", "firma": "tu familia"},
	}


# ------------------------------------------------------------------ atajos

## Resuelve un texto con el genero y las variables de este pedido.
func texto(plantilla: String, datos: Dictionary = {}) -> String:
	if datos.is_empty():
		return Genero.t(plantilla, cfg)
	return Genero.con_datos(plantilla, cfg, datos)


func color(clave: String, respaldo: String) -> Color:
	var colores: Dictionary = cfg.get("colores", {})
	return Color(colores.get(clave, respaldo))


func personaje() -> Dictionary:
	return cfg.get("personaje", {})


func nombre() -> String:
	return cfg.get("nombre", "")
