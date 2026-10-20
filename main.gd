extends Node2D

## ¡Corre, <Nombre>! — el runner personalizado.
##
## Todo lo que distingue a un cliente de otro sale de config.json: el nombre,
## el genero de los textos, los colores del personaje, que junta y donde corre.
## Este archivo no menciona a ningun cliente.

const ANCHO := 720.0
const ALTO := 1280.0
const SUELO := 980.0
const JUGADOR_X := 230.0

const GRAVEDAD := 2900.0
const IMPULSO := -1480.0     # salto de ~378 px, ver _alto_salto()
# Velocidad del mundo. Se mide en ALTURAS DE LA NIÑA por segundo, no en pixeles
# sueltos: son 334 px en pantalla, y lo que hace que algo se vea rapido o lento
# es cuanto avanza respecto a su propio tamaño.
#
#   340 px/s = 1.0 alturas/s  -> un trote
#   540 px/s = 1.6 alturas/s  -> corriendo de verdad
#
# Antes iba de 430 a 780 (1.3 a 2.3 alturas/s). Cruzaba la pantalla en 0.9 s al
# final, demasiado para un niño de 4 o 5 años.
#
# Esto ademas manda sobre la animacion, que avanza con el suelo: si esto sube,
# las piernas se mueven mas rapido solas, sin tocar nada en arte.gd.
const VEL_INICIAL := 340.0
const VEL_MAXIMA := 540.0
const ACELERACION := 7.0        # px/s que gana por segundo jugado: llega al tope a los 30 s
const META := 25                # coleccionables para ganar

enum Estado { TITULO, JUGANDO, PERDIO, GANO }

var _estado: Estado = Estado.TITULO
var _vel := VEL_INICIAL
var _puntos := 0
var _y := 0.0                   # desplazamiento vertical del jugador
var _vy := 0.0
var _en_suelo := true
var _t_spawn := 0.0
var _distancia := 0.0
var _t_desde_obstaculo := 0.0
var _tiempo_partida := 0.0

var _jugador: Arte.SpriteAnimado
var _mascota: Arte.SpriteAnimado
var _cosas: Array[Node2D] = []  # obstaculos y coleccionables en pantalla

var _capa_juego: Node2D
var _hud: Label
var _panel: Control
var _titulo: Label
var _cuerpo: Label
var _pie: Label

var _col_primario: Color
var _col_secundario: Color
var _col_fondo: Color

# Tintas derivadas del fondo del cliente. Ver _resolver_tintas().
var _tinta_titulo: Color
var _tinta_cuerpo: Color
var _tinta_suave: Color


## Modo demo: el juego se juega solo. Se activa pasando --demo despues de "--".
##
##   godot --path . --write-movie promo.avi --quit-after 900 -- --demo
##
## Sirve para dos cosas: grabar el video de promocion del pedido de cada cliente
## sin tener que jugarlo a mano, y poder revisar la jugabilidad sin depender de
## que alguien se siente a probarla.
var _demo := false

## Dibuja las cajas de colision encima del juego: --cajas despues de "--".
##
## Existe porque un jugador reporto perder sin tocar el obstaculo, y sobre el
## dibujo no se puede saber donde esta la caja. Con esto se ve, que es la unica
## forma de comprobar si la caja coincide con lo que se ve en pantalla.
var _sonido: Sonido
var _destello: ColorRect

var _ver_cajas := false

## Piloto torpe: --torpe salta tarde y a destiempo, a proposito.
##
## El piloto normal no falla nunca, asi que los choques dudosos — los que el
## jugador reporta como injustos — no aparecen jamas. Con esto si, y quedan
## registrados con sus numeros.
var _torpe := false
var _capa_cajas: Node2D


func _ready() -> void:
	_demo = OS.get_cmdline_user_args().has("--demo")
	_ver_cajas = OS.get_cmdline_user_args().has("--cajas")
	_torpe = OS.get_cmdline_user_args().has("--torpe")
	_col_primario = Pedido.color("primario", "#4A90D9")
	_col_secundario = Pedido.color("secundario", "#FFD166")
	_col_fondo = Pedido.color("fondo", "#1B2A3A")
	_resolver_tintas()

	_construir_fondo()
	_construir_personajes()
	_construir_interfaz()
	_sonido = Sonido.new()
	add_child(_sonido)
	if _ver_cajas:
		_capa_cajas = CajasDebug.new()
		_capa_cajas.juego = self
		_capa_cajas.z_index = 100
		add_child(_capa_cajas)
	_ir_a_titulo()
	if _demo:
		_empezar()


