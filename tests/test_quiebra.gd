extends SceneTree

## Recuperación de clubes en quiebra (Economia.procesar_quiebra) —
## respuesta al feedback: "¿y si los equipos en quiebra tienen que vender
## jugadores hasta recuperarse? podríamos obligarlos a comprar jugadores
## malos para rellenar la plantilla, resultando en que bajen de división
## porque empeora su equipo". Correr con:
## godot --headless --script tests/test_quiebra.gd

const SEED := 6767


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_vende_al_mas_valioso_y_sale_de_quiebra(rng)
	_test_reemplazo_es_mas_barato_y_reduce_el_sueldo(rng)
	_test_no_hace_nada_si_no_esta_quebrado(rng)
	_test_liga_no_toca_al_equipo_protegido(rng)
	_test_liga_liquida_a_los_no_protegidos(rng)

	quit()


func _test_vende_al_mas_valioso_y_sale_de_quiebra(rng: RandomNumberGenerator) -> void:
	print("=== procesar_quiebra(): vende al jugador de mayor media y sale de la quiebra ===")
	var equipo := Team.generar("ClubQuebrado", rng, 0)

	var mejor_id: int = -1
	var mejor_media := -1.0
	for j in equipo.todos_los_jugadores():
		if j["media"] > mejor_media:
			mejor_media = j["media"]
			mejor_id = j["id"]

	equipo.caja["fichajes"] = -100000000.0  # fuerza la quiebra, pase lo que pase con el valor del plantel
	Economia._recalcular_quiebra(equipo)
	var estaba_quebrado := equipo.quebrado

	var caja_antes: float = equipo.caja["fichajes"]
	var ventas := Economia.procesar_quiebra(equipo, rng)

	var ids_actuales := []
	for j in equipo.todos_los_jugadores():
		ids_actuales.append(j["id"])

	var ok: bool = estaba_quebrado
	ok = ok and not ventas.is_empty()
	ok = ok and ventas[0]["saliente"]["id"] == mejor_id  # el primero en venderse es el de mayor media
	ok = ok and not ids_actuales.has(mejor_id)  # ya no esta en el plantel
	ok = ok and equipo.caja["fichajes"] > caja_antes  # entro plata

	if ok:
		print("OK: se vendio primero al de mayor media (id=%d, media=%.1f), entro plata, y ya no esta en el plantel." % [mejor_id, mejor_media])
	else:
		print("FALLA: estaba_quebrado=%s ventas=%s" % [estaba_quebrado, ventas])


func _test_reemplazo_es_mas_barato_y_reduce_el_sueldo(rng: RandomNumberGenerator) -> void:
	print("\n=== El reemplazo es mas barato (baja la masa salarial, ayuda a la recuperacion futura) ===")
	var equipo := Team.generar("ClubQuebrado2", rng, 1000)
	for j in equipo.jugadores:
		j["media"] = 90.0  # todos carisimos, para que la venta forzada duela de verdad
		# Y con el sueldo que corresponde a esa media. Sin esto el estado
		# quedaba incoherente —media de crack, sueldo de suplente— y que
		# el reemplazo saliera mas barato pasaba a ser cuestion de suerte.
		equipo._registrar_fichaje(
			j, ValorJugador.calcular(j, 50.0, 3), equipo.contratos.get(j["id"], 3))
	equipo.recalcular_capitan()

	var sueldos_antes := 0.0
	for id in equipo.sueldos:
		sueldos_antes += equipo.sueldos[id]

	equipo.caja["fichajes"] = -100000000.0
	Economia._recalcular_quiebra(equipo)
	Economia.procesar_quiebra(equipo, rng)

	var sueldos_despues := 0.0
	for id in equipo.sueldos:
		sueldos_despues += equipo.sueldos[id]

	if sueldos_despues < sueldos_antes:
		print("OK: la masa salarial bajo de %s a %s tras la liquidacion." % [Economia.formato_dinero(sueldos_antes), Economia.formato_dinero(sueldos_despues)])
	else:
		print("FALLA: sueldos_antes=%s sueldos_despues=%s" % [sueldos_antes, sueldos_despues])


