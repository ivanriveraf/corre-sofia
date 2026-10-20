class_name Genero
extends RefCounted

## Motor de texto con genero — puerto a GDScript de juegos-cumple/src/genero.js
##
## Tiene que dar EXACTAMENTE los mismos resultados que la version JavaScript.
## El probador del navegador y el juego leen los mismos textos: si los dos
## motores no coinciden, revisas un pedido y entregas otro. test.gd corre los
## mismos casos que test.js justamente para vigilar eso.
##
## SINTAXIS
##   [a|b|c]     genero del cumpleanero  (m | f | n, en ese orden)
##   [m:a|b|c]   genero de la mascota    (el prefijo "m:" es lo que las separa)
##   {variable}  valor del config
##
## REGLA DE ORO: escribe siempre las 3 variantes.

const ORDEN := {"m": 0, "f": 1, "n": 2}

## Variables que el juego rellena mientras se juega, no el config del cliente.
const RUNTIME := ["puntos", "nivel", "tiempo", "cliente", "sabor", "jugador", "ganador"]

static var _re_mascota: RegEx
static var _re_nino: RegEx
static var _re_var: RegEx


static func _compilar() -> void:
	if _re_mascota != null:
		return
	_re_mascota = RegEx.new()
	_re_mascota.compile("\\[m:([^\\]]*)\\]")
	_re_nino = RegEx.new()
	_re_nino.compile("\\[([^\\]]*)\\]")
	_re_var = RegEx.new()
	_re_var.compile("\\{(\\w+)\\}")


## JSON entrega TODOS los numeros como float. Sin esto, {edad} sale "6.0 años"
## en el juego que recibe el cliente. La version JavaScript no tiene el problema
## porque JSON.parse respeta los enteros; aca hay que arreglarlo a mano.
static func _a_texto(v: Variant) -> String:
	if v is float and is_equal_approx(v, roundf(v)):
		return str(int(v))
	return str(v)


## GDScript no acepta callbacks en RegEx.sub(), asi que se recorre a mano.
static func _reemplazar(texto: String, re: RegEx, resolver: Callable) -> String:
	var salida := ""
	var pos := 0
	for m in re.search_all(texto):
		salida += texto.substr(pos, m.get_start() - pos)
		salida += str(resolver.call(m))
		pos = m.get_end()
	salida += texto.substr(pos)
	return salida


## Si faltan variantes, cae a la ultima disponible: nunca revienta en produccion.
static func _elegir(opciones: String, idx: int) -> String:
	var partes := opciones.split("|")
	if idx < partes.size():
		return partes[idx]
	return partes[partes.size() - 1] if partes.size() > 0 else ""


## Resuelve un texto con tokens usando el config del cliente.
static func t(texto: String, cfg: Dictionary) -> String:
	_compilar()

	var g_nino: int = ORDEN.get(cfg.get("genero", ""), 2)
	var mascota: Dictionary = cfg.get("mascota", {})
	var g_masc: int = ORDEN.get(mascota.get("genero", ""), 2)
	var vars := variables(cfg)

	# El orden importa: mascota primero, porque su patron es mas especifico.
	# Las lambdas llevan tipo en el parametro y en el retorno a proposito: sin
	# eso, GDScript no puede inferir y no compila.
	var r := _reemplazar(texto, _re_mascota,
		func(m: RegExMatch) -> String: return _elegir(m.get_string(1), g_masc))
	r = _reemplazar(r, _re_nino,
		func(m: RegExMatch) -> String: return _elegir(m.get_string(1), g_nino))
	r = _reemplazar(r, _re_var, func(m: RegExMatch) -> String:
		var clave: String = m.get_string(1)
		# Una variable desconocida se deja tal cual, para que se note al revisar
		# en vez de desaparecer en silencio.
		return _a_texto(vars[clave]) if vars.has(clave) else m.get_string(0))
	return r


## Aplana el config a las variables disponibles en los textos.
static func variables(cfg: Dictionary) -> Dictionary:
	var mascota: Dictionary = cfg.get("mascota", {})
	var col: Dictionary = cfg.get("coleccionable", {})
	var amigos: Array = cfg.get("amigos", [])
	var final: Dictionary = cfg.get("mensajeFinal", {})
	return {
		"nombre": cfg.get("nombre", ""),
		"apodo": cfg.get("apodo", "") if cfg.get("apodo", "") != "" else cfg.get("nombre", ""),
		"edad": cfg.get("edad", 0),
		"lugar": cfg.get("lugar", ""),
		"colegio": cfg.get("colegio", ""),
		"ciudad": cfg.get("ciudad", ""),
		"mascota": mascota.get("nombre", ""),
		"tipoMascota": mascota.get("tipo", ""),
		"coleccionable": col.get("plural", ""),
		"amigo1": amigos[0] if amigos.size() > 0 else "",
		"amigo2": amigos[1] if amigos.size() > 1 else "",
		"amigo3": amigos[2] if amigos.size() > 2 else "",
		"deQuien": final.get("firma", ""),
	}


## Resuelve un texto y ademas sustituye las variables de runtime que le pases.
##   con_datos("Juntaste {puntos} {coleccionable}", cfg, {"puntos": 12})
static func con_datos(texto: String, cfg: Dictionary, datos: Dictionary) -> String:
	var r := t(texto, cfg)
	for clave: String in datos:
		r = r.replace("{%s}" % clave, _a_texto(datos[clave]))
	return r


## Revisa una plantilla y devuelve sus problemas. Vacio = esta bien.
##
## POR QUE EXISTE: test.gd ya comprueba que los textos resuelvan sin dejar
## tokens sueltos, pero eso solo prueba el genero DEL PEDIDO QUE HAYA. Un texto
## escrito con dos variantes — "[o|a]" — pasa esa prueba con Sofia y con Pedro,
## y revienta el dia que entre un pedido neutro. Esto lo caza antes, mirando la
## plantilla en vez del resultado.
static func lint(plantilla: String) -> Array[String]:
	_compilar()
	var problemas: Array[String] = []

	for m: RegExMatch in _re_mascota.search_all(plantilla):
		var partes := m.get_string(1).split("|")
		if partes.size() != 3:
			problemas.append("[m:%s] tiene %d variantes, deben ser 3 (m|f|n)"
				% [m.get_string(1), partes.size()])

	# Los del niño se buscan sobre el texto SIN los de la mascota, porque el
	# patron general tambien casa con "[m:...]" y los contaria dos veces.
	var sin_mascota := _re_mascota.sub(plantilla, "", true)
	for m: RegExMatch in _re_nino.search_all(sin_mascota):
		var partes := m.get_string(1).split("|")
		if partes.size() != 3:
			problemas.append("[%s] tiene %d variantes, deben ser 3 (m|f|n)"
				% [m.get_string(1), partes.size()])

	# Las variables validas se preguntan a variables(), que es QUIEN LAS PRODUCE,
	# en vez de mantener una lista aparte: una lista a mano se desincroniza en
	# cuanto alguien agrega un campo, y entonces el linter da falsos positivos
	# sobre variables que si existen. Con un config vacio basta: lo que se usa
	# son las CLAVES.
	var conocidas := variables({}).keys()
	for m: RegExMatch in _re_var.search_all(plantilla):
		var v := m.get_string(1)
		if not RUNTIME.has(v) and not conocidas.has(v):
			problemas.append("{%s} no es una variable conocida" % v)

	return problemas
