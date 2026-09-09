extends SceneTree

## Cesion negociada (core/cesiones.gd): marcas cedible, te llega un
## pedido, negociás los terminos por rondas y el jugador tiene la ultima
## palabra. Despues juega afuera y vuelve con lo que crecio.

const SEED := 4141

var gs = null


func _init() -> void:
	_test_solo_piden_por_los_cedibles()
	_test_el_pedido_nace_negociable()
	_test_el_club_aguanta_hasta_su_tope()
	_test_pedir_de_mas_los_hace_contraofertar()
	_test_el_jugador_tiene_la_ultima_palabra()
	_test_el_cedido_entra_al_once_si_mejora()
	_test_vuelve_con_lo_que_crecio()
	_test_la_opcion_se_ejerce_al_vencer()
	_test_la_opcion_cara_se_deja_vencer()
	_test_ejerces_vos_la_opcion_de_tu_prestado()
	_test_la_opcion_se_ejerce_con_el_libro_cerrado()
	_test_el_estado_sobrevive_al_guardado()
	if gs != null:
		gs.free()
	quit()


func _partida() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	if gs != null:
		gs.free()
	gs = load("res://game/game_state.gd").new()
	gs.piramide = piramide
	gs.rng = rng
	gs.temporada_actual = 3
	gs.fecha_actual = 0
	gs.division_jugador = 2
	gs.equipo_jugador = piramide.divisiones[2].equipos[0]
	gs._sembrar_presupuestos()
	gs.dia_absoluto = Calendario.primer_dia_de_mercado()
	return {"piramide": piramide, "rng": rng}


## Fuerza un pedido de cesion por `jugador`. Repite porque la aparicion es
## al azar (Cesiones.DIAS_ENTRE_PEDIDOS) y el club que mira puede no
## servir; sin el bucle el test mediría la suerte de la semilla.
func _forzar_pedido(jugador: Dictionary) -> Dictionary:
	var equipo: Team = gs.equipo_jugador
	Cesiones.fijar(equipo, int(jugador["id"]), Cesiones.DISPONIBLE)
	for _i in range(400):
		var o: Dictionary = Cesiones.generar_pedido(equipo, gs.piramide, gs.rng, 3, gs.division_jugador)
		if not o.is_empty() and int(o["jugador_id"]) == int(jugador["id"]):
			return o
		if not o.is_empty():
			o["estado"] = Ofertas.RECHAZADA
			Ofertas.archivar(equipo)
	return {}


func _cedible_cualquiera() -> Dictionary:
	# Un titular sirve: la lista de cedibles no distingue, a diferencia de
	# pedir_prestamo (donde el dueño es la IA y no suelta a sus titulares).
	return gs.equipo_jugador.jugadores[7]


func _test_solo_piden_por_los_cedibles() -> void:
	print("=== Sin marcar a nadie, no llega ningun pedido ===")
	_partida()
	var equipo: Team = gs.equipo_jugador
	var hubo := false
	for _i in range(300):
		if not Cesiones.generar_pedido(equipo, gs.piramide, gs.rng, 7, gs.division_jugador).is_empty():
			hubo = true
			break
	if hubo:
		print("FALLA: llego un pedido por alguien que no marcaste cedible.")
	else:
		print("OK: la lista vacia no genera pedidos.")


func _test_el_pedido_nace_negociable() -> void:
	print("\n=== El pedido nace con terminos negociables ===")
	_partida()
	var j := _cedible_cualquiera()
	var o := _forzar_pedido(j)
	if o.is_empty():
		print("FALLA: no llego ningun pedido en 400 intentos.")
		return
	var pct: float = float(o["porcentaje_sueldo"])
	if pct >= Prestamos.PORCENTAJE_SUELDO_MINIMO and float(o["monto"]) > 0.0 \
			and Prestamos.DURACIONES.has(str(o["duracion"])):
		print("OK: %s" % Cesiones.resumen(o))
	else:
		print("FALLA: terminos fuera de rango: %s" % [o])


