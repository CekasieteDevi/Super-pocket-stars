extends SceneTree

## Mercado más profundo: resistencia de venta y cláusula de rescisión
## (Mercado.resistencia_venta, Mercado.pagar_clausula). Correr con:
## godot --headless --script tests/test_mercado_profundo.gd

const SEED := 3131


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_clausula_se_fija_al_fichar(rng)
	_test_resistencia_mayor_para_capitan(rng)
	_test_resistencia_mayor_para_figura_de_la_posicion(rng)
	_test_oferta_comun_puede_ser_rechazada_por_resistencia(rng)
	_test_clausula_fuerza_la_venta_pase_lo_que_pase(rng)
	_test_clausula_rechazo_sin_fondos(rng)

	quit()


func _test_clausula_se_fija_al_fichar(rng: RandomNumberGenerator) -> void:
	print("=== La clausula se fija al fichar, proporcional al valor ===")
	var equipo := Team.generar("ClubClausulas", rng, 0)
	var jugador: Dictionary = equipo.jugadores[0]
	var id: int = jugador["id"]
	var valor := ValorJugador.calcular(jugador, equipo.animo.get(id, 50.0), equipo.contratos.get(id, 1))

	var ok: bool = equipo.clausulas.has(id)
	ok = ok and is_equal_approx(equipo.clausulas[id], valor * Team.FACTOR_CLAUSULA)

	if ok:
		print("OK: clausula = valor x %.1f (%s)." % [Team.FACTOR_CLAUSULA, Economia.formato_dinero(equipo.clausulas[id])])
	else:
		print("FALLA: clausulas=%s valor_esperado=%s" % [equipo.clausulas, valor * Team.FACTOR_CLAUSULA])


func _test_resistencia_mayor_para_capitan(rng: RandomNumberGenerator) -> void:
	print("\n=== Mas resistencia para vender al capitan ===")
	var equipo := Team.generar("ClubCapitan", rng, 1000)
	var capitan: Dictionary = {}
	for j in equipo.jugadores:
		if j["id"] == equipo.capitan_id:
			capitan = j
			break
	var otro: Dictionary = {}
	for j in equipo.jugadores:
		if j["id"] != equipo.capitan_id:
			otro = j
			break

	var resistencia_capitan := Mercado.resistencia_venta(equipo, capitan)
	var resistencia_otro := Mercado.resistencia_venta(equipo, otro)

	if resistencia_capitan > resistencia_otro:
		print("OK: resistencia del capitan (%.2f) > resistencia de otro jugador (%.2f)." % [resistencia_capitan, resistencia_otro])
	else:
		print("FALLA: capitan=%.2f otro=%.2f" % [resistencia_capitan, resistencia_otro])


func _test_resistencia_mayor_para_figura_de_la_posicion(rng: RandomNumberGenerator) -> void:
	print("\n=== Mas resistencia si el jugador es muy superior al resto de su posicion ===")
	var equipo := Team.generar("ClubFigura", rng, 2000)
	equipo.capitan_id = -1  # aislamos el efecto de "figura", sin el bonus de capitan

	var idx_dc := -1
	for i in range(equipo.jugadores.size()):
		if equipo.jugadores[i]["posicion"] == "DC":
			idx_dc = i
			break
	var figura: Dictionary = equipo.jugadores[idx_dc]

	# El único otro DC (el del banco) queda fijo en 50 -- así el caso
	# "normal" (figura también en 50, sin diferencia) es un punto de
	# comparación limpio contra el caso "figura" (muy por encima).
	for j in equipo.banco:
		if j["posicion"] == "DC":
			j["media"] = 50.0

	figura["media"] = 50.0
	var resistencia_normal := Mercado.resistencia_venta(equipo, figura)

	figura["media"] = 95.0  # muy por encima del resto de su posicion
	var resistencia_figura := Mercado.resistencia_venta(equipo, figura)

	if resistencia_figura > resistencia_normal:
		print("OK: resistencia como figura (%.2f) > resistencia como jugador normal (%.2f)." % [resistencia_figura, resistencia_normal])
	else:
		print("FALLA: figura=%.2f normal=%.2f" % [resistencia_figura, resistencia_normal])


