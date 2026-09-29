class_name MuestraAnimaciones3D
extends Control

## Partido de muestra: una seguidilla de jugadas REALES del motor donde
## aparecen todas las animaciones del partido 3D. Cada jugada sale de un
## partido simulado o del Laboratorio (que monta las raras: chilena, los
## cinco regates, palomita...). Se reproduce con el mismo VistaPartido y
## VistaCancha3D del prototipo. No lo llama nadie: se abre a mano (F6).
##
## Muestra una jugada por vez y la repite en loop, para revisarlas de a una:
## ← → cambia de jugada, ↑ ↓ la velocidad, espacio pausa y R la reinicia.
## `-- clip=N` arranca en la jugada N (1..29).

## Semilla base de los partidos: la misma de PrototipoVista.
const SEMILLA_PARTIDOS := PrototipoVista.SEMILLA

## Trozos de partidos simulados: [rótulo, semilla + n, fotograma de la
## acción] y, si hace falta, [..., cuadros antes, cuadros después]. Medidos con scratch/_diag_acciones_semillas.gd y _diag_amague.gd:
## en 40 partidos al azar estas acciones sí aparecen solas.
const TROZOS := [
	["Pase y control con el pie", 0, 95],
	["Barrida", 0, 19],
	["Control con el pecho", 0, 357],
	["Caída", 0, 510],
	# Taco de primera en juego corrido. El del tick 777 era el primer toque
	# después de un cambio: la pelota aparecía en otro lado y la cámara
	# llegaba tarde (buscado con scratch/_buscar_taco.gd).
	["Taco", 0, 816, 6, 8],
	["Bloqueo de un remate", 1, 451],
	["El arquero la agarra y la saca con la mano", 2, 897],
	["Amague de centro", 63, 906],
	# El saque_arco del Laboratorio el motor lo registra como "patea"; en
	# partido sí sale como saque de arco.
	["Saque de arco", 0, 435],
]
## Cuadros antes y después de la acción en cada trozo (4 por segundo).
const ANTES := 10
const DESPUES := 18

## Jugadas del Laboratorio: [rótulo, clave]. Las que en 40 partidos no
## salieron nunca (chilena, amague, ruleta, globito y elástica) o salen poco.
const LABORATORIO := [
	["Centro y cabezazo", "cabezazo"],
	["Centro y volea", "volea"],
	["Centro y chilena", "chilena"],
	["Centro y palomita", "palomita"],
	["Regate: croqueta", "regate_croqueta"],
	["Regate: bicicleta", "regate_bicicleta"],
	["Regate: ruleta", "regate_ruleta"],
	["Regate: globito", "regate_globito"],
	["Regate: elástica", "regate_elastica"],
	["Lateral", "lateral"],
	["Lesión", "lesion"],
	["Gol, estirada y festejo", "gol"],
]
## Pelota parada y oficiales, al final (así no cambian los números de las
## anteriores). Mismo formato que TROZOS. Buscados con
## scratch/_buscar_pelota_parada.gd, _buscar_offside.gd y _buscar_barrera.gd.
## Las de texto en el segundo lugar son del Laboratorio con esa semilla y ese
## tramo: [rótulo, clave, semilla, desde, hasta] (scratch/_buscar_tiro_libre.gd).
const PELOTA_PARADA := [
	["Tiro libre: gol por arriba de la barrera", "tiro_libre", 12, 14, 34],
	["Tiro libre: pega en la barrera", "tiro_libre", 2, 14, 32],
	["Corner", 1, 587, 0, 30],
	["Tarjeta roja", 0, 1004, 4, 30],
	["Offside: el asistente levanta la bandera", 15, 931, 6, 8],
	["Cambio: el cuarto árbitro con el tablero", 0, 737, 0, 20],
	["Tiro con efecto: se acomoda, la curva y gol", "tiro_efecto", 30, 0, 16],
	# Agarra en el 326 y la despeja de volea en el 331 (scratch/_diag_arquero_resumen.gd).
	["El arquero la agarra y la saca de volea", 3, 326, 8, 20],
]
## Tope de cada jugada del Laboratorio (4 por segundo): el clip sigue un
## rato después de la jugada y con esto la muestra no se alarga de más.
const TOPE_LABORATORIO := 56

## Velocidades de revisión: la lenta sirve para mirar el contacto.
const VELOCIDADES := [0.25, 0.5, 1.0]