func _test_el_club_aguanta_hasta_su_tope() -> void:
	print("\n=== Pedir dentro del tope: aceptan ===")
	_partida()
	var j := _cedible_cualquiera()
	var o := _forzar_pedido(j)
	if o.is_empty():
		print("FALLA: no llego ningun pedido.")
		return
	var topes: Dictionary = gs.topes_de_cesion(o)
	var r: Dictionary = gs.contraofertar_cesion(int(o["id"]), {
		"monto": float(topes["fee"]) * 0.9,
		"porcentaje_sueldo": 1.0,
		"opcion_compra": 0.0,
		"plus_sueldo": 0.0,
		"duracion": str(o["duracion"]),
	})
	if not r["exito"]:
		print("FALLA: no dejo contraofertar: %s" % r["motivo"])
		return
	o["dias"] = 0.0
	Ofertas.avanzar(gs.equipo_jugador, 1, gs.piramide, gs.rng, gs.temporada_actual, gs.division_jugador)
	if str(o["estado"]) == Ofertas.ACUERDO_CLUB:
		print("OK: %s" % o["log"][-1])
	else:
		print("FALLA: quedo en %s — %s" % [o["estado"], o["log"][-1]])


func _test_pedir_de_mas_los_hace_contraofertar() -> void:
	print("\n=== Pedir el doble de su tope: contraofertan, no aceptan ===")
	_partida()
	var j := _cedible_cualquiera()
	var o := _forzar_pedido(j)
	if o.is_empty():
		print("FALLA: no llego ningun pedido.")
		return
	var topes: Dictionary = gs.topes_de_cesion(o)
	var pedido: float = float(topes["fee"]) * 2.0
	gs.contraofertar_cesion(int(o["id"]), {
		"monto": pedido, "porcentaje_sueldo": 1.0, "opcion_compra": 0.0,
		"plus_sueldo": 0.0, "duracion": str(o["duracion"]),
	})
	o["dias"] = 0.0
	Ofertas.avanzar(gs.equipo_jugador, 1, gs.piramide, gs.rng, gs.temporada_actual, gs.division_jugador)
	if str(o["estado"]) == Ofertas.PENDIENTE_NOSOTROS and float(o["monto"]) < pedido:
		print("OK: pediste %s y llegan hasta %s." % [
			Economia.formato_dinero(pedido), Economia.formato_dinero(o["monto"])])
	elif str(o["estado"]) == Ofertas.RETIRADA:
		print("OK: se levantaron de la mesa — %s" % o["log"][-1])
	else:
		print("FALLA: aceptaron el doble de su tope (%s)." % [o["estado"]])


func _test_el_jugador_tiene_la_ultima_palabra() -> void:
	print("\n=== Acordas con el club y todavia falta el jugador ===")
	_partida()
	var j := _cedible_cualquiera()
	var o := _forzar_pedido(j)
	if o.is_empty():
		print("FALLA: no llego ningun pedido.")
		return
	gs.responder_oferta(int(o["id"]), "aceptar")
	if str(o["estado"]) != Ofertas.ACUERDO_CLUB:
		print("FALLA: aceptar no dejo la cesion en acuerdo de clubes.")
		return
	o["dias"] = 0.0
	Ofertas.avanzar(gs.equipo_jugador, 1, gs.piramide, gs.rng, gs.temporada_actual,
		gs.division_jugador, float(gs.temporada_actual))
	var estado := str(o["estado"])
	if estado == Ofertas.CERRADA:
		var fuera: bool = gs.equipo_jugador.prestados_afuera.has(int(j["id"]))
		print("OK: dijo que si y se fue cedido (prestados_afuera=%s)." % fuera if fuera
			else "FALLA: cerro la cesion pero el jugador no figura cedido.")
	elif estado == Ofertas.SIN_ACUERDO:
		print("OK: el club arreglo y el jugador dijo que no — %s" % o["log"][-1])
	else:
		print("FALLA: quedo en %s" % estado)