## Los colores del texto NO pueden estar fijos: cada cliente trae su paleta y
## los fondos vienen tanto claros como oscuros. El de Sofia es #FFF4F8, un
## rosado casi blanco — con titulo amarillo y cuerpo blanco no se leia nada.
##
## Se elige segun la luminosidad del fondo, no segun el gusto.
func _resolver_tintas() -> void:
	if _col_fondo.get_luminance() > 0.55:
		# Fondo claro: el amarillo del secundario no contrasta, y el blanco
		# menos. Se tira del primario oscurecido, que siempre es un color fuerte.
		_tinta_titulo = _col_primario.darkened(0.25)
		_tinta_cuerpo = _col_fondo.darkened(0.82)
		_tinta_suave = _col_primario.darkened(0.05)
	else:
		_tinta_titulo = _col_secundario
		_tinta_cuerpo = Color.WHITE
		_tinta_suave = _col_primario.lightened(0.4)


## El escenario se mezcla HACIA el fondo del cliente en vez de oscurecerse a
## ciegas. Con un fondo claro, unas colinas muy oscuras se comen media pantalla
## y el personaje deja de leerse encima.
##   cercania 0 = igual al fondo, 1 = color primario puro
func _tono_escenario(cercania: float) -> Color:
	return _col_fondo.lerp(_col_primario, cercania)


## Altura maxima del salto, deducida de la fisica: v^2 / (2g).
## Se calcula en vez de escribirla a mano para no volver a generar premios donde
## el jugador no llega — que es lo que pasaba con los que puse a 300 px, cuando
## el salto solo alcanza 228.
func _alto_salto() -> float:
	return (IMPULSO * IMPULSO) / (2.0 * GRAVEDAD)


## Cuanto dura un salto completo, de despegue a aterrizaje.
func _duracion_salto() -> float:
	return 2.0 * absf(IMPULSO) / GRAVEDAD


## Distancia horizontal que recorre el jugador durante un salto completo.
func _largo_salto() -> float:
	return _vel * _duracion_salto()


# ------------------------------------------------------------------ escena

func _construir_fondo() -> void:
	var cielo := ColorRect.new()
	cielo.color = _col_fondo
	cielo.size = Vector2(ANCHO, ALTO)
	cielo.z_index = -20
	add_child(cielo)

	# Colinas de fondo: dos tonos del color primario, sin sprites, para que el
	# escenario tome el color del cliente sin depender de ningun asset.
	for i in range(2):
		var colina := Polygon2D.new()
		var alto_c := 150.0 + i * 90.0
		var base := SUELO - 40.0 + i * 30.0
		var pts := PackedVector2Array()
		pts.append(Vector2(-50, ALTO))
		for x in range(-50, int(ANCHO) + 100, 40):
			pts.append(Vector2(x, base - sin(float(x) * 0.006 + i * 2.0) * alto_c * 0.35 - alto_c * 0.4))
		pts.append(Vector2(ANCHO + 50, ALTO))
		colina.polygon = pts
		colina.color = _tono_escenario(0.22 + i * 0.16)
		colina.z_index = -15 + i
		add_child(colina)

	var suelo := ColorRect.new()
	suelo.color = _tono_escenario(0.62)
	suelo.position = Vector2(0, SUELO)
	suelo.size = Vector2(ANCHO, ALTO - SUELO)
	suelo.z_index = -5
	add_child(suelo)

	var linea := ColorRect.new()
	linea.color = _tono_escenario(0.9)
	linea.position = Vector2(0, SUELO)
	linea.size = Vector2(ANCHO, 5)
	linea.z_index = -4
	add_child(linea)

	# Nubes: el cielo ocupa mas de la mitad de la pantalla y sin nada se lee como
	# un error, no como espacio. Son circulos superpuestos, sin ningun asset.
	for nube in [Vector3(140, 250, 1.0), Vector3(520, 170, 0.75), Vector3(330, 430, 0.55)]:
		var g := Node2D.new()
		g.position = Vector2(nube.x, nube.y)
		g.scale = Vector2.ONE * nube.z
		g.z_index = -18
		for bulto in [Vector3(-60, 10, 42.0), Vector3(0, -12, 56.0), Vector3(58, 8, 38.0)]:
			var c := Polygon2D.new()
			c.polygon = _circulo(bulto.z)
			c.position = Vector2(bulto.x, bulto.y)
			c.color = _tono_escenario(0.10)
			g.add_child(c)
		add_child(g)

	_capa_juego = Node2D.new()
	# Delante de la mascota (z=1) y detras de la niña (z=3). Sin esto los
	# obstaculos iban al fondo y el perro los tapaba al pasar: desaparecian
	# detras de el. La niña si los tapa, y esta bien — es ella quien va delante.
	_capa_juego.z_index = 2
	add_child(_capa_juego)