## Sin loop recorre todas las jugadas de corrido (lo usa la medición
## tests/_diag_contactos_3d.gd, que mueve la posición a mano).
var en_loop := true
var reproductor: VistaPartido
var _rotulos: Array = []
var _cartel: Label
var _ayuda: Label
var _clip := 0
var _velocidad := 2


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reproductor = VistaPartido.new()
	add_child(reproductor)
	_cambiar_a_3d()
	var lista := _armar_lista()
	var colores := ColoresClub.par("Atlético Prueba", "Deportivo Banco")
	reproductor.iniciar(lista, colores[0], colores[1], "Muestra", "3D", {}, "regular")
	_cartel = Label.new()
	_cartel.add_theme_font_size_override("font_size", 30)
	_cartel.add_theme_color_override("font_outline_color", Color.BLACK)
	_cartel.add_theme_constant_override("outline_size", 10)
	_cartel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_cartel.position.y = 150
	_cartel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_cartel)
	_ayuda = Label.new()
	_ayuda.add_theme_font_size_override("font_size", 18)
	_ayuda.add_theme_color_override("font_outline_color", Color.BLACK)
	_ayuda.add_theme_constant_override("outline_size", 6)
	_ayuda.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_ayuda.position.y = 195
	_ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_ayuda)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("clip="):
			_clip = clampi(int(arg.trim_prefix("clip=")) - 1, 0, _rotulos.size() - 1)
	_ir_al_clip(_clip)
	reproductor.posicion = float(_rotulos[_clip][0])
	print("[muestra 3d] %d jugadas, %d fotogramas" % [_rotulos.size(), lista.size()])
	# Control: qué acciones con animación 3D trae la muestra y cuáles no.
	var hay := {}
	for f in lista:
		for a in f.get("acciones", []):
			hay[str(a["accion"])] = true
		if not f.get("lateral_preparacion", {}).is_empty():
			hay["lateral_prepara"] = true
	var faltan := VistaCancha3D.ANIM_DE_ACCION.keys().filter(func(k): return not hay.has(k))
	print("[muestra 3d] acciones: ", hay.keys())
	print("[muestra 3d] sin mostrar: ", faltan)


func _process(_delta: float) -> void:
	# Al llegar al último cuadro de la jugada vuelve a su primero. El cuadro
	# de sobra del final (ver _armar_lista) evita que VistaPartido la dé
	# por terminada antes.
	if not en_loop:
		return
	if reproductor.posicion >= float(_fin_del_clip(_clip) - 1):
		_ir_al_clip(_clip)
	_cartel.text = "%d/%d  %s" % [_clip + 1, _rotulos.size(), _rotulos[_clip][1]]
	_ayuda.text = "← →  jugada    ↑ ↓  velocidad x%s    espacio  pausa    R  reiniciar%s" % [
		str(VELOCIDADES[_velocidad]), "    (EN PAUSA)" if reproductor.pausado else ""]
	for etiqueta in [_cartel, _ayuda]:
		etiqueta.size.x = size.x
		etiqueta.position.x = 0


func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey and evento.pressed and not evento.echo):
		return
	match evento.keycode:
		KEY_RIGHT:
			_ir_al_clip((_clip + 1) % _rotulos.size())
		KEY_LEFT:
			_ir_al_clip((_clip - 1 + _rotulos.size()) % _rotulos.size())
		KEY_UP:
			_velocidad = mini(_velocidad + 1, VELOCIDADES.size() - 1)
		KEY_DOWN:
			_velocidad = maxi(_velocidad - 1, 0)
		KEY_SPACE:
			reproductor.pausado = not reproductor.pausado
		KEY_R:
			_ir_al_clip(_clip)
		_:
			return
	reproductor.velocidad = VELOCIDADES[_velocidad]
	get_viewport().set_input_as_handled()


## Salta al primer cuadro de la jugada `n` y limpia lo que VistaPartido
## arrastra de la vuelta anterior (relato y festejo del gol), así cada
## vuelta se ve igual que la primera.
func _ir_al_clip(n: int) -> void:
	_clip = n
	var desde := int(_rotulos[n][0])
	reproductor.posicion = float(desde)
	reproductor._idx_narrado = desde
	reproductor._relato_restante = 0.0
	reproductor._festejo_restante = 0.0
	reproductor._parpadeo_restante = 0.0
	reproductor._idx_congelado = -1
	reproductor._festejo_grupo.clear()
	reproductor.hud.relato = ""
	reproductor.hud.festejo = 0.0
	var f: Dictionary = reproductor.fotogramas[desde]
	reproductor.vista.camara.saltar_a(Vector2(f["pelota"]["x"], f["pelota"]["y"]), reproductor.size)