func _test_el_cedido_entra_al_once_si_mejora() -> void:
	print("\n=== El cedido entra al once del que lo pide si lo mejora ===")
	_partida()
	var equipo: Team = gs.equipo_jugador
	# Un club de la ultima division: cualquier suplente de division 2 le
	# mejora el puesto, que es el caso que interesa medir.
	var destino: Team = gs.piramide.divisiones[gs.piramide.divisiones.size() - 1].equipos[0]
	var j: Dictionary = equipo.banco[0]
	var id := int(j["id"])
	destino.caja["fichajes"] = 50000000.0
	destino.caja["contratos"] = 50000000.0
	var r := Prestamos.ceder(equipo, destino, id, 3.0, 1.0, 1.0, 0.0, 0.0)
	if not r["exito"]:
		print("FALLA: no se pudo ceder: %s" % r["motivo"])
		return
	var titular := false
	for x in destino.jugadores:
		if int(x["id"]) == id:
			titular = true
	if titular:
		print("OK: media %d entra al once de un club de la ultima division." % int(j["media"]))
	else:
		print("FALLA: quedo en el banco pudiendo ser titular.")


func _test_vuelve_con_lo_que_crecio() -> void:
	print("\n=== Vuelve con los partidos, los goles y la media que hizo afuera ===")
	_partida()
	var equipo: Team = gs.equipo_jugador
	var destino: Team = gs.piramide.divisiones[gs.piramide.divisiones.size() - 1].equipos[1]
	var j: Dictionary = equipo.banco[1]
	var id := int(j["id"])
	destino.caja["fichajes"] = 50000000.0
	destino.caja["contratos"] = 50000000.0
	var media_antes: float = float(j["media"])
	if not Prestamos.ceder(equipo, destino, id, 3.0, 1.0, 1.0, 0.0, 0.0)["exito"]:
		print("FALLA: no se pudo ceder.")
		return
	# Simula la temporada afuera: partidos jugados, goles y crecimiento.
	j["partidos_prestamo"] = 22
	j["goles_prestamo"] = 9
	j["media"] = media_antes + 4.0

	var vueltos: Array = Prestamos.procesar_retornos(equipo, 4.0)
	if vueltos.size() != 1:
		print("FALLA: no volvio (o volvio de mas): %d" % vueltos.size())
		return
	var rep: Dictionary = vueltos[0]
	var en_plantel := false
	for x in equipo.todos_los_jugadores():
		if int(x["id"]) == id:
			en_plantel = true
	if not en_plantel:
		print("FALLA: volvio el reporte pero no el jugador.")
		return
	if int(rep["partidos"]) == 22 and int(rep["goles"]) == 9 \
			and float(rep["media_ahora"]) > float(rep["media_antes"]):
		print("OK: %s" % Prestamos.texto_retorno(rep))
	else:
		print("FALLA: reporte incompleto: %s" % [rep])
	if destino.prestados_propios.has(id) or equipo.prestados_afuera.has(id):
		print("FALLA: quedaron registros del prestamo despues del retorno.")


func _test_el_estado_sobrevive_al_guardado() -> void:
	print("\n=== La lista de cedibles y los terminos sobreviven al guardado ===")
	_partida()
	var equipo: Team = gs.equipo_jugador
	var id := int(equipo.jugadores[3]["id"])
	Cesiones.fijar(equipo, id, Cesiones.DISPONIBLE)

	var destino: Team = gs.piramide.divisiones[gs.piramide.divisiones.size() - 1].equipos[2]
	destino.caja["fichajes"] = 50000000.0
	destino.caja["contratos"] = 50000000.0
	var cedido := int(equipo.banco[2]["id"])
	var r := Prestamos.ceder(equipo, destino, cedido, 3.0, 2.0, 0.8, 1234567.0, 0.0)
	if not r["exito"]:
		print("FALLA: no se pudo ceder: %s" % r["motivo"])
		return
	var sueldo_pactado: float = float(equipo.prestados_afuera[cedido]["sueldo_completo"])

	var copia := Team.cargar(equipo.guardar())
	if Cesiones.estado(copia, id) != Cesiones.DISPONIBLE:
		print("FALLA: la lista de cedibles no sobrevivio al guardado.")
		return
	var info: Dictionary = copia.prestados_afuera[cedido]
	if is_equal_approx(float(info["sueldo_completo"]), sueldo_pactado) \
			and is_equal_approx(float(info["opcion_compra"]), 1234567.0):
		print("OK: sueldo pactado y opcion de compra viajan con el guardado.")
	else:
		print("FALLA: los terminos se perdieron: %s" % [info])