static func _circulo(radio: float, lados := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(lados):
		var a := TAU * float(i) / float(lados)
		pts.append(Vector2(cos(a), sin(a)) * radio)
	return pts


func _construir_personajes() -> void:
	var p := Pedido.personaje()

	# Quien aparece lo decide el PEDIDO, no este archivo: el genero y el peinado
	# del config eligen el set del catalogo. Ver Arte.CATALOGO.
	_mascota = Arte.crear(Arte.set_mascota(Pedido.cfg), p)
	_mascota.position = Vector2(JUGADOR_X - 165.0, SUELO)
	_mascota.z_index = 1
	add_child(_mascota)

	_jugador = Arte.crear(Arte.set_jugador(Pedido.cfg), p)
	_jugador.position = Vector2(JUGADOR_X, SUELO)
	_jugador.z_index = 3
	add_child(_jugador)


func _construir_interfaz() -> void:
	_hud = Label.new()
	_hud.position = Vector2(30, 30)
	_hud.size = Vector2(ANCHO - 60, 70)
	_hud.add_theme_font_size_override("font_size", 46)
	_hud.add_theme_color_override("font_color", _tinta_titulo)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.z_index = 10
	add_child(_hud)

	# Los Control se comen los clics por defecto (MOUSE_FILTER_STOP), asi que el
	# panel de titulo bloqueaba el toque y el juego no arrancaba nunca. En el
	# telefono habria pasado igual con el tactil.
	# Destello del choque. Va por ENCIMA del juego y por DEBAJO del panel final
	# (z 15 contra 20): se ve el golpe y luego entra el panel, en ese orden.
	_destello = ColorRect.new()
	_destello.color = Color(1, 1, 1, 0)
	_destello.size = Vector2(ANCHO, ALTO)
	_destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_destello.z_index = 15
	add_child(_destello)

	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.z_index = 20
	add_child(_panel)

	var velo := ColorRect.new()
	velo.color = Color(_col_fondo, 0.92)
	velo.size = Vector2(ANCHO, ALTO)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(velo)

	_titulo = Label.new()
	_titulo.position = Vector2(50, 300)
	_titulo.size = Vector2(ANCHO - 100, 220)
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titulo.add_theme_font_size_override("font_size", 76)
	_titulo.add_theme_color_override("font_color", _tinta_titulo)
	_panel.add_child(_titulo)

	_cuerpo = Label.new()
	_cuerpo.position = Vector2(70, 560)
	_cuerpo.size = Vector2(ANCHO - 140, 340)
	_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cuerpo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cuerpo.add_theme_font_size_override("font_size", 40)
	_cuerpo.add_theme_color_override("font_color", _tinta_cuerpo)
	_panel.add_child(_cuerpo)

	_pie = Label.new()
	_pie.position = Vector2(50, 1050)
	_pie.size = Vector2(ANCHO - 100, 90)
	_pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pie.add_theme_font_size_override("font_size", 44)
	_pie.add_theme_color_override("font_color", _tinta_suave)
	_panel.add_child(_pie)


# ------------------------------------------------------------------ estados

func _ir_a_titulo() -> void:
	_estado = Estado.TITULO
	_panel.visible = true
	_hud.visible = false
	_titulo.text = Pedido.texto(Textos.RUNNER["titulo"])
	_cuerpo.text = Pedido.texto(Textos.RUNNER["instruccion"])
	_pie.text = Pedido.texto(Textos.COMUN["jugar"])


func _empezar() -> void:
	_sonido.tocar("empezar")
	_estado = Estado.JUGANDO
	_panel.visible = false
	_hud.visible = true
	_vel = VEL_INICIAL
	_puntos = 0
	_distancia = 0.0
	_y = 0.0
	_vy = 0.0
	_en_suelo = true
	_t_spawn = 0.6
	_t_desde_obstaculo = 99.0
	_tiempo_partida = 0.0
	for c in _cosas:
		c.queue_free()
	_cosas.clear()
	_actualizar_hud()


func _terminar(gano: bool) -> void:
	# El estado cambia PRIMERO: congela el mundo en el fotograma del golpe. Antes
	# el panel entraba de golpe en el mismo instante del choque y no se llegaba a
	# ver que habia pasado; con esta pausa el niño ve que choco, y luego lee.
	_estado = Estado.GANO if gano else Estado.PERDIO
	_hud.visible = false

	if gano:
		_sonido.tocar("ganar")
	else:
		# El golpe primero y la melodia detras: el choque es la causa y conviene
		# que se oiga pegado a la imagen.
		_sonido.tocar("choque")
		_sonido.tocar("perder", 1.0, -4.0)
		_parpadeo(Color(1, 1, 1, 0.55), 0.28)


	if gano:
		_titulo.text = Pedido.texto(Textos.COMUN["ganaste"])
		var meta: String = Pedido.texto(Textos.RUNNER["meta"], {"puntos": _puntos})
		_cuerpo.text = meta + "\n\n" + Pedido.texto(Textos.COMUN["despedida"])
	else:
		_titulo.text = Pedido.texto(Textos.COMUN["perdiste"])
		var col: Dictionary = Pedido.cfg.get("coleccionable", {})
		_cuerpo.text = "Juntaste %d de %d %s.\n\n%s" % [
			_puntos, META, col.get("plural", ""),
			Pedido.texto(Textos.RUNNER["animo"]),
		]
	_pie.text = Pedido.texto(Textos.COMUN["reintentar"])

	await get_tree().create_timer(0.45 if not gano else 0.25).timeout
	_panel.visible = true

	if _demo:
		print("[demo] %s con %d/%d en %.1f s" % ["GANO" if gano else "perdio", _puntos, META, _tiempo_partida])
		# Sin esto la grabacion se queda congelada en la pantalla final.
		await get_tree().create_timer(2.0).timeout
		_empezar()


# ------------------------------------------------------------------ bucle

func _process(delta: float) -> void:
	# Las animaciones avanzan con el SUELO, no con el reloj: se les pasa cuanto
	# terreno paso en este fotograma. Asi el pie apoyado se queda pegado al piso
	# aunque el juego acelere, sin tener que ajustar cuadros por segundo.
	#
	# Va ANTES del corte por estado: en la portada no hay partida pero los dos
	# siguen corriendo en el sitio, que es lo que invita a tocar la pantalla.
	# En la portada corren en el sitio, que es lo que invita a tocar. Al terminar
	# se quedan QUIETOS: seguir trotando despues de estrellarse se ve a broma.
	var vel_anim := 0.0
	if _estado == Estado.JUGANDO:
		vel_anim = _vel
	elif _estado == Estado.TITULO:
		vel_anim = VEL_INICIAL
	_jugador.avanzar(vel_anim * delta)
	_mascota.avanzar(vel_anim * delta)

	if _estado != Estado.JUGANDO:
		return

	_vel = minf(_vel + ACELERACION * delta, VEL_MAXIMA)
	_tiempo_partida += delta
	_distancia += _vel * delta

	if _demo:
		_jugar_solo()
	_mover_jugador(delta)
	_mover_cosas(delta)
	_generar(delta)
	if _ver_cajas:
		_capa_cajas.queue_redraw()


func _mover_jugador(delta: float) -> void:
	if not _en_suelo:
		_vy += GRAVEDAD * delta
		_y += _vy * delta
		if _y >= 0.0:
			_y = 0.0
			_vy = 0.0
			_en_suelo = true

	_jugador.position.y = SUELO + _y
	# La mascota sigue el salto con retraso: da sensacion de que corre atras.
	_mascota.position.y = SUELO + _y * 0.35
	_animar_salto()


## Elige la animacion y el cuadro del jugador.
##
## El cuadro del salto NO sale de un temporizador sino de la VELOCIDAD VERTICAL.
## Con reloj, la pose y el vuelo se desincronizan en cuanto el salto dura otra
## cosa — y aca dura otra cosa siempre, porque el niño puede soltar el salto
## antes. Atado a _vy, el despegue cae siempre en el primer cuadro y el punto
## mas alto en el del medio, dure lo que dure el salto.
##
##   _vy = IMPULSO (subiendo fuerte)  -> 0.0 -> cuadro 1, el despegue
##   _vy = 0       (punto mas alto)   -> 0.5 -> cuadro 3
##   _vy = -IMPULSO (cayendo fuerte)  -> 1.0 -> cuadro 4, estirada para caer
func _animar_salto() -> void:
	if _en_suelo:
		_jugador.usar("run")
		_jugador.cuadro_fijo = -1
		_jugador.rotation = 0.0
		return

	_jugador.usar("jump")
	# Cuantos cuadros hay se le pregunta al sprite en vez de ponerlo aca: si
	# algun dia el salto se regenera con mas poses, esto no hay que tocarlo.
	var n := _jugador.n_cuadros("jump")
	var avance := (_vy - IMPULSO) / (-2.0 * IMPULSO)
	_jugador.cuadro_fijo = clampi(int(avance * float(n)), 0, n - 1)
	# Aca habia una inclinacion segun _vy. Existia para simular el salto CUANDO
	# NO HABIA animacion de salto; ahora la hay, y las dos juntas se pelean: el
	# giro ademas acorta el cuerpo en pantalla y descalza la escala.


func _mover_cosas(delta: float) -> void:
	for i in range(_cosas.size() - 1, -1, -1):
		var c := _cosas[i]
		c.position.x -= _vel * delta

		if c.position.x < -120.0:
			c.queue_free()
			_cosas.remove_at(i)
			continue

		if _choca(c):
			if _demo or _ver_cajas:
				_explicar_choque(c)
			if c.get_meta("tipo", "") == "premio":
				_puntos += 1
				# El tono sube con el avance: a los 25 gatitos suena medio tono
				# mas alto que al primero. Es la forma mas barata de que el niño
				# OIGA que se esta acercando a la meta, sin mirar el marcador.
				_sonido.tocar("recoger", 1.0 + 0.45 * float(_puntos) / float(META))
				_actualizar_hud()
				_cosas.remove_at(i)
				_reventar(c)
				if _puntos >= META:
					_terminar(true)
					return
			else:
				_terminar(false)
				return


## Colision por cajas, sin motor de fisica: son dos rectangulos, no hace falta mas.
## La caja del jugador. Separada de _choca para que el dibujo de depuracion use
## EXACTAMENTE la misma, y no una copia que se desincronice.
##
## Sale del CUERPO medido de la animacion en curso (ver arte.gd), no del tamaño
## del dibujo. Con el dibujo estaba mal de dos formas: el ancho lo mandaba el
## pelo al vuelo, y el fondo se pegaba al nodo aunque la niña llevara las
## piernas recogidas — asi se perdia sin haber tocado el obstaculo.
##
## No se le aplica ningun factor encima: el perdon ya esta en QUE se mide. La
## caja es el nucleo del cuerpo — tronco y cara — y deja fuera el pie y el puño
## de la zancada. Eso es criterio de juego, no de dibujo: para un niño de 6 años
## vale mas perdonar un roce que ser exacto, y que se sienta injusto arruina el
## regalo. Un numero magico de "encogimiento" ademas se desajusta solo cuando
## cambia el arte; una medida del nucleo se vuelve a medir.
func caja_jugador() -> Rect2:
	var c := _jugador.cuerpo()
	return Rect2(JUGADOR_X + c.position.x, SUELO + _y + c.position.y, c.size.x, c.size.y)


func caja_cosa(c: Node2D) -> Rect2:
	var r: float = c.get_meta("radio", 40.0)
	return Rect2(c.position - Vector2(r, r), Vector2(r * 2, r * 2))


func _choca(c: Node2D) -> bool:
	# La caja se ancla en los PIES, no en el centro del sprite: el centro depende
	# del PNG y del recorte, y si cambia el pack de arte la colision se desalinea.
	#
	# Y es mas chica que el dibujo a proposito. Para un niño de 6 años vale mas
	# perdonar un roce que ser exacto: que se sienta injusto arruina el regalo.
	# Sale del tamaño MEDIDO del dibujo, no del lienzo del PNG: asi la caja sigue
	# al personaje aunque cambie el pack de arte o la escala.
	# Se pide "run" a proposito, no la animacion actual: en el salto el dibujo
	# cambia de alto y de escala, y si la caja lo siguiera se agrandaria o se
	# achicaria en el aire. La caja tiene que medir siempre lo mismo.
	return caja_jugador().intersects(caja_cosa(c))


## Cuenta contra que se choco y con que numeros. Solo en demo o con --cajas.
##
## Existe porque hubo dos reportes de "perdi sin tocar nada" y desde el dibujo no
## se puede saber: hay que ver las cajas y el estado del salto en ese fotograma.
func _explicar_choque(c: Node2D) -> void:
	var pj := caja_jugador()
	var pc := caja_cosa(c)
	var solape := pj.intersection(pc)
	print("[choque] %s en x=%.0f  |  jugador %s  cosa %s  |  solape %.0fx%.0f  |  _y=%.0f en_suelo=%s"
		% [c.get_meta("tipo", "?"), c.position.x, pj, pc, solape.size.x, solape.size.y,
			_y, _en_suelo])


## El coleccionable no desaparece de golpe: crece y se desvanece.
##
## Es medio segundo de nada, pero es el premio de la accion que el niño repite 25
## veces por partida. Sin esto, juntar un gatito y que se esfume sin mas se siente
## como si no hubiera pasado.
func _reventar(c: Node2D) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(c, "scale", Vector2.ONE * 1.7, 0.22) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "modulate:a", 0.0, 0.22)
	# Sigue viajando con el suelo mientras revienta. Sin esto se queda clavado en
	# pantalla y se nota que ya no es parte del mundo.
	t.tween_property(c, "position:x", c.position.x - _vel * 0.22, 0.22)
	await t.finished
	# El nodo ya no esta en _cosas, asi que un reinicio a mitad del reventon no
	# lo libera: puede seguir vivo o no cuando el tween acaba.
	if is_instance_valid(c):
		c.queue_free()


