extends SceneTree

## §9.3 rework: negociaciones por rondas, en las dos direcciones.

const SEED := 4747

var gs = null


func _init() -> void:
	_test_una_oferta_no_se_resuelve_en_el_acto()
	_test_el_vendedor_contraoferta()
	_test_la_miseria_corta_la_negociacion()
	_test_llegan_ofertas_por_los_mios()
	_test_aceptar_no_garantiza_la_venta()
	_test_lo_terminado_va_al_historial()
	_test_guardado()
	if gs != null:
		gs.free()
	quit()


## GameState es autoload y en un --script no existe: se instancia a mano y
## no se agrega al arbol (su _ready cargaria la partida real del disco).
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
	# Igual que en una partida nueva: sin sembrar, la caja de todos
	# arranca en cero y nadie puede ofertar nada (ver _sembrar_presupuestos).
	gs._sembrar_presupuestos()
	gs.equipo_jugador.caja["fichajes"] = 500000000.0
	return {"piramide": piramide, "rng": rng, "mio": gs.equipo_jugador,
		"otro": piramide.divisiones[division].equipos[1]}


func _test_una_oferta_no_se_resuelve_en_el_acto() -> void:
	print("=== Mandar una oferta la deja ABIERTA, no la resuelve ===")
	var p := _partida()
	var otro: Team = p["otro"]
	var jugador: Dictionary = otro.jugadores[5]
	var pedido := Negociacion.precio_pedido(otro, jugador)

	var r: Dictionary = gs.enviar_oferta(otro, int(jugador["id"]), pedido)
	if not r["exito"]:
		print("FALLA: no se pudo enviar (%s)." % r["motivo"])
		return
	var apenas_mandada := str(r["oferta"]["estado"])
	# Pasan los dias y recien ahi contestan.
	gs._avanzar_dias_todos(Ofertas.DIAS_RESPUESTA_MAX + 1)
	var despues := str(r["oferta"]["estado"])
	if apenas_mandada == Ofertas.PENDIENTE_ELLOS and despues == Ofertas.ACUERDO_CLUB:
		print("OK: queda esperando y a los %d dias aceptan." % (Ofertas.DIAS_RESPUESTA_MAX + 1))
	else:
		print("FALLA: %s -> %s" % [apenas_mandada, despues])


func _test_el_vendedor_contraoferta() -> void:
	print("\n=== Si te falta poco, contraofertan en vez de decir que no ===")
	var p := _partida()
	var otro: Team = p["otro"]
	var jugador: Dictionary = otro.jugadores[6]
	var pedido := Negociacion.precio_pedido(otro, jugador)

	# Por encima del insulto pero por debajo de lo que piden.
	var r: Dictionary = gs.enviar_oferta(otro, int(jugador["id"]), pedido * 0.8)
	gs._avanzar_dias_todos(Ofertas.DIAS_RESPUESTA_MAX + 1)
	var o: Dictionary = r["oferta"]
	if str(o["estado"]) == Ofertas.PENDIENTE_NOSOTROS and is_equal_approx(float(o["monto"]), pedido) \
			and int(o["ronda"]) == 2:
		print("OK: contraofertaron %s y la pelota vuelve a nuestro lado (ronda 2)." % [
			Economia.formato_dinero(o["monto"])])
	else:
		print("FALLA: estado=%s monto=%.0f ronda=%d" % [o["estado"], o["monto"], o["ronda"]])


func _test_la_miseria_corta_la_negociacion() -> void:
	print("\n=== Una miseria corta la negociacion y veta ===")
	var p := _partida()
	var otro: Team = p["otro"]
	var jugador: Dictionary = otro.jugadores[7]
	var id := int(jugador["id"])
	var pedido := Negociacion.precio_pedido(otro, jugador)

	var r: Dictionary = gs.enviar_oferta(otro, id, pedido * 0.1)
	gs._avanzar_dias_todos(Ofertas.DIAS_RESPUESTA_MAX + 1)
	var vetado := Negociacion.bloqueado(otro, id, 1)
	# archivar() ya la saco de ofertas; se busca en el historial.
	var estado := ""
	for h in gs.equipo_jugador.historial_mercado:
		if int(h["jugador_id"]) == id:
			estado = str(h["estado"])
	if estado == Ofertas.RETIRADA and vetado:
		print("OK: se levantaron de la mesa y quedaste vetado.")
	else:
		print("FALLA: estado=%s vetado=%s" % [estado, vetado])