## Un club de la ultima division no puede pagar la opcion de nadie: para
## medir la decision hace falta un comprador con caja y con plantel flojo,
## que es lo que arma esto.
func _club_comprador() -> Team:
	var destino: Team = gs.piramide.divisiones[gs.piramide.divisiones.size() - 1].equipos[3]
	destino.caja["fichajes"] = 500000000.0
	destino.caja["contratos"] = 500000000.0
	return destino


func _test_la_opcion_se_ejerce_al_vencer() -> void:
	print("
=== La opcion barata se ejerce al vencer el prestamo ===")
	_partida()
	var equipo: Team = gs.equipo_jugador
	var destino := _club_comprador()
	var j: Dictionary = equipo.banco[0]
	var id := int(j["id"])
	var valor := ValorJugador.calcular(j, equipo.animo.get(id, 50.0), equipo.contratos.get(id, 3))
	# Una opcion regalada: el comprador la ejerce seguro.
	var precio: float = valor * 0.5
	var caja_antes: float = equipo.caja["fichajes"]
	if not Prestamos.ceder(equipo, destino, id, 3.0, 1.0, 1.0, precio, 0.0)["exito"]:
		print("FALLA: no se pudo ceder.")
		return

	var vueltos: Array = Prestamos.procesar_retornos(equipo, 4.0, null)
	if vueltos.size() != 1 or not bool(vueltos[0].get("comprado", false)):
		print("FALLA: no ejercieron la opcion: %s" % [vueltos])
		return
	var sigue_en_destino := not Mercado.ubicar(destino, id).is_empty()
	var ya_no_es_mio := Mercado.ubicar(equipo, id).is_empty()
	var cobre: bool = equipo.caja["fichajes"] > caja_antes
	if sigue_en_destino and ya_no_es_mio and cobre 			and not destino.prestados_propios.has(id) and not equipo.sueldos.has(id):
		print("OK: %s" % Prestamos.texto_retorno(vueltos[0]))
	else:
		print("FALLA: destino=%s mio=%s cobre=%s" % [sigue_en_destino, not ya_no_es_mio, cobre])


func _test_la_opcion_cara_se_deja_vencer() -> void:
	print("
=== La opcion carisima se deja vencer y el jugador vuelve ===")
	_partida()
	var equipo: Team = gs.equipo_jugador
	var destino := _club_comprador()
	var j: Dictionary = equipo.banco[1]
	var id := int(j["id"])
	var valor := ValorJugador.calcular(j, equipo.animo.get(id, 50.0), equipo.contratos.get(id, 3))
	if not Prestamos.ceder(equipo, destino, id, 3.0, 1.0, 1.0, valor * 8.0, 0.0)["exito"]:
		print("FALLA: no se pudo ceder.")
		return

	var vueltos: Array = Prestamos.procesar_retornos(equipo, 4.0, null)
	if vueltos.size() != 1 or bool(vueltos[0].get("comprado", false)):
		print("FALLA: ejercieron una opcion de ocho veces lo que vale.")
		return
	if Mercado.ubicar(equipo, id).is_empty():
		print("FALLA: no volvio al plantel.")
		return
	print("OK: %s" % Prestamos.texto_retorno(vueltos[0]))


func _test_ejerces_vos_la_opcion_de_tu_prestado() -> void:
	print("
=== La opcion de un prestado TUYO la ejerces vos, no la IA ===")
	_partida()
	var equipo: Team = gs.equipo_jugador
	equipo.caja["fichajes"] = 500000000.0
	equipo.caja["contratos"] = 500000000.0
	# Un club de arriba te cede a un suplente suyo con opcion.
	var dueno: Team = gs.piramide.divisiones[0].equipos[0]
	var j: Dictionary = dueno.banco[0]
	var id := int(j["id"])
	var valor := ValorJugador.calcular(j, dueno.animo.get(id, 50.0), dueno.contratos.get(id, 3))
	if not Prestamos.ceder(dueno, equipo, id, 3.0, 1.0, 1.0, valor * 0.5, 0.0)["exito"]:
		print("FALLA: no se pudo recibir el prestamo.")
		return

	var abiertas: Array = gs.opciones_de_compra_abiertas()
	if abiertas.size() != 1 or int(abiertas[0]["jugador"]["id"]) != id:
		print("FALLA: la opcion no figura como abierta: %s" % [abiertas])
		return
	# Al vencer NADIE la ejerce por vos: la decision es tuya.
	var vueltos: Array = Prestamos.procesar_retornos(dueno, 4.5, equipo)
	if vueltos.size() == 1 and bool(vueltos[0].get("comprado", false)):
		print("FALLA: la IA ejercio la opcion del club del jugador.")
		return

	# Y ejercerla de verdad te lo deja como tuyo.
	_partida()
	equipo = gs.equipo_jugador
	equipo.caja["fichajes"] = 500000000.0
	equipo.caja["contratos"] = 500000000.0
	dueno = gs.piramide.divisiones[0].equipos[0]
	j = dueno.banco[0]
	id = int(j["id"])
	valor = ValorJugador.calcular(j, dueno.animo.get(id, 50.0), dueno.contratos.get(id, 3))
	Prestamos.ceder(dueno, equipo, id, 3.0, 1.0, 1.0, valor * 0.5, 0.0)
	var r: Dictionary = gs.ejercer_opcion_de_compra(id)
	if not r["exito"]:
		print("OK (el jugador dijo que no): %s" % r["motivo"])
		return
	if not equipo.prestados_propios.has(id) and not dueno.prestados_afuera.has(id) 			and equipo.contratos.get(id, 0) > 0 and not Mercado.ubicar(equipo, id).is_empty():
		print("OK: lo compraste por %s con contrato de %d años." % [
			Economia.formato_dinero(r["precio"]), int(r["anios"])])
	else:
		print("FALLA: quedaron rastros del prestamo: %s" % [r])


func _test_la_opcion_se_ejerce_con_el_libro_cerrado() -> void:
	print("
=== La opcion se ejerce aunque el libro de pases este cerrado ===")
	_partida()
	var equipo: Team = gs.equipo_jugador
	equipo.caja["fichajes"] = 500000000.0
	equipo.caja["contratos"] = 500000000.0
	var dueno: Team = gs.piramide.divisiones[0].equipos[1]
	var j: Dictionary = dueno.banco[0]
	var id := int(j["id"])
	var valor := ValorJugador.calcular(j, dueno.animo.get(id, 50.0), dueno.contratos.get(id, 3))
	if not Prestamos.ceder(dueno, equipo, id, 3.0, 1.0, 1.0, valor * 0.5, 0.0)["exito"]:
		print("FALLA: no se pudo recibir el prestamo.")
		return

	# Un dia de marzo: el libro esta cerrado y cualquier otra operacion de
	# mercado se rechaza.
	gs.dia_absoluto = Calendario.primer_dia_de_mercado() + 70
	if gs.hay_mercado_abierto():
		print("FALLA: el test no logro cerrar el libro de pases.")
		return
	var r: Dictionary = gs.ejercer_opcion_de_compra(id)
	if not r["exito"] and str(r["motivo"]).contains("mercado"):
		print("FALLA: rechazo la opcion por el libro cerrado: %s" % r["motivo"])
		return
	if not r["exito"]:
		print("OK (el jugador dijo que no, no el calendario): %s" % r["motivo"])
		return
	print("OK: la ejerciste con el libro cerrado por %s." % Economia.formato_dinero(r["precio"]))