## Un golpe de color sobre todo el juego, que se apaga solo.
func _parpadeo(color: Color, duracion: float) -> void:
	_destello.color = color
	var t := create_tween()
	t.tween_property(_destello, "color:a", 0.0, duracion).set_trans(Tween.TRANS_QUAD)


func _generar(delta: float) -> void:
	_t_spawn -= delta
	_t_desde_obstaculo += delta
	if _t_spawn > 0.0:
		return

	_t_spawn = 0.55 + randf() * 0.35

	# Dos obstaculos nunca pueden quedar mas juntos que un salto completo, o el
	# juego se vuelve imposible: saltas el primero y aterrizas encima del
	# segundo. El margen sale de la fisica del salto, no de un numero a ojo, asi
	# que sigue siendo justo aunque cambies la gravedad o el impulso.
	var puede_obstaculo := _t_desde_obstaculo >= _duracion_salto() * 1.7

	if puede_obstaculo and randf() < 0.42:
		_capa_juego.add_child(_crear_obstaculo())
		_t_desde_obstaculo = 0.0
	else:
		_capa_juego.add_child(_crear_premio())


func _crear_obstaculo() -> Node2D:
	var n := Node2D.new()
	n.position = Vector2(ANCHO + 90.0, SUELO - 56.0)
	n.set_meta("tipo", "obstaculo")
	n.set_meta("radio", 54.0)

	var cuerpo := Polygon2D.new()
	cuerpo.polygon = PackedVector2Array([
		Vector2(-56, 56), Vector2(-40, -46), Vector2(8, -62),
		Vector2(48, -38), Vector2(59, 56),
	])
	cuerpo.color = _col_primario.darkened(0.35)
	n.add_child(cuerpo)

	var brillo := Polygon2D.new()
	brillo.polygon = PackedVector2Array([
		Vector2(-32, -27), Vector2(0, -46), Vector2(13, -24), Vector2(-19, -8),
	])
	brillo.color = _col_primario.lightened(0.15)
	n.add_child(brillo)

	_cosas.append(n)
	return n


