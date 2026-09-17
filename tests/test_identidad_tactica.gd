extends SceneTree

const SEED := 76104
var fallos := 0

func _init() -> void:
	_probar_transiciones()
	_probar_carril()
	_probar_decisiones()
	_probar_desdoble()
	_probar_llegada_al_area()
	_probar_carrera()
	_probar_presion()
	_probar_reproduccion()
	print("FALLOS=%d" % fallos)
	quit(1 if fallos > 0 else 0)

func _comprobar(condicion: bool, texto: String) -> void:
	if not condicion: fallos += 1
	print(("OK: " if condicion else "FALLA: ") + texto)

func _estado() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var a := Team.generar("A", rng, 0)
	var b := Team.generar("B", rng, 400)
	a.formacion = "4-2-3-1"
	b.formacion = "4-2-3-1"
	a.reset_partido()
	b.reset_partido()
	a.local = true
	b.local = false
	var s := MotorEspacial.crear_estado(a, b, rng)
	for e in s.jugadores.values():
		if not e.equipo_local:
			e.pos = Vector2(45, float(e.jugador_id % 7) * 4.0 - 12.0)
	return s

func _jugador(s: Dictionary, rol: String, local := true) -> Dictionary:
	for e in s.jugadores.values():
		if e.rol == rol and e.equipo_local == local:
			return e
	return {}

func _probar_transiciones() -> void:
	var s := _estado()
	var mio := _jugador(s, "MC")
	var rival := _jugador(s, "MC", false)
	s.pelota.poseedor_id = rival.clave
	MotorEspacial._actualizar_transicion(s)
	s.pelota.poseedor_id = mio.clave
	MotorEspacial._actualizar_transicion(s)
	var vence: int = s.transicion_hasta
	_comprobar(MotorEspacial._transicion(s, true) > 0.9, "recuperar abre la carrera de transicion")
	s.tick += 3
	s.pelota.poseedor_id = _jugador(s, "EXT").clave
	MotorEspacial._actualizar_transicion(s)
	_comprobar(s.transicion_hasta == vence, "un pase propio no renueva la transicion")
	s.tick = vence + 1
	_comprobar(MotorEspacial._transicion(s, true) == 0, "la transicion caduca aunque siga la posesion")
	s.detenido = 10
	MotorEspacial._actualizar_transicion(s)
	_comprobar(s.transicion_hasta == -1, "una interrupcion cancela la transicion")

func _probar_carril() -> void:
	var s := _estado()
	var e := _jugador(s, "MC")
	e.pos = Vector2.ZERO
	e.vel = Vector2.ZERO
	var rival := _jugador(s, "DFC", false)
	rival.pos = Vector2(9, 0)
	var destino := MotorEspacial._corredor_elegido(s, e)
	_comprobar(absf(destino.y) > 3.0 and destino.x > 0.0, "el conductor rodea el carril central tapado")
	_comprobar(MotorEspacial._corredor_elegido(s, e) == destino, "mantiene el rumbo entre decisiones")
	e.erase("corredor_hasta")
	e.pos = Vector2(0, 25)
	rival.pos = Vector2(45, 0)
	destino = MotorEspacial._corredor_elegido(s, e)
	_comprobar(absf(destino.y - e.pos.y) < 1.0, "con banda libre corre por afuera antes de cerrarse")

func _masa(s: Dictionary, e: Dictionary, tipo: String) -> float:
	var j := MotorEspacial._dict_jugador(s, s.home, e.jugador_id)
	var opciones := MotorEspacial.evaluar_opciones(s, e, j)
	var temp := MotorEspacial.temperatura(j, MotorEspacial.presion_normalizada(s, e.pos, true))
	var maxima := -INF
	for o in opciones: maxima = maxf(maxima, o.utilidad)
	var total := 0.0
	var elegidas := 0.0
	for o in opciones:
		var peso := exp((o.utilidad - maxima) / temp)
		total += peso
		if o.tipo == tipo: elegidas += peso
	return elegidas / total

func _probar_decisiones() -> void:
	var s := _estado()
	var e := _jugador(s, "MC")
	e.pos = Vector2.ZERO
	s.pelota.pos = e.pos
	s.pelota.poseedor_id = e.clave
	var comp := _jugador(s, "MCO")
	comp.pos = Vector2(8, 8)
	s.home.estilo = "Tiki taka"
	var tiki := _masa(s, e, "pase")
	s.home.estilo = "Contragolpe"
	var contra := _masa(s, e, "pase")
	_comprobar(tiki > contra + 0.1, "con el mismo plantel, Tiki taka elige mas el pase corto")
	var j := MotorEspacial._dict_jugador(s, s.home, e.jugador_id)
	j.atributos.fuerza = 100
	e.pos = Vector2(0, 24)
	e.erase("corredor_hasta")
	comp.pos = Vector2(-1, -24)
	s.pelota.pos = e.pos
	_jugador(s, "DFC", false).pos = Vector2(3, 24)
	var hay_cambio := false
	for o in MotorEspacial.evaluar_opciones(s, e, j):
		if o.tipo == "pase_largo" and o.objetivo_id == comp.clave:
			hay_cambio = true
	_comprobar(hay_cambio, "un carril tapado habilita cambiar de frente sin ganar metros")
	# El pase atras al area debe distinguirse de regalar terreno en campo propio.
	e.pos = Vector2(43, 16)
	e.erase("corredor_hasta")
	comp.pos = Vector2(35, 0)
	_jugador(s, "DFC", false).pos = Vector2(-20, -20)
	var hay_devolucion := false
	for o in MotorEspacial.evaluar_opciones(s, e, j):
		if o.tipo == "pase" and o.objetivo_id == comp.clave:
			hay_devolucion = bool(o.detalle.get("pase_atras_al_area", false))
	_comprobar(hay_devolucion, "desde el fondo reconoce la devolucion al rematador")

