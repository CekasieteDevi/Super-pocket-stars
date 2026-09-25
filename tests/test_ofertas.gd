extends SceneTree

## §9.3 rework: negociaciones por rondas, en las dos direcciones.

const SEED := 4747

var gs = null


func _init() -> void:
	_test_una_oferta_no_se_resuelve_en_el_acto()
	_test_el_vendedor_contraoferta()
	_test_la_miseria_corta_la_negociacion()
	_test_el_veto_se_avisa_una_sola_vez()
	_test_llegan_ofertas_por_los_mios()
	_test_pueden_competir_tres_clubes_por_el_mismo()
	_test_el_crack_de_abajo_lo_buscan_los_de_arriba()
	_test_aceptar_no_garantiza_la_venta()
	_test_operacion_caida_explica_quien_y_por_que()
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
	# El libro de pases solo abre en enero, febrero y julio, y una
	# partida arranca en marzo: sin esto toda operacion se rechaza.
	gs.dia_absoluto = Calendario.primer_dia_de_mercado()
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


func _test_el_veto_se_avisa_una_sola_vez() -> void:
	print("
=== El veto se avisa en la portada y se apaga al aceptarlo ===")
	var p := _partida()
	var otro: Team = p["otro"]
	var mio: Team = p["mio"]
	var jugador: Dictionary = otro.jugadores[7]
	var id := int(jugador["id"])

	gs.enviar_oferta(otro, id, Negociacion.precio_pedido(otro, jugador) * 0.1)
	gs._avanzar_dias_todos(Ofertas.DIAS_RESPUESTA_MAX + 1)

	# El veto vive en el club VENDEDOR, asi que sin la marca en la oferta
	# la portada no tiene de donde sacarlo. Ver Main._pendientes_de_portada.
	var sin_ver: Array = Ofertas.vetos_sin_ver(mio)
	if sin_ver.size() != 1:
		print("FALLA: vetos sin ver = %d, se esperaba 1." % sin_ver.size())
		return
	var aviso: Dictionary = sin_ver[0]
	if int(aviso["veto_hasta"]) != Negociacion.veto_hasta(gs.temporada_actual):
		print("FALLA: veto_hasta=%d" % int(aviso["veto_hasta"]))
		return
	print("OK: el veto por %s aparece como pendiente." % str(aviso["jugador"]))

	Ofertas.marcar_veto_visto(aviso)
	if Ofertas.vetos_sin_ver(mio).is_empty():
		print("OK: aceptarlo lo saca de la lista.")
	else:
		print("FALLA: el aviso sigue despues de aceptarlo.")

	# El cartel se apaga, el veto NO: son dos cosas distintas.
	if Negociacion.bloqueado(otro, id, gs.temporada_actual):
		print("OK: el veto sigue en pie despues de aceptar el aviso.")
	else:
		print("FALLA: aceptar el aviso levanto el veto.")

	# El aviso tiene que sobrevivir al guardado: si te vetan y guardas
	# antes de leerlo, al volver tiene que seguir ahi.
	var vuelto := Team.cargar(JSON.parse_string(JSON.stringify(mio.guardar())))
	var marcados := 0
	for h in vuelto.historial_mercado:
		if bool(h.get("veto", false)):
			marcados += 1
	if marcados == 1:
		print("OK: la marca de veto sobrevive al guardado.")
	else:
		print("FALLA: quedaron %d vetos marcados despues de guardar." % marcados)


func _test_llegan_ofertas_por_los_mios() -> void:
	print("\n=== Los otros clubes vienen a buscar a los tuyos ===")
	var p := _partida()
	var mio: Team = p["mio"]
	var rng: RandomNumberGenerator = p["rng"]
	# Se limpia la bandeja en cada vuelta: una oferta abierta bloquea otra
	# por el mismo jugador, y sin limpiar el test medía cuantos jugadores
	# destacan en el plantel y no si llegan ofertas.
	var recibidas := []
	for _i in range(60):
		recibidas.append_array(Ofertas.generar_entrantes(mio, p["piramide"], rng, 7, 4))
		mio.ofertas.clear()
	var todas_por_los_mios := true
	for o in recibidas:
		if not bool(o["entrante"]) or Mercado.ubicar(mio, int(o["jugador_id"])).is_empty():
			todas_por_los_mios = false
	if recibidas.size() > 30 and todas_por_los_mios:
		print("OK: %d ofertas en 60 semanas, todas por jugadores del plantel." % recibidas.size())
	else:
		print("FALLA: %d ofertas, coherentes=%s" % [recibidas.size(), todas_por_los_mios])


func _test_pueden_competir_tres_clubes_por_el_mismo() -> void:
	print("\n=== Tres clubes pueden ofertar a la vez por el mismo jugador ===")
	var p := _partida()
	var mio: Team = p["mio"]
	var jugador: Dictionary = mio.jugadores[8]
	var id := int(jugador["id"])
	jugador["media"] = 80.0
	jugador["potencial"] = 80.0
	jugador["edad"] = 25
	jugador["personalidades"] = {}
	mio.animo[id] = 0.0
	for j in mio.todos_los_jugadores():
		Traspasos.fijar(mio, int(j["id"]), Traspasos.NO_DISPONIBLE)
	Traspasos.fijar(mio, id, Traspasos.DISPONIBLE)
	for liga in p["piramide"].divisiones:
		for club in liga.equipos:
			if club != mio:
				club.caja["fichajes"] = 500000000.0
	for _i in range(20):
		Ofertas.generar_entrantes(mio, p["piramide"], p["rng"], 2, 4)
	var clubes := {}
	for o in mio.ofertas:
		clubes[str(o["club"])] = true
	if Ofertas.cantidad_abiertas_entrantes(mio, id, "compra") == 3 and clubes.size() == 3:
		print("OK: hay tres ofertas simultaneas de tres clubes distintos.")
	else:
		print("FALLA: ofertas=%d clubes=%d" % [
			Ofertas.cantidad_abiertas_entrantes(mio, id, "compra"), clubes.size()])


func _test_el_crack_de_abajo_lo_buscan_los_de_arriba() -> void:
	print("
=== El crack de una division baja lo buscan los de arriba; al suplente flojo, los de abajo ===")
	# El suplente flojo SI puede recibir ofertas: le sirve a un club de mas
	# abajo. Antes el test pedia cero ofertas por el, y era justo lo que
	# hacia que las ofertas se juntaran en uno o dos jugadores del plantel.
	var p := _partida(6)
	var mio: Team = p["mio"]
	var rng: RandomNumberGenerator = p["rng"]
	# Media de dos divisiones mas arriba: es el que un club de arriba ficha.
	var crack: Dictionary = mio.jugadores[10]
	crack["media"] = NivelDivision.media_de(4) + 2.0
	crack["edad"] = 25
	var flojo: Dictionary = mio.banco[0]
	flojo["media"] = mio.media_equipo() - 10.0
	flojo["edad"] = 30

	var por_crack := 0
	var de_arriba := 0
	var por_flojo := 0
	var flojo_de_arriba := 0
	for _i in range(400):
		for o in Ofertas.generar_entrantes(mio, p["piramide"], rng, 2, 6):
			var es_de_arriba := false
			for d in range(6):
				for e in p["piramide"].divisiones[d].equipos:
					if e.nombre == str(o["club"]):
						es_de_arriba = true
			if int(o["jugador_id"]) == int(crack["id"]):
				por_crack += 1
				if es_de_arriba:
					de_arriba += 1
			elif int(o["jugador_id"]) == int(flojo["id"]):
				por_flojo += 1
				if es_de_arriba:
					flojo_de_arriba += 1
		mio.ofertas.clear()
	if por_crack >= 10 and de_arriba == por_crack and por_crack > por_flojo and flojo_de_arriba == 0:
		print("OK: %d ofertas por el crack, todas de arriba; %d por el flojo, ninguna de arriba." % [
			por_crack, por_flojo])
	else:
		print("FALLA: crack=%d (de arriba %d) flojo=%d (de arriba %d)" % [
			por_crack, de_arriba, por_flojo, flojo_de_arriba])


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


func _test_operacion_caida_explica_quien_y_por_que() -> void:
	print("\n=== Una operación caída identifica jugador, club y causa ===")
	var p := _partida()
	var mio: Team = p["mio"]
	var comprador: Team = p["otro"]
	var rng: RandomNumberGenerator = p["rng"]
	var jugador: Dictionary = mio.jugadores[0]

	var sin_jugador := Ofertas.nueva(997, comprador.nombre, jugador, 1000000.0, true, rng)
	sin_jugador["jugador_id"] = -999
	sin_jugador["estado"] = Ofertas.ACUERDO_CLUB
	sin_jugador["dias"] = 0.0
	mio.ofertas.append(sin_jugador)
	Ofertas.avanzar(mio, 1, p["piramide"], rng, 1, gs.division_jugador)
	var aviso_jugador := str(sin_jugador["log"][-1])

	var sin_club := Ofertas.nueva(998, "Club desaparecido", jugador, 1000000.0, true, rng)
	sin_club["estado"] = Ofertas.ACUERDO_CLUB
	sin_club["dias"] = 0.0
	mio.ofertas.append(sin_club)
	Ofertas.avanzar(mio, 1, p["piramide"], rng, 1, gs.division_jugador)
	var aviso_club := str(sin_club["log"][-1])

	var nombre := str(sin_jugador["jugador"])
	if aviso_jugador.contains(nombre) and aviso_jugador.contains(comprador.nombre) \
			and aviso_jugador.contains("ya no está en tu plantel") \
			and aviso_club.contains(nombre) and aviso_club.contains("Club desaparecido") \
			and aviso_club.contains("ya no forma parte de la competición"):
		print("OK: ambos avisos identifican el pase y explican la causa.")
	else:
		print("FALLA: jugador='%s' club='%s'" % [aviso_jugador, aviso_club])


func _test_lo_terminado_va_al_historial() -> void:
	print("\n=== Lo terminado sale de la lista viva y va al historial ===")
	var p := _partida()
	var mio: Team = p["mio"]
	var otro: Team = p["otro"]
	var jugador: Dictionary = otro.jugadores[3]
	var r: Dictionary = gs.enviar_oferta(otro, int(jugador["id"]), 1.0)
	var vivas_antes := mio.ofertas.size()
	# Una enviada espera al otro club: Rechazar no aplica, Retirar si.
	var retiro: Dictionary = gs.retirar_oferta(int(r["oferta"]["id"]))
	if retiro["exito"] and mio.ofertas.size() == vivas_antes - 1 \
			and str(mio.historial_mercado[-1]["estado"]) == Ofertas.RETIRADA:
		print("OK: retirar una enviada la saca en el acto: %d abiertas -> %d, y %d en el historial." % [
			vivas_antes, mio.ofertas.size(), mio.historial_mercado.size()])
	else:
		print("FALLA: exito=%s abiertas=%d historial=%d" % [
			retiro["exito"], mio.ofertas.size(), mio.historial_mercado.size()])


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
