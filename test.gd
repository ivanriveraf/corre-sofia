extends SceneTree

## Verificacion del runner.
##   godot --headless --path . --script res://test.gd
##
## Los casos de [1] a [4] son LOS MISMOS que juegos-cumple/test.js. Si los dos
## motores no dan identico, el probador del navegador y el juego entregado
## dirian cosas distintas — revisas un pedido y le mandas otro al cliente.

var fallos := 0

const CLAVES: Array[String] = [
	"nombre", "genero", "edad", "lugar", "coleccionable", "personaje", "colores"
]


func _ok(cond: bool, msg: String, extra := "") -> void:
	if cond:
		print("  OK    ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)
		if extra != "":
			print("        -> ", extra)


func _initialize() -> void:
	print("\n[1] El genero del cumpleanero reescribe el texto")
	var base := {"nombre": "X", "mascota": {"nombre": "M", "genero": "m"}}
	var casos: Array[Array] = [
		["¡Bienvenid[o|a|e], {nombre}!", "m", "¡Bienvenido, X!"],
		["¡Bienvenid[o|a|e], {nombre}!", "f", "¡Bienvenida, X!"],
		["¡Bienvenid[o|a|e], {nombre}!", "n", "¡Bienvenide, X!"],
		["Eres [un|una|une] campe[ón|ona|one]", "m", "Eres un campeón"],
		["Eres [un|una|une] campe[ón|ona|one]", "f", "Eres una campeona"],
		["Eres [un|una|une] campe[ón|ona|one]", "n", "Eres une campeone"],
	]
	for c: Array in casos:
		var cfg := base.duplicate(true)
		cfg["genero"] = c[1]
		var got: String = Genero.t(c[0], cfg)
		_ok(got == c[2], "[%s] \"%s\"" % [c[1], got], "esperaba \"%s\"" % c[2])

	print("\n[2] La mascota tiene su propio canal, independiente del nino")
	var mascotas: Array[Array] = [
		["f", "m", "{mascota} está perdid[m:o|a|e]", "M está perdido"],
		["f", "f", "{mascota} está perdid[m:o|a|e]", "M está perdida"],
		["m", "n", "Ayuda a encontrar[m:lo|la|le]", "Ayuda a encontrarle"],
		["m", "f", "Sol[o|a|e] {nombre} puede encontrar[m:lo|la|le]", "Solo X puede encontrarla"],
		["f", "m", "Sol[o|a|e] {nombre} puede encontrar[m:lo|la|le]", "Sola X puede encontrarlo"],
	]
	for c: Array in mascotas:
		var cfg := {"nombre": "X", "genero": c[0], "mascota": {"nombre": "M", "genero": c[1]}}
		var got: String = Genero.t(c[2], cfg)
		_ok(got == c[3], "nino=%s mascota=%s -> \"%s\"" % [c[0], c[1], got],
			"esperaba \"%s\"" % c[3])

	print("\n[3] Un token que empieza con \"m\" NO se confunde con el canal mascota")
	var trampa := Genero.t("Hay [mucho|mucha|muche] que hacer",
		{"nombre": "X", "genero": "f", "mascota": {"nombre": "M", "genero": "m"}})
	_ok(trampa == "Hay mucha que hacer", "\"%s\"" % trampa)

	print("\n[4] Variables de runtime")
	var cfg_r := {"nombre": "X", "genero": "f", "coleccionable": {"plural": "gatitos"}}
	var meta := Genero.con_datos("Juntaste {puntos} {coleccionable}", cfg_r, {"puntos": 12})
	_ok(meta == "Juntaste 12 gatitos", "\"%s\"" % meta)
	var sin_dato := Genero.t("Juntaste {puntos} {coleccionable}", cfg_r)
	_ok(sin_dato.contains("{puntos}"),
		"sin el dato, {puntos} queda visible en vez de desaparecer")

	# JSON entrega los numeros como float: {edad} tiene que salir "6", no "6.0".
	# Este bug SI llego al juego, y solo se vio leyendo la salida de este test.
	var edad := Genero.t("Hoy cumples {edad} años",
		{"nombre": "X", "genero": "f", "edad": 6.0})
	_ok(edad == "Hoy cumples 6 años", "\"%s\"" % edad,
		"la edad no puede salir con decimales")
	var medio := Genero.t("{edad}", {"edad": 6.5})
	_ok(medio == "6.5", "un decimal de verdad si se respeta: \"%s\"" % medio)

	print("\n[5] El config del pedido carga y esta completo")
	var cfg := _cargar_config()
	_ok(not cfg.is_empty(), "config.json carga")
	for clave: String in CLAVES:
		_ok(cfg.has(clave), "tiene '%s'" % clave)
	_ok(["m", "f", "n"].has(cfg.get("genero", "")),
		"genero es m, f o n (es \"%s\")" % cfg.get("genero", ""))

	print("\n[6] Ningun titulo del runner depende del genero")
	for g: String in ["m", "f", "n"] as Array[String]:
		var c := cfg.duplicate(true)
		c["genero"] = g
		var titulos: Array[String] = []
		for g2: String in ["m", "f", "n"] as Array[String]:
			var c2 := cfg.duplicate(true)
			c2["genero"] = g2
			titulos.append(Genero.t(Textos.RUNNER["titulo"], c2))
		_ok(titulos[0] == titulos[1] and titulos[1] == titulos[2],
			"titulo: \"%s\"" % titulos[0], "varia: %s" % str(titulos))
		break

	print("\n[7] Los textos del runner resuelven sin dejar tokens sueltos")
	for clave: String in Textos.RUNNER:
		var txt: String = Genero.con_datos(Textos.RUNNER[clave], cfg, {"puntos": 9})
		_ok(not txt.contains("[") and not txt.contains("{"),
			"runner.%s: \"%s\"" % [clave, txt.substr(0, 58)])
	for clave: String in Textos.COMUN:
		var txt: String = Genero.t(Textos.COMUN[clave], cfg)
		_ok(not txt.contains("[") and not txt.contains("{"),
			"comun.%s: \"%s\"" % [clave, txt.substr(0, 58)])

	print("\n[8] La paleta arma las reglas correctas")
	var p: Dictionary = cfg.get("personaje", {})
	_ok(Paleta._cuantas("FlatBoy", p) == 7,
		"FlatBoy con este pedido: %d tonos mapeados" % Paleta._cuantas("FlatBoy", p))
	_ok(Paleta._cuantas("FlatBoy", {}) == 0,
		"personaje vacio -> 0 reglas, el sprite va tal cual")
	# El mismo #ff6666 tiene que caer en ranuras distintas segun el pack
	_ok(Paleta.PALETAS["FlatBoy"]["gorro"]["base"] == "ff6666",
		"#ff6666 es 'gorro' en FlatBoy")
	_ok(Paleta.PALETAS["CuteGirlFiles"]["pelo"]["base"] == "ff6666",
		"#ff6666 es 'pelo' en CuteGirl")

	print("\n[9] Estan todos los cuadros de animacion que declara arte.gd")
	for quien: String in Arte.FUENTES:
		var f: Dictionary = Arte.FUENTES[quien]
		for anim: String in f["animaciones"]:
			var a: Dictionary = f["animaciones"][anim]
			var n: int = int(a["cuadros"])
			var faltan := 0
			for i in range(1, n + 1):
				if not FileAccess.file_exists("%s/%s_%02d.png" % [f["carpeta"], anim, i]):
					faltan += 1
			_ok(faltan == 0, "%s/%s: %d cuadros" % [quien, anim, n],
				"faltan %d archivos" % faltan)
			# Cada animacion tiene que traer su propia paleta MEDIDA. Sin esto,
			# reusar la paleta de otra animacion pasa desapercibido hasta que se
			# ve media falda sin recolorear en pantalla.
			_ok(Paleta.PALETAS.has(a["pack"]),
				"%s/%s declara la paleta '%s'" % [quien, anim, a["pack"]],
				"falta '%s' en paleta.gd" % a["pack"])

	print()
	print("[11] El catalogo puede cumplir este pedido")
	# Esta es la prueba que impide entregar un pedido imposible. El juego se abre
	# igual si falta el set — un pedido pagado no puede terminar en pantalla
	# negra — pero entonces sale con el peinado de otro, y de eso hay que
	# enterarse en el taller, no en la fiesta.
	var falta := Arte.faltantes(cfg)
	_ok(falta.is_empty(),
		"hay sprites para el genero '%s', el peinado '%s' y la mascota '%s'"
			% [cfg.get("genero", ""),
				(cfg.get("personaje", {}) as Dictionary).get("peinado", ""),
				(cfg.get("mascota", {}) as Dictionary).get("tipo", "")],
		"el catalogo NO tiene: %s  ->  o corriges el pedido, o generas el set" % ", ".join(falta))
	# El set que se elija tiene que existir de verdad en FUENTES.
	_ok(Arte.FUENTES.has(Arte.set_jugador(cfg)),
		"el set del niño ('%s') existe" % Arte.set_jugador(cfg))
	_ok(Arte.FUENTES.has(Arte.set_mascota(cfg)),
		"el set de la mascota ('%s') existe" % Arte.set_mascota(cfg))

	print()
	print("[10] La caja de colision sale del cuerpo, no del dibujo")
	for quien: String in Arte.FUENTES:
		var fa: Dictionary = Arte.FUENTES[quien]
		for anim: String in fa["animaciones"]:
			var a: Dictionary = fa["animaciones"][anim]
			var c: Rect2 = a["cuerpo"]
			var ancho_dibujo: float = float(a["dibujo"].x) * float(a["escala"])
			# Si alguien vuelve a sacar la caja del tamaño del dibujo, esto salta:
			# el dibujo de la niña mide 246 px de ancho pero su cuerpo 172, porque
			# el resto es pelo al vuelo.
			_ok(c.size.x > 0.0 and c.size.y > 0.0, "%s/%s: caja %s" % [quien, anim, c])
			# Vale para todos: la caja nunca puede ser el lienzo.
			_ok(c.size.x < ancho_dibujo,
				"%s/%s: nucleo %.0f px contra %.0f de dibujo (%.0f%%)"
					% [quien, anim, c.size.x, ancho_dibujo, 100.0 * c.size.x / ancho_dibujo],
				"la caja esta saliendo del lienzo, no del cuerpo")
			# El nodo esta AL RAS DEL SUELO: nada del cuerpo puede quedar debajo.
			_ok(c.end.y <= 0.0, "%s/%s: la caja no cuelga bajo el suelo" % [quien, anim],
				"cuelga %.0f px" % c.end.y)

	# Regresion: se perdia porque el pie delantero de la zancada rozaba el
	# obstaculo. La caja de la niña tiene que ser su NUCLEO — tronco y cara — y
	# eso es mucho menos de la mitad de su dibujo, que lo manda el pelo al vuelo.
	#
	# El umbral solo aplica a ella: el perro es un animal horizontal y su tronco
	# ocupa el 74% del dibujo con toda razon. Ademas no choca con nada.
	for anim: String in Arte.FUENTES["ninaSuelto"]["animaciones"]:
		var an: Dictionary = Arte.FUENTES["ninaSuelto"]["animaciones"][anim]
		var caja: Rect2 = an["cuerpo"]
		var dib: float = float(an["dibujo"].x) * float(an["escala"])
		_ok(caja.size.x < dib * 0.5,
			"ninaSuelto/%s: la caja es el nucleo (%.0f%% del dibujo)" % [anim, 100.0 * caja.size.x / dib],
			"incluye brazos y piernas estirados: se pierde por rozar con el zapato")

	# La otra cara del mismo arreglo: al perdonar mas, hay que comprobar que
	# TODAVIA se pueda chocar. Una caja demasiado chica no da un juego facil, da
	# un juego roto — se atraviesan los obstaculos y no hay nada que esquivar.
	#
	# Los numeros salen de main.gd. Se repiten aqui a proposito: si alguien los
	# cambia alla sin pensar en la colision, esta prueba se lo dice.
	var SUELO := 980.0
	var JUGADOR_X := 230.0
	var ALTO_SALTO := 1480.0 * 1480.0 / (2.0 * 2900.0)   # IMPULSO^2 / 2*GRAVEDAD
	var corriendo: Rect2 = Arte.FUENTES["ninaSuelto"]["animaciones"]["run"]["cuerpo"]
	var saltando: Rect2 = Arte.FUENTES["ninaSuelto"]["animaciones"]["jump"]["cuerpo"]
	var obstaculo := Rect2(JUGADOR_X - 54.0, SUELO - 56.0 - 54.0, 108.0, 108.0)

	var en_suelo := Rect2(JUGADOR_X + corriendo.position.x, SUELO + corriendo.position.y,
		corriendo.size.x, corriendo.size.y)
	_ok(en_suelo.intersects(obstaculo),
		"corriendo por el suelo, el obstaculo SI choca",
		"la caja quedo tan chica que se atraviesan los obstaculos")

	var en_alto := Rect2(JUGADOR_X + saltando.position.x,
		SUELO - ALTO_SALTO + saltando.position.y, saltando.size.x, saltando.size.y)
	_ok(not en_alto.intersects(obstaculo),
		"en lo mas alto del salto (%.0f px) lo libra" % ALTO_SALTO,
		"ni saltando al maximo se pasa: el juego seria imposible")

	# Regresion: se perdia sin haber tocado el obstaculo. En el salto la niña
	# recoge las piernas, o sea que sus pies quedan MUY por encima del nodo; con
	# la caja pegada al nodo, colgaba por debajo de sus pies y enganchaba lo que
	# en pantalla ya habia librado.
	var salto: Rect2 = Arte.FUENTES["ninaSuelto"]["animaciones"]["jump"]["cuerpo"]
	_ok(salto.end.y < -20.0,
		"saltando, la caja termina %.0f px sobre el suelo (piernas recogidas)" % -salto.end.y,
		"la caja llega al suelo aunque las piernas van recogidas")

	print("\n" + "=".repeat(58))
	if fallos == 0:
		print("TODO OK — el motor GDScript coincide con el de JavaScript.")
	else:
		print("%d FALLA(S) — revisar arriba." % fallos)
	quit(0 if fallos == 0 else 1)


func _cargar_config() -> Dictionary:
	if not FileAccess.file_exists("res://config.json"):
		return {}
	var leido: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config.json"))
	return leido if typeof(leido) == TYPE_DICTIONARY else {}