func _fin_del_clip(n: int) -> int:
	if n + 1 < _rotulos.size():
		return int(_rotulos[n + 1][0])
	return reproductor.fotogramas.size() - 1


## Las jugadas se eligieron (y se revisaron una por una) con los partidos que
## daba el motor sin la frenada al llegar, el giro con inercia ni el arranque
## (fisica.frenada, giro_acel, arranque_extra). Con eso los partidos salen
## distintos y el taco del tick 816 ya no es un taco: la muestra los arma con
## la física de entonces y la deja como estaba.
const FISICA_DE_LA_MUESTRA := {"frenada": 0.0, "giro_acel": 0.0, "arranque_extra": 0.0, "un_corte_por_vuelo": 0, "cambio_por_abajo": 0, "arquero_tendido_ticks": 0, "desvio_lo_toca_el_defensor": 0, "cambio_de_lado": 0}


func _armar_lista() -> Array:
	var fisica: Dictionary = MotorEspacial.pesos()["fisica"]
	var antes := {}
	for clave in FISICA_DE_LA_MUESTRA:
		antes[clave] = fisica.get(clave, null)
		fisica[clave] = FISICA_DE_LA_MUESTRA[clave]
	var lista := _armar_lista_con_la_fisica_de_la_muestra()
	for clave in antes:
		if antes[clave] == null:
			fisica.erase(clave)
		else:
			fisica[clave] = antes[clave]
	return lista


func _armar_lista_con_la_fisica_de_la_muestra() -> Array:
	var lista := []
	var partidos := {}
	for trozo in TROZOS:
		var n := int(trozo[1])
		if not partidos.has(n):
			var rng := RandomNumberGenerator.new()
			rng.seed = SEMILLA_PARTIDOS + n
			var local := Team.generar("Atlético Prueba", rng)
			var visita := Team.generar("Deportivo Banco", rng, 1000)
			partidos[n] = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
		var fotos: Array = partidos[n]
		var antes := int(trozo[3]) if trozo.size() > 3 else ANTES
		var despues := int(trozo[4]) if trozo.size() > 4 else DESPUES
		var desde := maxi(0, int(trozo[2]) - antes)
		var hasta := mini(fotos.size(), int(trozo[2]) + despues)
		_agregar(lista, str(trozo[0]), fotos.slice(desde, hasta))
	for jugada in LABORATORIO:
		# Como el Laboratorio del juego: equipos propios y semilla fija, así
		# cada jugada sale siempre igual.
		var rng := RandomNumberGenerator.new()
		rng.seed = Laboratorio.SEMILLA
		var casa := Team.generar("Atlético Prueba", rng)
		var visita := Team.generar("Deportivo Banco", rng, 1000)
		var r := Laboratorio.generar(str(jugada[1]), casa, visita, rng)
		var fotos: Array = r["fotogramas"]
		if str(jugada[1]) == "regate_elastica":
			fotos = _con_carrera(fotos, "regate_elastica")
		_agregar(lista, str(jugada[0]), fotos.slice(0, mini(fotos.size(), TOPE_LABORATORIO)))
	for trozo in PELOTA_PARADA:
		if trozo[1] is String:
			var rng_l := RandomNumberGenerator.new()
			rng_l.seed = int(trozo[2])
			var casa_l := Team.generar("Atlético Prueba", rng_l)
			var visita_l := Team.generar("Deportivo Banco", rng_l, 1000)
			var fotos_l: Array = Laboratorio.generar(str(trozo[1]), casa_l, visita_l, rng_l)["fotogramas"]
			var tramo: Array = fotos_l.slice(int(trozo[3]), mini(fotos_l.size(), int(trozo[4])))
			if str(trozo[1]) == "tiro_efecto":
				tramo = _con_acomodo(tramo)
			# La falta queda antes del tramo: sin ella el 3D no arma la barrera.
			var faltas := []
			for f in fotos_l.slice(0, int(trozo[3])):
				faltas.append_array((f.get("eventos", []) as Array).filter(func(e): return str(e.get("tipo", "")) == "falta"))
			if not faltas.is_empty() and not tramo.is_empty():
				var primero: Dictionary = (tramo[0] as Dictionary).duplicate()
				primero["eventos"] = (primero.get("eventos", []) as Array) + [faltas[-1]]
				tramo[0] = primero
			_agregar(lista, str(trozo[0]), tramo)
			continue
		var n := int(trozo[1])
		if not partidos.has(n):
			var rng := RandomNumberGenerator.new()
			rng.seed = SEMILLA_PARTIDOS + n
			var local := Team.generar("Atlético Prueba", rng)
			var visita := Team.generar("Deportivo Banco", rng, 1000)
			partidos[n] = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
		var fotos: Array = partidos[n]
		var desde := maxi(0, int(trozo[2]) - int(trozo[3]))
		var hasta := mini(fotos.size(), int(trozo[2]) + int(trozo[4]))
		_agregar(lista, str(trozo[0]), fotos.slice(desde, hasta))
	# Un cuadro de sobra que no es de ninguna jugada: la última también
	# vuelve a empezar antes de que VistaPartido llegue al final.
	lista.append(lista[-1])
	return lista


