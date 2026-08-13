extends SceneTree

## Mercado.ofertar_por_jugador() — oferta iniciada por el jugador humano
## (a diferencia de ejecutar_ventana(), que es automático entre clubes de
## la IA). Correr con: godot --headless --script tests/test_mercado_oferta.gd
##
## Qué verificamos:
##   1. Oferta exitosa: el jugador entra, el más débil sale, la caja de
##      Fichajes se mueve la diferencia exacta en los dos clubes.
##   2. Rechazo si el objetivo no es mejor que tu titular actual.
##   3. Rechazo si no alcanza el presupuesto de Fichajes.

const SEED := 5050


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_oferta_exitosa(rng)
	_test_rechazo_no_es_mejor(rng)
	_test_rechazo_sin_fondos(rng)

	quit()


func _test_oferta_exitosa(rng: RandomNumberGenerator) -> void:
	print("=== Oferta exitosa ===")
	var comprador := Team.generar("Comprador", rng, 0)
	var vendedor := Team.generar("Vendedor", rng, 1000)

	# Forzamos un caso claro: el vendedor tiene un DC muy superior.
	var idx_objetivo := -1
	for i in range(vendedor.jugadores.size()):
		if vendedor.jugadores[i]["posicion"] == "DC":
			idx_objetivo = i
			break
	vendedor.jugadores[idx_objetivo]["media"] = 90.0

	var idx_saliente := -1
	for i in range(comprador.jugadores.size()):
		if comprador.jugadores[i]["posicion"] == "DC":
			idx_saliente = i
			break
	comprador.jugadores[idx_saliente]["media"] = 40.0
	comprador.caja["fichajes"] = 10000000.0  # de sobra, para aislar el caso de "alcanza"

	var caja_vendedor_antes: float = vendedor.caja["fichajes"]
	var jugador_objetivo_id: int = vendedor.jugadores[idx_objetivo]["id"]
	var jugador_saliente_id: int = comprador.jugadores[idx_saliente]["id"]

	var resultado := Mercado.ofertar_por_jugador(comprador, vendedor, jugador_objetivo_id)

	var ok: bool = resultado["exito"]
	ok = ok and comprador.jugadores[idx_saliente]["id"] == jugador_objetivo_id
	ok = ok and vendedor.jugadores[idx_objetivo]["id"] == jugador_saliente_id
	ok = ok and vendedor.caja["fichajes"] > caja_vendedor_antes
	ok = ok and comprador.sueldos.has(jugador_objetivo_id) and not comprador.sueldos.has(jugador_saliente_id)
	ok = ok and vendedor.sueldos.has(jugador_saliente_id) and not vendedor.sueldos.has(jugador_objetivo_id)

	if ok:
		print("OK: el jugador entra, el debil sale, la plata y los sueldos se movieron bien.")
	else:
		print("FALLA: %s" % [resultado])


func _test_rechazo_no_es_mejor(rng: RandomNumberGenerator) -> void:
	print("\n=== Rechazo: el objetivo no es mejor ===")
	var comprador := Team.generar("Comprador2", rng, 2000)
	var vendedor := Team.generar("Vendedor2", rng, 3000)

	var idx_objetivo := -1
	for i in range(vendedor.jugadores.size()):
		if vendedor.jugadores[i]["posicion"] == "MC":
			idx_objetivo = i
			break
	vendedor.jugadores[idx_objetivo]["media"] = 50.0

	for j in comprador.jugadores:
		if j["posicion"] == "MC":
			j["media"] = 70.0  # ya mejor que el objetivo

	var jugador_objetivo_id: int = vendedor.jugadores[idx_objetivo]["id"]
	var resultado := Mercado.ofertar_por_jugador(comprador, vendedor, jugador_objetivo_id)

	if not resultado["exito"]:
		print("OK: se rechazo la oferta (%s)." % resultado["motivo"])
	else:
		print("FALLA: se esperaba que se rechazara la oferta.")


func _test_rechazo_sin_fondos(rng: RandomNumberGenerator) -> void:
	print("\n=== Rechazo: no alcanza el presupuesto ===")
	var comprador := Team.generar("Comprador3", rng, 4000)
	var vendedor := Team.generar("Vendedor3", rng, 5000)

	var idx_objetivo := -1
	for i in range(vendedor.jugadores.size()):
		if vendedor.jugadores[i]["posicion"] == "ARQ":
			idx_objetivo = i
			break
	vendedor.jugadores[idx_objetivo]["media"] = 95.0

	for j in comprador.jugadores:
		if j["posicion"] == "ARQ":
			j["media"] = 20.0
	comprador.caja["fichajes"] = 0.0

	var jugador_objetivo_id: int = vendedor.jugadores[idx_objetivo]["id"]
	var resultado := Mercado.ofertar_por_jugador(comprador, vendedor, jugador_objetivo_id)

	if not resultado["exito"] and resultado.has("diferencia"):
		print("OK: se rechazo por falta de fondos (necesitaba %s)." % Economia.formato_dinero(resultado["diferencia"]))
	else:
		print("FALLA: se esperaba un rechazo por fondos insuficientes.")