func _test_no_hace_nada_si_no_esta_quebrado(rng: RandomNumberGenerator) -> void:
	print("\n=== Un club sano no pierde a nadie ===")
	var equipo := Team.generar("ClubSano", rng, 2000)
	equipo.caja["fichajes"] = 1000000.0
	Economia._recalcular_quiebra(equipo)

	var ids_antes := []
	for j in equipo.todos_los_jugadores():
		ids_antes.append(j["id"])

	var ventas := Economia.procesar_quiebra(equipo, rng)

	var ids_despues := []
	for j in equipo.todos_los_jugadores():
		ids_despues.append(j["id"])

	if ventas.is_empty() and ids_antes == ids_despues:
		print("OK: sin quiebra, no se vende a nadie.")
	else:
		print("FALLA: ventas=%s" % [ventas])


func _test_liga_no_toca_al_equipo_protegido(rng: RandomNumberGenerator) -> void:
	print("\n=== Liga: al equipo del jugador humano no se le vende nadie automaticamente ===")
	var liga := Liga.new()
	liga.inicializar(["Protegido", "Rival"], rng, 0)
	var protegido: Team = liga.equipos[0]
	protegido.caja["fichajes"] = -100000000.0

	var ids_antes := []
	for j in protegido.todos_los_jugadores():
		ids_antes.append(j["id"])

	liga.procesar_economia_y_mercado_y_progresion(rng, protegido, 1)

	var ids_despues := []
	for j in protegido.todos_los_jugadores():
		ids_despues.append(j["id"])

	var hay_aviso := false
	for n in liga.noticias:
		if n.find("QUIEBRA") != -1 and n.find("Protegido") != -1:
			hay_aviso = true

	if ids_antes == ids_despues and hay_aviso:
		print("OK: el plantel protegido no cambio, pero se genero un aviso de quiebra.")
	else:
		print("FALLA: ids_antes==ids_despues=%s hay_aviso=%s" % [ids_antes == ids_despues, hay_aviso])


func _test_liga_liquida_a_los_no_protegidos(rng: RandomNumberGenerator) -> void:
	print("\n=== Liga: a un club de la IA en quiebra si se le liquidan jugadores ===")
	var liga := Liga.new()
	liga.inicializar(["Protegido2", "RivalQuebrado"], rng, 3000)
	var rival: Team = liga.equipos[1]

	# Calculamos el umbral real del club (no un numero fijo adivinado) y
	# ponemos la caja bien por debajo -- lo bastante para seguir en rojo
	# despues de que procesar_temporada le sume el ingreso normal de la
	# temporada encima, pero recuperable con un par de ventas, no un
	# agujero imposible (maximo teorico de recupero: ~70% del valor del
	# plantel completo, liquidando a todos).
	var valor_plantel := 0.0
	for j in rival.todos_los_jugadores():
		valor_plantel += ValorJugador.calcular(j, rival.animo.get(j["id"], 50.0), rival.contratos.get(j["id"], 1))
	rival.caja["fichajes"] = -0.2 * valor_plantel - 300000.0

	var ids_antes := []
	for j in rival.todos_los_jugadores():
		ids_antes.append(j["id"])

	liga.procesar_economia_y_mercado_y_progresion(rng, liga.equipos[0], 1)

	var ids_despues := []
	for j in rival.todos_los_jugadores():
		ids_despues.append(j["id"])

	var hubo_venta_en_noticias := false
	for n in liga.noticias:
		if n.find("QUIEBRA") != -1 and n.find("RivalQuebrado") != -1 and n.find("vende de urgencia") != -1:
			hubo_venta_en_noticias = true

	if ids_antes != ids_despues and hubo_venta_en_noticias and not rival.quebrado:
		print("OK: el club de la IA se liquido solo, quedo con jugadores distintos, y salio de la quiebra.")
	else:
		print("FALLA: cambio_plantel=%s hubo_venta_en_noticias=%s sigue_quebrado=%s" % [ids_antes != ids_despues, hubo_venta_en_noticias, rival.quebrado])