## Solo para la muestra: el Laboratorio arranca el regate con el jugador
## parado y después lo deja quieto (y a los 9 ticks lo saca de la cancha). En
## un partido llega corriendo y sigue: se le agrega la carrera antes y la
## salida después, en línea recta a la velocidad del regate. El resto de los
## jugadores queda como en el primer cuadro del regate.
const CARRERA_TICKS := 8
const SALIDA_TICKS := 10
const CARRERA_M_POR_TICK := 1.3


func _con_carrera(fotos: Array, accion: String) -> Array:
	var e := -1
	var id := -1
	for i in fotos.size():
		for a in fotos[i].get("acciones", []):
			if str(a["accion"]) == accion:
				e = i
				id = int(a["clave"])
				break
		if e >= 0:
			break
	if e < 0:
		return fotos
	var fin := e + int(MotorEspacial.duracion_regate(MotorEspacial.tipo_regate_de_accion(accion))) - 1
	var base: Dictionary = fotos[e]
	var j0 := VistaPartido._jugador_en(base, id)
	var frente := Vector2(float(j0.get("ox", 1.0)), float(j0.get("oy", 0.0))).normalized()
	var salida: Array = []
	# Llega corriendo: CARRERA_TICKS cuadros antes, sin acciones.
	for k in range(CARRERA_TICKS, 0, -1):
		var f: Dictionary = base.duplicate(true)
		f["acciones"] = []
		f["eventos"] = []
		f["tick"] = int(base.get("tick", 0)) - k
		_mover(f, id, -frente * CARRERA_M_POR_TICK * float(k))
		salida.append(f)
	var regate: Array = fotos.slice(e, fin + 1)
	regate[0] = (regate[0] as Dictionary).duplicate()
	regate[0]["reubicacion"] = false
	salida.append_array(regate)
	# Sigue corriendo derecho: el Laboratorio lo dejaba quieto.
	var ultimo: Dictionary = fotos[fin]
	for k in range(1, SALIDA_TICKS + 1):
		var f: Dictionary = ultimo.duplicate(true)
		f["acciones"] = []
		f["eventos"] = []
		f["tick"] = int(ultimo.get("tick", 0)) + k
		_mover(f, id, frente * CARRERA_M_POR_TICK * float(k))
		salida.append(f)
	return salida


## Solo para la muestra: el Laboratorio arranca el tiro con efecto con el
## jugador ya parado sobre la pelota. En un partido entra en diagonal
## llevándola y se acomoda: acá llega conduciendo desde atrás a la izquierda
## del remate (el derecho que curva con el interno se abre para ese lado) y
## frena los últimos ticks. El resto queda como en el cuadro del remate.
const ACOMODO_ANGULO_GRADOS := 25.0
const ACOMODO_PASOS_M := [1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.0, 0.8, 0.6]
const ACOMODO_PELOTA_ADELANTE_M := 0.5


