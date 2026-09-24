extends SceneTree

## Lista de transferibles (core/traspasos.gd): el estado de cada jugador
## filtra las ofertas que llegan por el. Correr con:
## godot --headless --script tests/test_traspasos.gd

const SEED := 5151

var fallos := 0
var gs = null


func _init() -> void:
	_test_el_default_es_disponible()
	_test_el_boton_cicla()
	_test_no_disponible_no_recibe_ofertas()
	_test_venta_rapida_llega_mas_barata()
	_test_venta_rapida_tiene_prioridad()
	_test_venta_rapida_no_aguanta_contraoferta()
	_test_el_estado_sobrevive_al_guardado()
	_test_el_que_se_va_no_deja_estado()
	print("\nFALLOS=%d" % fallos)
	if gs != null:
		gs.free()
	quit()


func _ok(texto: String) -> void:
	print("OK: %s" % texto)


func _falla(texto: String) -> void:
	fallos += 1
	print("FALLA: %s" % texto)


func _test_venta_rapida_tiene_prioridad() -> void:
	var p := _partida()
	var mio: Team = p["mio"]
	var id := int(mio.banco[0]["id"])
	var normal := Traspasos.prioridad(mio, id)
	var piso_normal := Traspasos.factor_minimo_oferta(mio, id)
	Traspasos.fijar(mio, id, Traspasos.VENTA_RAPIDA)
	var rapida := Traspasos.prioridad(mio, id)
	var piso_rapida := Traspasos.factor_minimo_oferta(mio, id)
	if rapida > normal and piso_rapida < piso_normal:
		_ok("venta rapida aparece %.1fx mas en el radar de compradores." % (rapida / normal))
	else:
		_falla("venta rapida baja el precio pero no aumenta la prioridad.")


## GameState es autoload y en un --script no existe: se instancia a mano,
## igual que en test_ofertas.
func _partida(division := 4) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	if gs != null:
		gs.free()
	gs = load("res://game/game_state.gd").new()
	gs.piramide = piramide
	gs.rng = rng
	gs.temporada_actual = 1
	gs.division_jugador = division
	gs.equipo_jugador = piramide.divisiones[division].equipos[0]
	gs._sembrar_presupuestos()
	gs.equipo_jugador.caja["fichajes"] = 500000000.0
	gs.dia_absoluto = Calendario.primer_dia_de_mercado()
	return {"piramide": piramide, "rng": rng, "mio": gs.equipo_jugador,
		"otro": piramide.divisiones[division].equipos[1]}


func _test_el_default_es_disponible() -> void:
	print("=== Sin tocar nada, todos estan disponibles ===")
	var p := _partida()
	var mio: Team = p["mio"]
	var todos := true
	for j in mio.jugadores + mio.banco:
		if Traspasos.estado(mio, int(j["id"])) != Traspasos.DISPONIBLE:
			todos = false
	if todos and mio.traspasos.is_empty():
		_ok("los %d del plantel arrancan disponibles y el dict esta vacio." % (
			mio.jugadores.size() + mio.banco.size()))
	else:
		_falla("traspasos=%s todos_disponibles=%s" % [mio.traspasos, todos])


func _test_el_boton_cicla() -> void:
	print("\n=== El boton cicla disponible, no disponible, venta rapida ===")
	var p := _partida()
	var mio: Team = p["mio"]
	var id := int(mio.jugadores[3]["id"])
	var recorrido := []
	for _i in range(4):
		Traspasos.fijar(mio, id, Traspasos.siguiente(Traspasos.estado(mio, id)))
		recorrido.append(Traspasos.estado(mio, id))
	var esperado := [Traspasos.NO_DISPONIBLE, Traspasos.VENTA_RAPIDA,
		Traspasos.DISPONIBLE, Traspasos.NO_DISPONIBLE]
	# Volver a disponible tiene que BORRAR la entrada: el default no se guarda.
	if recorrido == esperado:
		_ok("recorrido %s." % [recorrido])
	else:
		_falla("recorrido %s, esperaba %s." % [recorrido, esperado])


func _test_no_disponible_no_recibe_ofertas() -> void:
	print("\n=== Por un no disponible no llega ninguna oferta ===")
	var p := _partida()
	var mio: Team = p["mio"]
	var rng: RandomNumberGenerator = p["rng"]
	# Todo el plantel cerrado menos uno: si el filtro no anduviera, las
	# ofertas caerian repartidas por todos.
	# El abierto es el de mejor media: generar_entrantes solo sortea a los
	# que destacan en el club. Con jugadores[0] el test dependía de que el
	# primero del plantel destacara, y con la semilla actual no destaca.
	var abierto := -1
	var mejor_media := -1.0
	for j in mio.todos_los_jugadores():
		if float(j["media"]) > mejor_media:
			mejor_media = float(j["media"])
			abierto = int(j["id"])
	for j in mio.jugadores + mio.banco:
		var id := int(j["id"])
		if id != abierto:
			Traspasos.fijar(mio, id, Traspasos.NO_DISPONIBLE)

	var recibidas := 0
	var por_otro := 0
	for _i in range(120):
		for o in Ofertas.generar_entrantes(mio, p["piramide"], rng, 7, 4):
			recibidas += 1
			if int(o["jugador_id"]) != abierto:
				por_otro += 1
		mio.ofertas.clear()
	if recibidas > 5 and por_otro == 0:
		_ok("%d ofertas y todas por el unico disponible." % recibidas)
	else:
		_falla("%d ofertas, %d por alguien cerrado." % [recibidas, por_otro])


