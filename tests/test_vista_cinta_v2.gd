extends SceneTree

## Etapa 2 del Motor V2 (docs/motor_v2.md): la vista (VistaV2) elige los
## clips de una vez con lo que busca el cuerpo (CuerposV2Nativos).
## Un jugador parado mira atrás, sale picando 25 m y llega frenando:
## - lo que busca el cuerpo (giro que falta, metros para parar, rapidez) se lee
##   bien desde GDScript;
## - la vista hace Giro_180, Arranque, Correr y Frenada, en ese orden;
## - el pie apoyado casi no patina en ninguno (como DetectorPatinaV2: a menos
##   de 1,5 cm del punto más bajo del pie en ese clip).
## Otro pica y, a su punta, le piden volver: da Media_Vuelta y sigue con
## Correr, sin pasar por Correr_Espaldas ni de costado.

const SEED := 20260930
const PASO := 1.0 / 60.0
const JUGADOR := 3
const PIQUE := 6
const APOYO_M := DetectorPatinaV2.APOYO_M

var fallos := 0


func _init() -> void:
	if not ClassDB.class_exists("CuerposV2Nativos"):
		_ok(false, "la extensión motor_v2 está armada para esta plataforma (motor_v2/bin)")
		print("FALLOS=%d" % fallos)
		quit(1)
		return
	var vista := VistaV2.new()
	vista.size = Vector2(640, 360)
	root.add_child(vista)
	process_frame.connect(_probar.bind(vista), CONNECT_ONE_SHOT)


func _probar(vista: VistaV2) -> void:
	var c: Object = ClassDB.instantiate("CuerposV2Nativos")
	c.configurar(FisicaV2.parametros_cuerpo(), FisicaV2.clips())
	var fisico := FisicaV2.fisico_de({"velocidad": 80.0, "aceleracion": 80.0, "agilidad": 70.0})
	for i in MundoV2.JUGADORES:
		c.agregar(Vector2(-40.0 + 3.0 * i, 0.0), 0.0, fisico)
	var inicio: Vector2 = c.get_pos()[JUGADOR]
	var p3: Jugador3D = vista._jugadores[JUGADOR]
	var medida := {"previo": {}, "suelo": {}, "patina": {}, "metros": {}, "orden": []}
	_pasos(c, vista, 30, medida, JUGADOR)
	c.mirar_a(JUGADOR, inicio + Vector2(0.0, -10.0))
	_ok(absf(absf(c.get_giro_pendiente(JUGADOR)) - PI) < 0.01,
		"mirando atrás le falta media vuelta (%.1f°)" % rad_to_deg(c.get_giro_pendiente(JUGADOR)))
	_pasos(c, vista, 90, medida, JUGADOR)
	var destino := inicio + Vector2(0.0, -25.0)
	c.ir_a(JUGADOR, destino, 1.0, true)
	# Mira más allá del destino: despacio el cuerpo gira hacia donde mira.
	c.mirar_a(JUGADOR, inicio + Vector2(0.0, -40.0))
	_ok(absf(c.get_metros_para_parar(JUGADOR) - 25.0) < 0.01,
		"yendo a parar a 25 m le faltan %.2f m para parar" % c.get_metros_para_parar(JUGADOR))
	_ok(absf(c.get_rapidez_buscada(JUGADOR) - float(fisico["vel_max"])) < 0.01,
		"busca su punta (%.2f m/s)" % c.get_rapidez_buscada(JUGADOR))
	_pasos(c, vista, 480, medida, JUGADOR)
	_ok(c.get_rapidez()[JUGADOR] == 0.0 and c.get_pos()[JUGADOR].distance_to(destino) < 0.01, "llegó parado")
	var orden: Array = medida["orden"]
	var giro := orden.find("Giro_180_Izq") if orden.has("Giro_180_Izq") else orden.find("Giro_180_Der")
	var esperado := [giro, orden.find("Arranque"), orden.find("Correr"), orden.find("Frenada")]
	var en_orden := not esperado.has(-1)
	for k in range(1, esperado.size()):
		en_orden = en_orden and esperado[k] > esperado[k - 1]
	_ok(en_orden, "hace media vuelta, arranca, corre y frena, en ese orden (%s)" % [orden])
	_ok(p3._anim_actual == Cancha3D.ANIM_QUIETO, "termina quieto (%s)" % p3._anim_actual)
	var patina: Dictionary = medida["patina"]
	var metros: Dictionary = medida["metros"]
	for clip in patina:
		if clip.begins_with("Giro_"):
			# En el lugar: se compara con lo que barre un pie que gira con el
			# cuerpo sin clip (radio ~0,11 m, media vuelta: 0,35 m por pie).
			_ok(float(patina[clip]) < 0.3, "%s: el pie apoyado desliza %.2f m en toda la vuelta" % [clip, patina[clip]])
		elif clip in ["Arranque", "Correr", "Frenada"]:
			var r := float(patina[clip]) / maxf(float(metros.get(clip, 0.0)), 0.01)
			_ok(r < 0.15, "%s: el pie apoyado desliza el %.0f%% de lo que avanza el cuerpo (%.2f de %.2f m)"
				% [clip, 100.0 * r, patina[clip], metros.get(clip, 0.0)])
	_media_vuelta(c, vista)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


