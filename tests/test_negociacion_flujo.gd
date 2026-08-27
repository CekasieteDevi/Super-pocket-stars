extends SceneTree

## §9.3 rework: el flujo completo de un pase negociado, de punta a punta,
## por donde pasa el jugador humano (GameState).

const SEED := 8181


func _init() -> void:
	_test_pase_completo()
	_test_la_miseria_veta_el_boton()
	_test_el_jugador_puede_decir_que_no()
	if gs != null:
		gs.free()
	quit()


## GameState es un autoload y en un --script no existe, asi que se
## instancia a mano y se le arma el estado. No se agrega al arbol: _ready
## cargaria la partida guardada de verdad y este test no tiene por que
## tocar el disco.
var gs = null


func _partida() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	if gs != null:
		gs.free()  # si no, quedan Nodes colgados y Godot avisa al salir
	gs = load("res://game/game_state.gd").new()
	gs.piramide = piramide
	gs.rng = rng
	gs.temporada_actual = 1
	# El jugador en division 3 para que comprar hacia abajo sea posible.
	gs.division_jugador = 2
	gs.equipo_jugador = piramide.divisiones[2].equipos[0]
	gs.equipo_jugador.caja["fichajes"] = 500000000.0
	var vendedor: Team = piramide.divisiones[4].equipos[0]
	return {"piramide": piramide, "vendedor": vendedor, "rng": rng}


func _test_pase_completo() -> void:
	print("=== Ofertar, que acepten, cerrar contrato ===")
	var p := _partida()
	var vendedor: Team = p["vendedor"]
	var jugador: Dictionary = vendedor.jugadores[6]
	var id := int(jugador["id"])
	var plantel_antes := vendedor.jugadores.size() + vendedor.banco.size()

	var pedido := Negociacion.precio_pedido(vendedor, jugador)
	var oferta: Dictionary = gs.ofertar_compra(vendedor, id, pedido)
	if not oferta["exito"]:
		print("FALLA: rechazaron una oferta igual al pedido (%s)." % oferta["motivo"])
		return

	# Un sueldo generoso para que el jugador acepte bajar/subir a donde sea.
	var sueldo: float = maxf(1000.0, float(vendedor.sueldos.get(id, 1000.0))) * 4.0
	var cierre: Dictionary = gs.ofrecer_contrato(vendedor, id, pedido, sueldo, 4)
	if not cierre["exito"]:
		print("FALLA: el jugador rechazo un sueldo x4 (%s)." % cierre["motivo"])
		return

	var lo_tengo := not Mercado.ubicar(gs.equipo_jugador, id).is_empty()
	var lo_perdio := Mercado.ubicar(vendedor, id).is_empty()
	var sueldo_ok: bool = is_equal_approx(float(gs.equipo_jugador.sueldos[id]), sueldo)
	var anios_ok: bool = int(gs.equipo_jugador.contratos[id]) == 4
	var plantel_ok: bool = vendedor.jugadores.size() + vendedor.banco.size() == plantel_antes
	if lo_tengo and lo_perdio and sueldo_ok and anios_ok and plantel_ok:
		print("OK: pase cerrado por %s, contrato de 4 anios a %s, y el vendedor sigue con %d." % [
			Economia.formato_dinero(pedido), Economia.formato_dinero(sueldo), plantel_antes])
	else:
		print("FALLA: tengo=%s perdio=%s sueldo=%s anios=%s plantel=%s" % [
			lo_tengo, lo_perdio, sueldo_ok, anios_ok, plantel_ok])


func _test_la_miseria_veta_el_boton() -> void:
	print("\n=== Ofertar una miseria veta al club por una temporada ===")
	var p := _partida()
	var vendedor: Team = p["vendedor"]
	var jugador: Dictionary = vendedor.jugadores[8]
	var id := int(jugador["id"])
	var pedido := Negociacion.precio_pedido(vendedor, jugador)

	var r: Dictionary = gs.ofertar_compra(vendedor, id, pedido * 0.1)
	if not r.get("insulto", false):
		print("FALLA: el 10% del precio no ofendio.")
		return
	# Y ahora ni una oferta buena entra.
	var r2: Dictionary = gs.ofertar_compra(vendedor, id, pedido * 2.0)
	if not r2["exito"] and str(r2["motivo"]).contains("temporada"):
		print("OK: despues del insulto ni el doble del precio los hace volver.")
	else:
		print("FALLA: aceptaron pese al veto (%s)." % [r2])

	# La temporada que viene, si.
	gs.temporada_actual = 2
	var r3: Dictionary = gs.ofertar_compra(vendedor, id, pedido)
	if r3["exito"]:
		print("OK: en la temporada siguiente vuelven a escuchar.")
	else:
		print("FALLA: el veto no caduco (%s)." % r3["motivo"])


func _test_el_jugador_puede_decir_que_no() -> void:
	print("\n=== El club acepta pero el jugador puede negarse ===")
	var p := _partida()
	# Un jugador de PRIMERA: bajar a tercera por el mismo sueldo no le
	# interesa, aunque su club se lo quiera sacar de encima.
	var vendedor: Team = p["piramide"].divisiones[0].equipos[0]
	var jugador: Dictionary = vendedor.jugadores[6]
	var id := int(jugador["id"])
	vendedor.animo[id] = 75.0

	var pedido := Negociacion.precio_pedido(vendedor, jugador)
	var oferta: Dictionary = gs.ofertar_compra(vendedor, id, pedido)
	if not oferta["exito"]:
		print("FALLA: el club no acepto el precio pedido.")
		return
	var sueldo: float = float(vendedor.sueldos.get(id, 1000.0))
	var cierre: Dictionary = gs.ofrecer_contrato(vendedor, id, pedido, sueldo, 3)
	var sigue_ahi := not Mercado.ubicar(vendedor, id).is_empty()
	if not cierre["exito"] and sigue_ahi:
		print("OK: el club dijo que si, el jugador que no (%s), y sigue en su club." % cierre["motivo"])
	else:
		print("FALLA: cierre=%s sigue=%s" % [cierre, sigue_ahi])
