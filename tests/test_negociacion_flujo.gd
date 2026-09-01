extends SceneTree

## §9.3 rework: un pase completo por donde pasa el jugador humano — mandar
## la oferta, esperar la respuesta, y firmar el contrato con sueldo, años
## y cláusula.

const SEED := 8181

var gs = null


func _init() -> void:
	_test_pase_completo()
	_test_una_clausula_desmedida_espanta_al_jugador()
	_test_el_jugador_puede_decir_que_no()
	if gs != null:
		gs.free()
	quit()


## GameState es autoload y en un --script no existe: se instancia a mano y
## no se agrega al arbol (su _ready cargaria la partida real del disco).
func _partida() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	if gs != null:
		gs.free()
	gs = load("res://game/game_state.gd").new()
	gs.piramide = piramide
	gs.rng = rng
	gs.temporada_actual = 1
	# El jugador en division 3 para que comprar hacia abajo sea posible.
	gs.division_jugador = 2
	gs.equipo_jugador = piramide.divisiones[2].equipos[0]
	gs._sembrar_presupuestos()
	gs.equipo_jugador.caja["fichajes"] = 500000000.0
	# El libro de pases solo abre en enero, febrero y julio, y una
	# partida arranca en marzo: sin esto toda operacion se rechaza.
	gs.dia_absoluto = Calendario.primer_dia_de_mercado()
	return {"piramide": piramide, "vendedor": piramide.divisiones[4].equipos[0], "rng": rng}


## Manda la oferta y deja pasar los dias hasta que el club conteste.
func _acordar(vendedor: Team, id: int, monto: float) -> Dictionary:
	var r: Dictionary = gs.enviar_oferta(vendedor, id, monto)
	if not r["exito"]:
		return r
	gs._avanzar_dias_todos(Ofertas.DIAS_RESPUESTA_MAX + 1)
	return r


func _test_pase_completo() -> void:
	print("=== Ofertar, esperar, y firmar contrato con clausula ===")
	var p := _partida()
	var vendedor: Team = p["vendedor"]
	var jugador: Dictionary = vendedor.jugadores[6]
	var id := int(jugador["id"])
	var plantel_antes := vendedor.jugadores.size() + vendedor.banco.size()

	var pedido := Negociacion.precio_pedido(vendedor, jugador)
	var r := _acordar(vendedor, id, pedido)
	if not r["exito"] or str(r["oferta"]["estado"]) != Ofertas.ACUERDO_CLUB:
		print("FALLA: no se llego al acuerdo de clubes (%s)." % [r])
		return

	var sueldo: float = maxf(1000.0, float(vendedor.sueldos.get(id, 1000.0))) * 4.0
	var clausula := ValorJugador.calcular(jugador, 50.0, 3) * Team.FACTOR_CLAUSULA
	var cierre: Dictionary = gs.cerrar_fichaje(int(r["oferta"]["id"]), sueldo, 4, clausula)
	if not cierre["exito"]:
		print("FALLA: el jugador rechazo un sueldo x4 (%s)." % cierre["motivo"])
		return

	var lo_tengo := not Mercado.ubicar(gs.equipo_jugador, id).is_empty()
	var lo_perdio := Mercado.ubicar(vendedor, id).is_empty()
	var sueldo_ok: bool = is_equal_approx(float(gs.equipo_jugador.sueldos[id]), sueldo)
	var anios_ok: bool = int(gs.equipo_jugador.contratos[id]) == 4
	var clausula_ok: bool = is_equal_approx(float(gs.equipo_jugador.clausulas[id]), clausula)
	var plantel_ok: bool = vendedor.jugadores.size() + vendedor.banco.size() == plantel_antes
	if lo_tengo and lo_perdio and sueldo_ok and anios_ok and clausula_ok and plantel_ok:
		print("OK: cerrado por %s, 4 anios a %s, clausula %s, vendedor sigue con %d." % [
			Economia.formato_dinero(pedido), Economia.formato_dinero(sueldo),
			Economia.formato_dinero(clausula), plantel_antes])
	else:
		print("FALLA: tengo=%s perdio=%s sueldo=%s anios=%s clausula=%s plantel=%s" % [
			lo_tengo, lo_perdio, sueldo_ok, anios_ok, clausula_ok, plantel_ok])


func _test_una_clausula_desmedida_espanta_al_jugador() -> void:
	print("\n=== Blindarlo con una clausula enorme tiene precio ===")
	# Ponersela por las nubes lo protege de que te lo saquen, pero a el lo
	# encierra: o le bajas la clausula o le pagas mas.
	var p := _partida()
	var vendedor: Team = p["vendedor"]
	var jugador: Dictionary = vendedor.jugadores[4]
	var id := int(jugador["id"])
	var pedido := Negociacion.precio_pedido(vendedor, jugador)
	var sueldo: float = maxf(1000.0, float(vendedor.sueldos.get(id, 1000.0))) * 1.6
	var normal := ValorJugador.calcular(jugador, 50.0, 3) * Team.FACTOR_CLAUSULA

	var r := _acordar(vendedor, id, pedido)
	if str(r["oferta"]["estado"]) != Ofertas.ACUERDO_CLUB:
		print("FALLA: no hubo acuerdo de clubes.")
		return
	var oferta_id := int(r["oferta"]["id"])
	var con_blindaje: Dictionary = gs.cerrar_fichaje(oferta_id, sueldo, 3, normal * 8.0)
	var normal_ok: Dictionary = gs.cerrar_fichaje(oferta_id, sueldo, 3, normal)
	if not con_blindaje["exito"] and normal_ok["exito"]:
		print("OK: con clausula x8 dijo que no (%s); con la normal firmo." % con_blindaje["motivo"])
	else:
		print("FALLA: blindaje=%s normal=%s" % [con_blindaje.get("exito"), normal_ok.get("exito")])


func _test_el_jugador_puede_decir_que_no() -> void:
	print("\n=== El club acepta pero el jugador puede negarse ===")
	var p := _partida()
	# Un jugador de PRIMERA: bajar a tercera por el mismo sueldo no le
	# interesa, aunque su club le acepte el precio.
	var vendedor: Team = p["piramide"].divisiones[0].equipos[0]
	var jugador: Dictionary = vendedor.jugadores[6]
	var id := int(jugador["id"])
	vendedor.animo[id] = 75.0

	var pedido := Negociacion.precio_pedido(vendedor, jugador)
	var r := _acordar(vendedor, id, pedido)
	if str(r["oferta"]["estado"]) != Ofertas.ACUERDO_CLUB:
		print("FALLA: el club no acepto el precio pedido (%s)." % [r["oferta"]["estado"]])
		return
	var sueldo: float = float(vendedor.sueldos.get(id, 1000.0))
	var clausula := ValorJugador.calcular(jugador, 50.0, 3) * Team.FACTOR_CLAUSULA
	var cierre: Dictionary = gs.cerrar_fichaje(int(r["oferta"]["id"]), sueldo, 3, clausula)
	var sigue_ahi := not Mercado.ubicar(vendedor, id).is_empty()
	if not cierre["exito"] and sigue_ahi:
		print("OK: el club dijo que si, el jugador que no (%s), y sigue en su club." % cierre["motivo"])
	else:
		print("FALLA: cierre=%s sigue=%s" % [cierre, sigue_ahi])