func _crear_premio() -> Node2D:
	var n := Node2D.new()
	# A distintas alturas: algunos obligan a saltar, otros se juntan corriendo.
	# Fracciones del salto maximo: al ras, a media altura y casi en el tope.
	var techo := _alto_salto()
	var altura: float = [60.0, techo * 0.55, techo * 0.88].pick_random()
	n.position = Vector2(ANCHO + 80.0, SUELO - altura)
	n.set_meta("tipo", "premio")
	n.set_meta("radio", 56.0)

	var estrella := Polygon2D.new()
	estrella.polygon = _puntos_estrella(56.0, 24.0, 5)
	estrella.color = _col_secundario
	n.add_child(estrella)

	var centro := Polygon2D.new()
	centro.polygon = _puntos_estrella(29.0, 13.0, 5)
	centro.color = _col_secundario.lightened(0.45)
	n.add_child(centro)

	_cosas.append(n)
	return n


static func _puntos_estrella(radio: float, interno: float, puntas: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var paso := PI / float(puntas)
	for i in range(puntas * 2):
		var r := radio if i % 2 == 0 else interno
		var a := -PI / 2.0 + paso * i
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts


func _actualizar_hud() -> void:
	var col: Dictionary = Pedido.cfg.get("coleccionable", {})
	_hud.text = "%d / %d %s" % [_puntos, META, col.get("plural", "")]


# ------------------------------------------------------------------ entrada

## Se usa _input y no _unhandled_input a proposito: _unhandled_input solo recibe
## lo que nadie consumio antes, y cualquier Control de la interfaz que quede con
## su mouse_filter por defecto vuelve a tragarse el toque. _input llega siempre.
func _input(evento: InputEvent) -> void:
	var toco := false
	if evento is InputEventScreenTouch and evento.pressed:
		toco = true
	elif evento is InputEventMouseButton and evento.pressed:
		toco = true
	elif evento.is_action_pressed("ui_accept"):
		toco = true
	if not toco:
		return

	match _estado:
		Estado.TITULO:
			_empezar()
		Estado.JUGANDO:
			if _en_suelo:
				_saltar()
		Estado.PERDIO, Estado.GANO:
			_empezar()


## Piloto automatico del modo demo. No pretende jugar bien: solo salta a tiempo
## para que la grabacion muestre el juego funcionando de verdad.
func _jugar_solo() -> void:
	if not _en_suelo:
		return

	# Anticipa segun la velocidad: a mas rapido, hay que saltar antes.
	var aviso := _vel * 0.55
	if _torpe:
		aviso *= randf_range(0.30, 0.85)   # salta tarde, y nunca igual

	# Los obstaculos mandan. Si hay uno cerca no se salta por una estrella, o el
	# salto se gasta y se aterriza justo encima del obstaculo.
	var obstaculo_cerca := false
	for c in _cosas:
		var dx: float = c.position.x - JUGADOR_X
		if dx < 0.0 or dx > _largo_salto() * 1.6:
			continue
		if c.get_meta("tipo", "") == "obstaculo":
			obstaculo_cerca = true
			if dx <= aviso:
				_saltar()
				return

	if obstaculo_cerca:
		return

	for c in _cosas:
		var dx: float = c.position.x - JUGADOR_X
		if dx >= 0.0 and dx <= aviso and c.position.y < SUELO - 130.0:
			_saltar()
			return


func _saltar() -> void:
	_vy = IMPULSO
	_en_suelo = false
	# Un pelin de variacion de tono para que veinte saltos seguidos no suenen a
	# la misma muestra repetida, que es lo que delata a un juego barato.
	_sonido.tocar("salto", randf_range(0.94, 1.06))


## Dibuja las cajas de colision. Solo con --cajas.
class CajasDebug extends Node2D:
	var juego

	func _draw() -> void:
		draw_rect(juego.caja_jugador(), Color(0, 0.7, 1, 0.9), false, 4.0)
		for c: Node2D in juego._cosas:
			var esPremio: bool = c.get_meta("tipo", "") == "premio"
			var col := Color(0.2, 0.9, 0.2, 0.9) if esPremio else Color(1, 0.1, 0.1, 0.9)
			draw_rect(juego.caja_cosa(c), col, false, 4.0)