func _test_llegan_ofertas_por_los_mios() -> void:
	print("\n=== Los otros clubes vienen a buscar a los tuyos ===")
	var p := _partida()
	var mio: Team = p["mio"]
	var rng: RandomNumberGenerator = p["rng"]
	var recibidas := 0
	for _i in range(60):
		recibidas += Ofertas.generar_entrantes(mio, p["piramide"], rng, 7, 4).size()
	var todas_por_los_mios := true
	for o in mio.ofertas:
		if not bool(o["entrante"]) or Mercado.ubicar(mio, int(o["jugador_id"])).is_empty():
			todas_por_los_mios = false
	if recibidas > 5 and todas_por_los_mios:
		print("OK: %d ofertas en 60 semanas, todas por jugadores del plantel." % recibidas)
	else:
		print("FALLA: %d ofertas, coherentes=%s" % [recibidas, todas_por_los_mios])


func _test_aceptar_no_garantiza_la_venta() -> void:
	print("\n=== Aceptar una oferta no cierra la venta: falta el jugador ===")
	# Este es el punto: los clubes arreglan y el pase se puede caer igual
	# porque el jugador no se pone de acuerdo, y eso no lo controlas vos.
	var p := _partida(0)  # el jugador en PRIMERA
	var mio: Team = p["mio"]
	var rng: RandomNumberGenerator = p["rng"]
	var jugador: Dictionary = mio.jugadores[8]
	var id := int(jugador["id"])
	mio.animo[id] = 90.0  # comodisimo: no se quiere ir a ningun lado

	# Un club de DECIMA lo quiere. El precio se arregla, el contrato no.
	var comprador: Team = p["piramide"].divisiones[9].equipos[0]
	comprador.caja["fichajes"] = 500000000.0
	var oferta := Ofertas.nueva(999, comprador.nombre, jugador, 1000000.0, true, rng)
	mio.ofertas.append(oferta)

	var r: Dictionary = gs.responder_oferta(999, "aceptar")
	if not r["exito"]:
		print("FALLA: no se pudo aceptar (%s)." % r["motivo"])
		return
	gs._avanzar_dias_todos(Ofertas.DIAS_RESPUESTA_MAX + 1)

	var sigue := not Mercado.ubicar(mio, id).is_empty()
	var estado := ""
	for h in mio.historial_mercado:
		if int(h["id"]) == 999:
			estado = str(h["estado"])
	if estado == Ofertas.SIN_ACUERDO and sigue:
		print("OK: los clubes arreglaron, el jugador dijo que no y se quedo.")
	else:
		print("FALLA: estado=%s sigue=%s" % [estado, sigue])


func _test_lo_terminado_va_al_historial() -> void:
	print("\n=== Lo terminado sale de la lista viva y va al historial ===")
	var p := _partida()
	var mio: Team = p["mio"]
	var otro: Team = p["otro"]
	var jugador: Dictionary = otro.jugadores[3]
	var r: Dictionary = gs.enviar_oferta(otro, int(jugador["id"]), 1.0)
	gs.responder_oferta(int(r["oferta"]["id"]), "rechazar")
	# rechazar() sobre una PENDIENTE_ELLOS no aplica; se fuerza el estado.
	r["oferta"]["estado"] = Ofertas.RECHAZADA
	var vivas_antes := mio.ofertas.size()
	Ofertas.archivar(mio)
	if mio.ofertas.size() == vivas_antes - 1 and not mio.historial_mercado.is_empty():
		print("OK: %d abiertas -> %d, y %d en el historial." % [
			vivas_antes, mio.ofertas.size(), mio.historial_mercado.size()])
	else:
		print("FALLA: abiertas=%d historial=%d" % [mio.ofertas.size(), mio.historial_mercado.size()])


func _test_guardado() -> void:
	print("\n=== Ofertas e historial sobreviven al guardado ===")
	var p := _partida()
	var mio: Team = p["mio"]
	var otro: Team = p["otro"]
	gs.enviar_oferta(otro, int(otro.jugadores[2]["id"]), 50000.0)
	var abiertas := mio.ofertas.size()
	var vuelto := Team.cargar(JSON.parse_string(JSON.stringify(mio.guardar())))
	if vuelto.ofertas.size() == abiertas and int(vuelto.ofertas[0]["jugador_id"]) == int(otro.jugadores[2]["id"]):
		print("OK: %d negociacion(es) abiertas despues de guardar y cargar." % abiertas)
	else:
		print("FALLA: quedaron %d" % vuelto.ofertas.size())