func _test_venta_rapida_llega_mas_barata() -> void:
	print("\n=== En venta rapida ofrecen entre 40 y 50 por ciento menos ===")
	# Mismo plantel y misma semilla: la unica diferencia entre las dos
	# corridas es el estado. El factor sale de un randf_range extra, asi
	# que se compara el promedio de monto/valor y no oferta contra oferta.
	var normal := _promedio_sobre_valor(false)
	var rapida := _promedio_sobre_valor(true)
	if normal <= 0.0 or rapida <= 0.0:
		_falla("no llegaron ofertas para medir (normal=%.2f rapida=%.2f)." % [normal, rapida])
		return
	var proporcion := rapida / normal
	# 0.50..0.60 del monto normal, con margen por el ruido de la muestra.
	if proporcion > 0.45 and proporcion < 0.68:
		_ok("normal %.2f del valor, venta rapida %.2f: paga el %.0f por ciento." % [
			normal, rapida, proporcion * 100.0])
	else:
		_falla("normal %.2f, rapida %.2f: proporcion %.2f fuera de 0.45-0.68." % [
			normal, rapida, proporcion])


## Promedio de monto/valor de las ofertas entrantes, con todo el plantel
## en el mismo estado.
func _promedio_sobre_valor(venta_rapida: bool) -> float:
	var p := _partida()
	var mio: Team = p["mio"]
	var rng: RandomNumberGenerator = p["rng"]
	if venta_rapida:
		for j in mio.jugadores + mio.banco:
			Traspasos.fijar(mio, int(j["id"]), Traspasos.VENTA_RAPIDA)

	var suma := 0.0
	var n := 0
	for _i in range(300):
		for o in Ofertas.generar_entrantes(mio, p["piramide"], rng, 7, 4):
			var id := int(o["jugador_id"])
			var donde := Mercado.ubicar(mio, id)
			var valor := ValorJugador.calcular(
				donde["jugador"], mio.animo.get(id, 50.0), mio.contratos.get(id, 3))
			if valor > 0.0:
				suma += float(o["monto"]) / valor
				n += 1
		mio.ofertas.clear()
	return suma / float(n) if n > 0 else 0.0


func _test_venta_rapida_no_aguanta_contraoferta() -> void:
	print("\n=== Al de venta rapida no le podes sacar mas plata ===")
	var p := _partida()
	var mio: Team = p["mio"]
	var rng: RandomNumberGenerator = p["rng"]
	var jugador: Dictionary = mio.jugadores[7]
	var id := int(jugador["id"])
	var comprador: Team = p["piramide"].divisiones[0].equipos[0]
	comprador.caja["fichajes"] = 5000000000.0
	var tasacion := ValorJugador.calcular(
		jugador, mio.animo.get(id, 50.0), mio.contratos.get(id, 3))
	# Justo arriba del tope de la venta rapida y bien abajo del normal.
	var pedido := tasacion * 1.20

	var estados := {}
	for estado in [Traspasos.DISPONIBLE, Traspasos.VENTA_RAPIDA]:
		Traspasos.fijar(mio, id, estado)
		mio.ofertas.clear()
		var oferta := Ofertas.nueva(1, comprador.nombre, jugador, tasacion * 0.8, true, rng)
		mio.ofertas.append(oferta)
		Ofertas.contraofertar(oferta, pedido, rng)
		Ofertas.avanzar(mio, 30, p["piramide"], rng, 1, 4)
		estados[estado] = str(oferta["estado"])

	if estados[Traspasos.DISPONIBLE] == Ofertas.ACUERDO_CLUB \
			and estados[Traspasos.VENTA_RAPIDA] != Ofertas.ACUERDO_CLUB:
		_ok("pidiendo 1.20x: disponible cierra, venta rapida queda en %s." % [
			estados[Traspasos.VENTA_RAPIDA]])
	else:
		_falla("disponible=%s venta_rapida=%s" % [
			estados[Traspasos.DISPONIBLE], estados[Traspasos.VENTA_RAPIDA]])


func _test_el_estado_sobrevive_al_guardado() -> void:
	print("\n=== El estado sobrevive a guardar y cargar ===")
	var p := _partida()
	var mio: Team = p["mio"]
	var id_rapida := int(mio.jugadores[2]["id"])
	var id_cerrado := int(mio.banco[0]["id"])
	Traspasos.fijar(mio, id_rapida, Traspasos.VENTA_RAPIDA)
	Traspasos.fijar(mio, id_cerrado, Traspasos.NO_DISPONIBLE)

	var vuelto: Team = Team.cargar(JSON.parse_string(JSON.stringify(mio.guardar())))
	if Traspasos.estado(vuelto, id_rapida) == Traspasos.VENTA_RAPIDA \
			and Traspasos.estado(vuelto, id_cerrado) == Traspasos.NO_DISPONIBLE:
		_ok("los dos estados vuelven igual del JSON.")
	else:
		_falla("volvio %s" % [vuelto.traspasos])


func _test_el_que_se_va_no_deja_estado() -> void:
	print("\n=== El que se va del club no deja el estado colgado ===")
	var p := _partida()
	var mio: Team = p["mio"]
	var id := int(mio.banco[1]["id"])
	Traspasos.fijar(mio, id, Traspasos.VENTA_RAPIDA)
	mio._limpiar_registro(id)
	if not mio.traspasos.has(id):
		_ok("se borro junto con sueldo y contrato.")
	else:
		_falla("quedo %s" % [mio.traspasos])
