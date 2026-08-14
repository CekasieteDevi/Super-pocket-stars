extends SceneTree

## Clima del partido (§8.4 #18-20) — 5% de dias especiales (a pedido
## explicito), modificador de bloque C sobre control/tiro/reflejos, y
## calor acelerando el desgaste real.
## Correr con: godot --headless --script tests/test_clima.gd

const SEED := 9191


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_probabilidad_del_5_por_ciento(rng)
	_test_cuando_sale_algo_especial_es_una_opcion_valida(rng)
	_test_lluvia_castiga_control_y_reflejos(rng)
	_test_viento_castiga_tiro(rng)
	_test_dia_normal_no_modifica_nada(rng)
	_test_factor_energia(rng)
	_test_integracion_calor_acelera_el_desgaste_real(rng)
	_test_integracion_simular_le_asigna_el_mismo_clima_y_arbitro_a_los_dos(rng)

	quit()


func _test_probabilidad_del_5_por_ciento(rng: RandomNumberGenerator) -> void:
	print("=== ~5%% de los partidos tienen clima especial ===")
	var total := 4000
	var especiales := 0
	for i in range(total):
		if Clima.generar(rng) != "":
			especiales += 1
	var proporcion: float = float(especiales) / float(total)
	if proporcion > 0.03 and proporcion < 0.07:
		print("OK: %d/%d (%.1f%%) con clima especial (esperado ~5%%)." % [especiales, total, proporcion * 100.0])
	else:
		print("FALLA: proporcion=%.1f%%" % (proporcion * 100.0))


func _test_cuando_sale_algo_especial_es_una_opcion_valida(rng: RandomNumberGenerator) -> void:
	print("\n=== Cuando sale clima especial, siempre es Lluvia/Calor/Viento ===")
	var ok := true
	for i in range(4000):
		var clima := Clima.generar(rng)
		if clima != "" and not Clima.OPCIONES.has(clima):
			ok = false
			print("FALLA: salio '%s'" % clima)
			break
	if ok:
		print("OK: nunca salio nada fuera de OPCIONES (ni distinto de \"\").")


func _test_lluvia_castiga_control_y_reflejos(rng: RandomNumberGenerator) -> void:
	print("\n=== Lluvia castiga control y reflejos, nada mas ===")
	var ok := true
	ok = ok and is_equal_approx(Clima.modificador("Lluvia", "control"), -Clima.MALUS_LLUVIA)
	ok = ok and is_equal_approx(Clima.modificador("Lluvia", "reflejos"), -Clima.MALUS_LLUVIA)
	ok = ok and is_equal_approx(Clima.modificador("Lluvia", "tiro"), 0.0)
	ok = ok and is_equal_approx(Clima.modificador("Lluvia", "pases"), 0.0)
	if ok:
		print("OK: -%.1f en control/reflejos, 0 en tiro/pases." % Clima.MALUS_LLUVIA)
	else:
		print("FALLA")


func _test_viento_castiga_tiro(rng: RandomNumberGenerator) -> void:
	print("\n=== Viento castiga tiro, nada mas ===")
	var ok := true
	ok = ok and is_equal_approx(Clima.modificador("Viento", "tiro"), -Clima.MALUS_VIENTO)
	ok = ok and is_equal_approx(Clima.modificador("Viento", "control"), 0.0)
	ok = ok and is_equal_approx(Clima.modificador("Viento", "pases"), 0.0)
	if ok:
		print("OK: -%.1f en tiro, 0 en el resto." % Clima.MALUS_VIENTO)
	else:
		print("FALLA")


func _test_dia_normal_no_modifica_nada(rng: RandomNumberGenerator) -> void:
	print("\n=== Dia normal (\"\") no modifica ningun atributo ===")
	var ok := true
	for atributo in ["control", "reflejos", "tiro", "pases", "quite"]:
		ok = ok and is_equal_approx(Clima.modificador("", atributo), 0.0)
	if ok:
		print("OK: 0.0 en todos los atributos con clima normal.")
	else:
		print("FALLA")


func _test_factor_energia(rng: RandomNumberGenerator) -> void:
	print("\n=== Solo Calor acelera el desgaste, el resto factor 1.0 ===")
	var ok := true
	ok = ok and is_equal_approx(Clima.factor_energia("Calor"), Clima.FACTOR_ENERGIA_CALOR)
	ok = ok and is_equal_approx(Clima.factor_energia("Lluvia"), 1.0)
	ok = ok and is_equal_approx(Clima.factor_energia("Viento"), 1.0)
	ok = ok and is_equal_approx(Clima.factor_energia(""), 1.0)
	if ok:
		print("OK: Calor=%.1fx, el resto 1.0x." % Clima.FACTOR_ENERGIA_CALOR)
	else:
		print("FALLA")


func _test_integracion_calor_acelera_el_desgaste_real(rng: RandomNumberGenerator) -> void:
	print("\n=== Integracion: un jugador se cansa mas rapido en un partido con Calor ===")
	var equipo_normal := Team.generar("ClubNormal", rng, 0)
	var equipo_calor := Team.generar("ClubCalor", rng, 100)
	equipo_normal.reset_partido()
	equipo_calor.reset_partido()
	equipo_calor.clima_partido = "Calor"

	var jugador_id: int = equipo_normal.jugadores[0]["id"]
	var jugador_id_calor: int = equipo_calor.jugadores[0]["id"]
	for i in range(10):
		equipo_normal.desgastar(jugador_id, 60)
		equipo_calor.desgastar(jugador_id_calor, 60)

	if equipo_calor.resistencia_pct(jugador_id_calor) < equipo_normal.resistencia_pct(jugador_id):
		print("OK: con Calor, resistencia=%.4f; sin clima, resistencia=%.4f (mas cansado con calor)." % [
			equipo_calor.resistencia_pct(jugador_id_calor), equipo_normal.resistencia_pct(jugador_id)
		])
	else:
		print("FALLA")


func _test_integracion_simular_le_asigna_el_mismo_clima_y_arbitro_a_los_dos(rng: RandomNumberGenerator) -> void:
	print("\n=== MatchEngine.simular() le asigna el mismo clima/arbitro a home y away ===")
	var home := Team.generar("HomeContexto", rng, 0)
	var away := Team.generar("AwayContexto", rng, 100)
	var ok := true
	for i in range(20):
		var r := RandomNumberGenerator.new()
		r.seed = 6000 + i
		MatchEngine.simular(home, away, r, false)
		ok = ok and home.clima_partido == away.clima_partido
		ok = ok and home.arbitro_partido == away.arbitro_partido
		ok = ok and Arbitro.TIPOS.has(home.arbitro_partido)
		ok = ok and (home.clima_partido == "" or Clima.OPCIONES.has(home.clima_partido))
	if ok:
		print("OK: en 20 partidos, clima/arbitro siempre coinciden entre home y away y son valores validos.")
	else:
		print("FALLA: clima home=%s away=%s, arbitro home=%s away=%s" % [home.clima_partido, away.clima_partido, home.arbitro_partido, away.arbitro_partido])