## A su punta hacia +z, le piden volver a -z (sin frenar en el punto, como
## en los piques del laboratorio).
func _media_vuelta(c: Object, vista: VistaV2) -> void:
	var x: float = c.get_pos()[PIQUE].x
	c.ir_a(PIQUE, Vector2(x, 80.0), 1.0, false)
	var medida := {"previo": {}, "suelo": {}, "patina": {}, "metros": {}, "orden": []}
	_pasos(c, vista, 240, medida, PIQUE)
	c.ir_a(PIQUE, Vector2(x, -80.0), 1.0, false)
	medida["orden"] = []
	_pasos(c, vista, 240, medida, PIQUE)
	var orden: Array = medida["orden"]
	var vuelta := orden.find("Media_Vuelta_Izq") if orden.has("Media_Vuelta_Izq") else orden.find("Media_Vuelta_Der")
	_ok(vuelta >= 0 and orden.find("Correr", vuelta) > vuelta, "a su punta da la media vuelta y sigue corriendo (%s)" % [orden])
	var de_lado := orden.filter(func(a: String) -> bool: return a.begins_with("Correr_Costado") or a == "Correr_Espaldas")
	_ok(de_lado.is_empty(), "no corre de espaldas ni de costado para darse vuelta (%s)" % [de_lado])
	_ok(c.get_vel(PIQUE).y < -0.9 * c.get_rapidez_buscada(PIQUE), "termina corriendo al revés (%.1f m/s)" % c.get_vel(PIQUE).y)
	var p3: Jugador3D = vista._jugadores[PIQUE]
	_ok(absf(wrapf(p3.rotation.y - PI, -PI, PI)) < 0.2, "y el modelo mira hacia donde corre (%.0f°)" % rad_to_deg(p3.rotation.y))
	for clip in medida["patina"]:
		if clip.begins_with("Media_Vuelta"):
			var r := float(medida["patina"][clip]) / maxf(float(medida["metros"].get(clip, 0.0)), 0.01)
			_ok(r < 0.15, "%s: el pie apoyado desliza el %.0f%% de lo que recorre el cuerpo (%.2f de %.2f m)"
				% [clip, 100.0 * r, medida["patina"][clip], medida["metros"][clip]])


## Avanza el cuerpo y la vista, y mide el pie apoyado del jugador j por clip.
## Los cuadros de fundido entre clips no cuentan (DetectorPatinaV2.FUNDIDO).
func _pasos(c: Object, vista: VistaV2, n: int, m: Dictionary, j: int) -> void:
	var p3: Jugador3D = vista._jugadores[j]
	for k in n:
		c.avanzar()
		vista.dibujar_cuerpos(c, 1.0, PASO, Vector2.ZERO)
		var clip := p3._anim_actual
		if (m["orden"] as Array).is_empty() or m["orden"][-1] != clip:
			(m["orden"] as Array).append(clip)
		m["metros"][clip] = float(m["metros"].get(clip, 0.0)) + float(c.get_rapidez()[j]) * PASO
		for pie in DetectorPatinaV2.PIES:
			var q := DetectorPatinaV2.ancla_de(p3, pie)
			var alto := q.y - p3.global_position.y
			if p3._mezcla >= 1.0:
				m["suelo"][clip] = minf(float(m["suelo"].get(clip, INF)), alto)
			var previo: Dictionary = m["previo"]
			if previo.has(pie) and p3._mezcla >= 1.0:
				var antes: Vector3 = previo[pie]
				if minf(alto, antes.y - p3.global_position.y) <= float(m["suelo"][clip]) + APOYO_M:
					m["patina"][clip] = float(m["patina"].get(clip, 0.0)) + Vector2(q.x - antes.x, q.z - antes.z).length()
			previo[pie] = q


func _ok(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion:
		fallos += 1
