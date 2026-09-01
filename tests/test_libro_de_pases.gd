extends SceneTree

## El libro de pases: enero, febrero y julio.
##
## Fuera de esos meses no se puede ofertar por nadie ni nadie oferta por
## vos, y lo que quedo abierto SE CAE al cerrar la ventana — si aceptas
## una el ultimo dia y no la firmas, perdiste la oportunidad.
##
## Para que los meses signifiquen algo, la temporada tiene que estar
## anclada al almanaque: arranca siempre el mismo dia de marzo, con
## receso en el medio. Sin eso se corre —dura 266 dias— y la segunda
## temporada iria de noviembre a agosto.

const SEED := 1717
const GUION := preload("res://game/game_state.gd")


func _init() -> void:
	_test_los_meses_de_mercado()
	_test_la_temporada_arranca_siempre_en_marzo()
	_test_fuera_de_ventana_no_se_puede_operar()
	_test_al_cerrar_se_cae_lo_que_estaba_abierto()
	_test_lo_rechazado_y_lo_vencido_desaparece()
	quit()


func _test_los_meses_de_mercado() -> void:
	print("=== Enero, febrero y julio ===")
	var abiertos := []
	var cerrados := []
	# Un ano entero desde el arranque, mirando el dia 1 de cada mes.
	for mes in range(1, 13):
		# El dia 15 de cada mes del 2026, que es el primer ano completo.
		var dia := 0
		while int(Calendario.fecha(dia)["year"]) < 2026 \
				or int(Calendario.fecha(dia)["month"]) < mes:
			dia += 1
		if Calendario.hay_mercado(dia):
			abiertos.append(mes)
		else:
			cerrados.append(mes)
	if abiertos != [1, 2, 7]:
		print("FALLA: el mercado abre en los meses %s." % str(abiertos))
		return
	print("OK: abre en enero, febrero y julio; cerrado los otros %d meses." % cerrados.size())


func _test_la_temporada_arranca_siempre_en_marzo() -> void:
	print("\n=== Cada temporada arranca en marzo ===")
	var gs := GUION.new()
	gs.partida_nueva(SEED)
	var arranques := []
	for temporada in range(2):
		var f := Calendario.fecha(gs.dia_absoluto)
		arranques.append("%d/%d" % [int(f["day"]), int(f["month"])])
		if int(f["month"]) != Calendario.MES_INICIAL:
			print("FALLA: la temporada %d arranca el %s." % [temporada + 1, arranques[-1]])
			return
		# Se juega la temporada entera y se pasa el receso.
		var pasos := 0
		var t := gs.temporada_actual
		while gs.temporada_actual == t and pasos < 4000:
			pasos += 1
			if gs.hay_partido_hoy():
				gs.jugar_siguiente_fecha()
			else:
				gs.avanzar_un_dia()
		# El receso: dias sin fecha hasta el arranque nuevo.
		var receso := 0
		while gs.en_receso() and receso < 400:
			gs.avanzar_un_dia()
			receso += 1
		if receso == 0:
			print("FALLA: no hubo receso entre temporadas.")
			return
	print("OK: las temporadas arrancan el %s, con receso en el medio." % str(arranques))


func _test_fuera_de_ventana_no_se_puede_operar() -> void:
	print("\n=== Con el mercado cerrado no se opera ===")
	var gs := GUION.new()
	gs.partida_nueva(SEED + 1)
	# La partida arranca en marzo: cerrado.
	if gs.hay_mercado_abierto():
		print("FALLA: la partida arranca con el mercado abierto en marzo.")
		return
	var vendedor: Team = null
	for e in gs.liga_jugador().equipos:
		if e != gs.equipo_jugador:
			vendedor = e
			break
	var r: Dictionary = gs.ofertar_por_jugador(vendedor, int(vendedor.jugadores[0]["id"]))
	if bool(r.get("exito", true)):
		print("FALLA: se pudo comprar con el mercado cerrado.")
		return
	if str(r.get("motivo", "")) != GUION.MERCADO_CERRADO:
		print("FALLA: el motivo fue '%s'." % str(r.get("motivo", "")))
		return
	print("OK: la compra se rechaza y dice por que.")