func _probar_desdoble() -> void:
	var s := _estado()
	s.home.estilo = "Tiki taka"
	var extremo := _jugador(s, "EXT")
	var lateral := _jugador(s, "LAT")
	var lado := signf(float(lateral.base.y))
	extremo.pos = Vector2(15, lado * 20.0)
	s.pelota.pos = extremo.pos
	s.pelota.poseedor_id = extremo.clave
	var objetivo := MotorEspacial._buscar_apoyo(s, lateral, s.home, Vector2(0, lado * 20.0))
	_comprobar(objetivo.x > extremo.pos.x and absf(objetivo.y) > absf(extremo.pos.y), "el lateral de ese lado pasa por fuera del extremo")

func _probar_presion() -> void:
	var s := _estado()
	var rival := _jugador(s, "MC", false)
	rival.pos = Vector2.ZERO
	s.pelota.pos = rival.pos
	s.pelota.poseedor_id = rival.clave
	var distancia := 3.0
	for e in s.jugadores.values():
		if e.equipo_local and e.rol != "ARQ":
			e.pos = Vector2(-distancia, distancia * 0.3)
			distancia += 2
	_jugador(s, "EXT", false).pos = Vector2(8, 8)
	s.home.estilo = "Presión alta"
	var presion := MotorEspacial._perseguidores(s, false)
	_comprobar(presion.size() == 3, "presion alta activa un tercer jugador cercano")
	var primero: Dictionary = s.jugadores[presion[0]]
	var segundo: Dictionary = s.jugadores[presion[1]]
	_comprobar(MotorEspacial._objetivo_de_presion(s, primero) != MotorEspacial._objetivo_de_presion(s, segundo), "uno presiona y otro tapa la linea de pase")
	s.home.estilo = "Contragolpe"
	_comprobar(MotorEspacial._perseguidores(s, false).size() <= 2, "contragolpe conserva gente en el bloque")

func _probar_llegada_al_area() -> void:
	for local in [true, false]:
		var s := _estado()
		var extremo := _jugador(s, "EXT", local)
		var signo := 1.0 if local else -1.0
		var lado := signf(float(extremo.base.y))
		var poseedor := _jugador(s, "LAT", local)
		poseedor.pos = Vector2(40 * signo, -25 * lado)
		s.pelota.pos = poseedor.pos
		s.pelota.poseedor_id = poseedor.clave
		var equipo := MotorEspacial._equipo_de(s, local)
		var objetivo := MotorEspacial._buscar_apoyo(s, extremo, equipo, Vector2(30 * signo, 25 * lado))
		_comprobar(objetivo.x * signo >= 36 and absf(objetivo.y) <= 13, "el extremo opuesto llega al area, local=%s" % local)

func _probar_carrera() -> void:
	var distancias := []
	for estilo in ["Tiki taka", "Contragolpe"]:
		var s := _estado()
		s.home.estilo = estilo
		var e := _jugador(s, "EXT")
		e.pos = Vector2(0, 25)
		e.rapidez = e.vel_max
		s.transicion_local = true
		s.transicion_hasta = s.tick + int(MotorEspacial.SEGUNDOS_TRANSICION / MotorEspacial.TICK_SEG)
		var inicio: Vector2 = e.pos
		MotorEspacial._conducir(s, e)
		distancias.append(e.pos.distance_to(inicio))
	_comprobar(distancias[1] > distancias[0], "en una recuperacion libre, contragolpe acelera mas con el mismo jugador")
	var s := _estado()
	s.home.estilo = "Contragolpe"
	var mco := _jugador(s, "MCO")
	mco.pos = Vector2(0, 0)
	s.transicion_local = true
	s.transicion_hasta = s.tick + int(MotorEspacial.SEGUNDOS_TRANSICION / MotorEspacial.TICK_SEG)
	var apoyo := MotorEspacial._buscar_apoyo(s, mco, s.home, mco.pos)
	_comprobar(apoyo.x > mco.pos.x + 4.0, "tras recuperar, el MCO tambien rompe hacia adelante")

func _probar_reproduccion() -> void:
	var resultados := []
	for animar in [false, true]:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED
		var a := Team.generar("A", rng, 0)
		var b := Team.generar("B", rng, 400)
		a.estilo = "Tiki taka"
		b.estilo = "Contragolpe"
		resultados.append(MotorEspacial.simular(a, b, rng, animar))
	_comprobar(resultados[0].eventos == resultados[1].eventos and resultados[0].stats == resultados[1].stats, "generar fotogramas no altera el partido ni sus decisiones")
	var fotogramas: Array = resultados[1].fotogramas
	_comprobar(not fotogramas.is_empty() and fotogramas.back().jugadores[0].has("recorrido"), "la animacion recibe la distancia real para la zancada")