func _test_oferta_comun_puede_ser_rechazada_por_resistencia(rng: RandomNumberGenerator) -> void:
	print("\n=== Con resistencia alta, una oferta comun puede rechazarse aunque la plata alcance ===")
	var comprador := Team.generar("CompradorResistencia", rng, 3000)
	var vendedor := Team.generar("VendedorResistencia", rng, 4000)
	comprador.caja["fichajes"] = 100000000.0
	vendedor.reputacion = 100.0  # maxima resistencia por reputacion

	var idx_objetivo := -1
	for i in range(vendedor.jugadores.size()):
		if vendedor.jugadores[i]["posicion"] == "DC":
			idx_objetivo = i
			break
	vendedor.jugadores[idx_objetivo]["media"] = 95.0
	vendedor.capitan_id = vendedor.jugadores[idx_objetivo]["id"]  # capitan + figura + reputacion = resistencia al tope

	for j in comprador.jugadores:
		if j["posicion"] == "DC":
			j["media"] = 30.0

	var jugador_objetivo_id: int = vendedor.jugadores[idx_objetivo]["id"]
	# rng propio y con seed fija (no el "rng" compartido de todo el archivo):
	# este intento en particular se puede terminar en el primer tiro si le
	# toca un randf() alto por casualidad (con resistencia ~0.85 pasa ~15%
	# de las veces), y como una vez que se acepta la venta ya no hay forma
	# de "reintentar" (el jugador se fue del club), usar el rng compartido
	# lo hace flaky ante cualquier cambio en cuanto rng consume el resto
	# del archivo antes de esta funcion (paso con Habilidades, con esto).
	var rng_oferta := RandomNumberGenerator.new()
	rng_oferta.seed = 555
	var rechazado_por_resistencia := false
	for intento in range(50):
		var resultado := Mercado.ofertar_por_jugador(comprador, vendedor, jugador_objetivo_id, rng_oferta)
		if not resultado["exito"] and resultado.get("resistencia", false):
			rechazado_por_resistencia = true
			break
		elif resultado["exito"]:
			break  # con resistencia < 1.0 tarde o temprano se acepta; alcanza con verlo rechazar alguna vez

	if rechazado_por_resistencia:
		print("OK: al menos un intento se rechazo por resistencia de venta.")
	else:
		print("FALLA: en 50 intentos con resistencia al maximo, nunca se rechazo por resistencia.")


func _test_clausula_fuerza_la_venta_pase_lo_que_pase(rng: RandomNumberGenerator) -> void:
	print("\n=== pagar_clausula(): venta obligatoria, ignora resistencia y si el objetivo 'es mejor' ===")
	var comprador := Team.generar("CompradorClausula", rng, 5000)
	var vendedor := Team.generar("VendedorClausula", rng, 6000)
	vendedor.reputacion = 100.0

	var idx_objetivo := -1
	for i in range(vendedor.jugadores.size()):
		if vendedor.jugadores[i]["posicion"] == "MC":
			idx_objetivo = i
			break
	vendedor.jugadores[idx_objetivo]["media"] = 95.0
	vendedor.capitan_id = vendedor.jugadores[idx_objetivo]["id"]
	var jugador_objetivo_id: int = vendedor.jugadores[idx_objetivo]["id"]
	var clausula: float = vendedor.clausulas[jugador_objetivo_id]

	# El comprador tiene un MC MEJOR (no le convendria una oferta comun),
	# pero pagar la clausula igual tiene que andar -- es su decision.
	for j in comprador.jugadores:
		if j["posicion"] == "MC":
			j["media"] = 99.0
	comprador.caja["fichajes"] = clausula + 1000.0

	var resultado := Mercado.pagar_clausula(comprador, vendedor, jugador_objetivo_id)

	var comprador_ids := []
	for j in comprador.jugadores:
		comprador_ids.append(j["id"])

	var ok: bool = resultado["exito"]
	ok = ok and comprador_ids.has(jugador_objetivo_id)
	ok = ok and is_equal_approx(resultado["clausula"], clausula)

	if ok:
		print("OK: la clausula fuerza la venta del capitan/figura sin importar resistencia ni si convenia (%s)." % Economia.formato_dinero(clausula))
	else:
		print("FALLA: %s" % [resultado])


func _test_clausula_rechazo_sin_fondos(rng: RandomNumberGenerator) -> void:
	print("\n=== pagar_clausula(): rechazo si no alcanza el presupuesto ===")
	var comprador := Team.generar("CompradorPobre", rng, 7000)
	var vendedor := Team.generar("VendedorClausula2", rng, 8000)
	comprador.caja["fichajes"] = 0.0

	var jugador_objetivo_id: int = vendedor.jugadores[0]["id"]
	var resultado := Mercado.pagar_clausula(comprador, vendedor, jugador_objetivo_id)

	if not resultado["exito"] and resultado.has("clausula"):
		print("OK: se rechazo por falta de fondos para la clausula (%s)." % Economia.formato_dinero(resultado["clausula"]))
	else:
		print("FALLA: %s" % [resultado])