func _test_al_cerrar_se_cae_lo_que_estaba_abierto() -> void:
	print("\n=== Al cerrar la ventana se cae lo que quedo en el aire ===")
	var gs := GUION.new()
	gs.partida_nueva(SEED + 2)
	# Se avanza hasta el ultimo dia de una ventana abierta.
	var pasos := 0
	while pasos < 2000:
		pasos += 1
		if gs.hay_partido_hoy():
			gs.jugar_siguiente_fecha()
			continue
		gs.avanzar_un_dia()
		if gs.dias_de_mercado() == 0:
			break
	if gs.dias_de_mercado() != 0:
		print("FALLA: no se llego al ultimo dia de una ventana en %d pasos." % pasos)
		return

	# Una negociacion abierta el ultimo dia.
	var vendedor: Team = null
	for e in gs.liga_jugador().equipos:
		if e != gs.equipo_jugador:
			vendedor = e
			break
	gs.equipo_jugador.caja["fichajes"] = 99999999.0
	var objetivo: int = int(vendedor.jugadores[0]["id"])
	var valor := ValorJugador.calcular(vendedor.jugadores[0],
		vendedor.animo.get(objetivo, 50.0), vendedor.contratos.get(objetivo, 3))
	var envio: Dictionary = gs.enviar_oferta(vendedor, objetivo, valor * 2.0)
	if not bool(envio.get("exito", false)):
		print("FALLA: no se pudo enviar la oferta el ultimo dia (%s)." % str(envio.get("motivo", "")))
		return
	var abiertas_antes := 0
	for o in gs.equipo_jugador.ofertas:
		if Ofertas.abierta(o):
			abiertas_antes += 1
	if abiertas_antes == 0:
		print("FALLA: la oferta no quedo abierta.")
		return

	gs.avanzar_un_dia()  # primer dia con el mercado cerrado
	if gs.hay_mercado_abierto():
		print("FALLA: el mercado sigue abierto despues de avanzar el dia.")
		return
	for o in gs.equipo_jugador.ofertas:
		if Ofertas.abierta(o):
			print("FALLA: quedo una negociacion abierta con el mercado cerrado.")
			return
	print("OK: las %d negociaciones abiertas se cayeron al cerrar el mercado." % abiertas_antes)


func _test_lo_rechazado_y_lo_vencido_desaparece() -> void:
	print("\n=== Rechazar y vencer sacan la oferta de la lista ===")
	var gs := GUION.new()
	gs.partida_nueva(SEED + 3)
	gs.dia_absoluto = Calendario.primer_dia_de_mercado()

	# Una oferta ENTRANTE por uno de los nuestros.
	var comprador: Team = null
	for e in gs.liga_jugador().equipos:
		if e != gs.equipo_jugador:
			comprador = e
			break
	var mio: Dictionary = gs.equipo_jugador.jugadores[0]
	var entrante := Ofertas.nueva(9001, comprador.nombre, mio, 100000.0, true, gs.rng)
	gs.equipo_jugador.ofertas.append(entrante)

	var r: Dictionary = gs.responder_oferta(9001, "rechazar")
	if not bool(r.get("exito", false)):
		print("FALLA: no se pudo rechazar (%s)." % str(r.get("motivo", "")))
		return
	for o in gs.equipo_jugador.ofertas:
		if int(o["id"]) == 9001:
			print("FALLA: la oferta rechazada sigue en la lista viva.")
			return
	var en_historial := false
	for o in gs.equipo_jugador.historial_mercado:
		if int(o["id"]) == 9001:
			en_historial = true
	if not en_historial:
		print("FALLA: la oferta rechazada no quedo en el historial.")
		return

	# Y una que queda abierta cuando se cierra el mercado.
	var otra := Ofertas.nueva(9002, comprador.nombre, mio, 100000.0, true, gs.rng)
	gs.equipo_jugador.ofertas.append(otra)
	var pasos := 0
	while gs.hay_mercado_abierto() and pasos < 400:
		pasos += 1
		if gs.hay_partido_hoy():
			gs.jugar_siguiente_fecha()
		else:
			gs.avanzar_un_dia()
	for o in gs.equipo_jugador.ofertas:
		if int(o["id"]) == 9002:
			print("FALLA: la oferta vencida sigue en la lista viva.")
			return
	print("OK: la rechazada y la vencida se van de la lista y quedan en el historial.")