func _con_acomodo(fotos: Array) -> Array:
	if fotos.is_empty():
		return fotos
	var base: Dictionary = fotos[0]
	var id := -1
	for a in base.get("acciones", []):
		if str(a["accion"]) == MotorEspacial.ACCION_PATEA:
			id = int(a["clave"])
	var tr = base["pelota"].get("trayectoria", {})
	if id < 0 or not (tr is Dictionary) or tr.is_empty():
		return fotos
	var bola := Vector2(base["pelota"]["x"], base["pelota"]["y"])
	var tiro := (Vector2(tr["control"]["x"], tr["control"]["y"]) - bola).normalized()
	# Hacia la derecha del remate: viene de atrás a la izquierda.
	var derecha := Vector2(-tiro.y, tiro.x)
	var ang := deg_to_rad(ACOMODO_ANGULO_GRADOS)
	var rumbo := (tiro * cos(ang) + derecha * sin(ang)).normalized()
	# Metros hasta la pelota del remate en cada cuadro de la llegada.
	var distancias: Array = []
	var atras := 0.0
	for i in range(ACOMODO_PASOS_M.size() - 1, -1, -1):
		atras += float(ACOMODO_PASOS_M[i])
		distancias.push_front(atras)
	var salida: Array = []
	for k in distancias.size():
		var f: Dictionary = base.duplicate(true)
		f["acciones"] = []
		f["eventos"] = []
		f["tick"] = int(base.get("tick", 0)) - distancias.size() + k
		f["pelota"]["trayectoria"] = {}
		f["pelota"]["es_remate"] = false
		f["pelota"]["poseedor_id"] = id
		var pelota: Vector2 = bola - rumbo * float(distancias[k])
		f["pelota"]["x"] = pelota.x
		f["pelota"]["y"] = pelota.y
		for j in f["jugadores"]:
			if int(j["id"]) == id:
				var pie: Vector2 = pelota - rumbo * ACOMODO_PELOTA_ADELANTE_M
				j["x"] = pie.x
				j["y"] = pie.y
				j["ox"] = rumbo.x
				j["oy"] = rumbo.y
		salida.append(f)
	# Como en un partido: el motor graba el remate en el tick en que la pelota
	# ya salió, con la pelota en los pies en el anterior (ahí va el golpe, ver
	# CoreografiaPartido). El Laboratorio lo graba con la pelota todavía en
	# el pie: con la llegada antes, el golpe caía un tick antes de que saliera.
	var quieta: Dictionary = base.duplicate(true)
	quieta["reubicacion"] = false
	var remate_acciones: Array = quieta["acciones"]
	quieta["acciones"] = []
	quieta["pelota"]["trayectoria"] = {}
	quieta["pelota"]["poseedor_id"] = id
	salida.append(quieta)
	var resto: Array = fotos.slice(1)
	if not resto.is_empty():
		var sale: Dictionary = (resto[0] as Dictionary).duplicate()
		sale["acciones"] = (sale.get("acciones", []) as Array) + remate_acciones
		resto[0] = sale
	salida.append_array(resto)
	return salida


## Corre al jugador `id` y a la pelota (la lleva él) en `delta`.
static func _mover(f: Dictionary, id: int, delta: Vector2) -> void:
	for j in f["jugadores"]:
		if int(j["id"]) == id:
			j["x"] = float(j["x"]) + delta.x
			j["y"] = float(j["y"]) + delta.y
			j["recorrido"] = float(j.get("recorrido", 0.0)) + delta.length()
	f["pelota"]["x"] = float(f["pelota"]["x"]) + delta.x
	f["pelota"]["y"] = float(f["pelota"]["y"]) + delta.y


## Cada jugada empieza con `reubicacion`: VistaPartido no interpola desde la
## anterior y la cámara salta, igual que en un saque del medio.
func _agregar(lista: Array, rotulo: String, fotos: Array) -> void:
	if fotos.is_empty():
		return
	var primero: Dictionary = fotos[0].duplicate()
	primero["reubicacion"] = true
	fotos[0] = primero
	_rotulos.append([lista.size(), rotulo])
	lista.append_array(fotos)


func _cambiar_a_3d() -> void:
	var vieja := reproductor.vista
	var nueva := VistaCancha3D.new()
	nueva.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reproductor.add_child(nueva)
	reproductor.move_child(nueva, vieja.get_index())
	reproductor.remove_child(vieja)
	vieja.queue_free()
	reproductor.vista = nueva
