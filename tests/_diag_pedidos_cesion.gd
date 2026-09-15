extends SceneTree

## Medicion, no test: cuantos pedidos de cesion le llegan al club del
## jugador en una ventana de pases, y por quien.
##
## Se marcan cedibles el banco y las reservas, que es el uso normal de la
## lista: los que no juegan. Cada pedido queda abierto DIAS_ABIERTO dias y
## mientras tanto bloquea otro pedido por el mismo jugador.

const SEED := 8282
const DIAS_VENTANA := 90
const DIAS_ABIERTO := 5
const CORRIDAS := 10


func _init() -> void:
	var inicio := Time.get_ticks_msec()
	for division in [2, 6]:
		_medir(division)
	print("ms totales: %d" % (Time.get_ticks_msec() - inicio))
	quit()


func _medir(division: int) -> void:
	var total := 0
	var cedibles := 0
	var jugadores_pedidos := 0
	var suma_ventaja := 0.0
	var por_division := {}
	for corrida in range(CORRIDAS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + corrida
		var piramide := Piramide.generar(rng)
		var gs = load("res://game/game_state.gd").new()
		gs.piramide = piramide
		gs.rng = rng
		gs.temporada_actual = 1
		gs.division_jugador = division
		gs.equipo_jugador = piramide.divisiones[division].equipos[0]
		gs._sembrar_presupuestos()
		var mio: Team = gs.equipo_jugador
		for j in mio.banco + mio.reservas:
			Cesiones.fijar(mio, int(j["id"]), Cesiones.DISPONIBLE)
			cedibles += 1

		var nacido := {}
		var pedidos_por := {}
		for dia in range(DIAS_VENTANA):
			for o in mio.ofertas.duplicate():
				if dia - int(nacido[int(o["id"])]) >= DIAS_ABIERTO:
					mio.ofertas.erase(o)
			var o: Dictionary = Cesiones.generar_pedido(mio, piramide, rng, 1, division)
			if o.is_empty():
				continue
			nacido[int(o["id"])] = dia
			total += 1
			pedidos_por[int(o["jugador_id"])] = true
			var pide := Ofertas._club_por_nombre(piramide, str(o["club"]))
			var j: Dictionary = Mercado.ubicar(mio, int(o["jugador_id"]))["jugador"]
			suma_ventaja += float(j["media"]) - pide.media_equipo()
			for d in range(piramide.divisiones.size()):
				if piramide.divisiones[d].equipos.has(pide):
					por_division[d + 1] = int(por_division.get(d + 1, 0)) + 1
		jugadores_pedidos += pedidos_por.size()
		gs.free()

	var n := float(CORRIDAS)
	print("Division %d (%d corridas de %d dias, %.1f cedibles):" % [
		division + 1, CORRIDAS, DIAS_VENTANA, cedibles / n])
	print("  pedidos por ventana: %.1f" % (total / n))
	print("  cedibles distintos con al menos un pedido: %.1f" % (jugadores_pedidos / n))
	print("  pedidos por division del que pide: %s" % [por_division])
	if total > 0:
		print("  media del pedido - media del club que pide: %+.1f" % (suma_ventaja / float(total)))
